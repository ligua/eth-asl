source("scripts/r/common.r")

# ---- Parse command line args ----
args <- commandArgs(trailingOnly=TRUE)
if(length(args) == 0) {
  result_dir_base <- "results/throughput"
} else if(length(args) == 1) {
  result_dir_base <- args[1]
} else {
  stop("Arguments: [<results_directory>]")
}

# ---------------------------
# ---- HELPER FUNCTIONS -----
# ---------------------------

memaslap_summary <- function(df) {
  DROP_TIMES_BEFORE = 2 * 60 # How many seconds in the beginning we want to drop
  DROP_TIMES_AFTER = max((df %>% filter(type=="t"))$time) - 2 * 60
  
  df2 <- df %>%
    mutate(min=min/1000, max=max/1000, avg=avg/1000, std=std/1000) %>%
    filter(type=="t" & time > DROP_TIMES_BEFORE & time <= DROP_TIMES_AFTER) %>%
    filter(request_type=="GET")
  
  response_times <- df2 %>%
    group_by(time) %>%
    summarise(mean_response_time=sum(ops*avg)/sum(ops)) %>%
    select(time, mean_response_time)
  response_time_beginning <- (response_times %>%
    top_n(5, desc(time)))$mean_response_time %>%
    mean() # need mean() because we're taking more than 1 element
  response_time_end <- (response_times %>%
    top_n(5, time))$mean_response_time %>%
    mean()
  
  res <- list()
  tps_summed <- df2 %>% group_by(time, repetition) %>%
                   summarise(tps=sum(tps))
  tps_values <- tps_summed$tps
  res$tps_mean <- mean(tps_values)
  res$tps_std <- sd(tps_values) # TODO calculate tps std over reps too
  res$tps_q2.5 <- quantile(tps_values, 0.025)
  res$tps_q97.5 <- quantile(tps_values, 0.975)
  two_sided_t_val <- qt(c(.025, .975), df=length(tps_values)-1)[2]
  res$tps_confidence_delta <- two_sided_t_val * res$tps_std/sqrt(length(tps_values))
  res$tps_confidence_delta_rel <- res$tps_confidence_delta / res$tps_mean
  res$mean_response_time <- mean(df2$avg)
  res$std_response_time <- sqrt(sum(df2$ops * df2$std * df2$std) / sum(df2$ops))
  res$response_time_beginning <- response_time_beginning
  res$response_time_end <- response_time_end
  
  return(as.data.frame(res))
}

middleware_summary <- function(df2) {
  res <- list()
  res$response_time_q01 <- quantile(df2$tAll, 0.01)
  res$response_time_q05 <- quantile(df2$tAll, 0.05)
  res$response_time_q50 <- quantile(df2$tAll, 0.50)
  res$response_time_q95 <- quantile(df2$tAll, 0.95)
  res$response_time_q99 <- quantile(df2$tAll, 0.99)
  
  return(as.data.frame(res))
}

file_to_df <- function(file_path, sep=";") {
  if(file.exists(file_path)) {
    df <- read.csv(file_path, header=TRUE, sep=sep)
    result <- df
  } else {
    result <- data.frame()
  }
  return(result)
}

normalise_request_log_df <- function(df) {
  df2 <- df %>%
    filter(type=="GET") %>%
    mutate(tAll=timeReturned-timeCreated)
  
  first_get_request_time <- min(df2$timeCreated)
  last_get_request_time <- max(df2$timeCreated)
  DROP_TIMES_BEFORE = first_get_request_time + 2 * 60 * 1000
  DROP_TIMES_AFTER = last_get_request_time - 2 * 60 * 1000
  
  df2 <- df2 %>% filter(timeCreated > first_get_request_time &
                          timeCreated >= DROP_TIMES_AFTER)
  return(df2)
}

# ------------------
# ---- FILE IO -----
# ------------------

# ---- Loop over result dirs ----
file_name_regex <- paste0(result_dir_base,
                          "/clients(\\d{1,3})_threads(\\d{1,2})_rep(\\d{1,2})/memaslap_stats\\.csv$")
unfiltered_files <- list.files(path=".", "memaslap_stats.csv", recursive=TRUE)
filtered_files <- grep(file_name_regex, unfiltered_files, value=TRUE, perl=TRUE)

result_params <- as.data.frame(str_match(filtered_files, file_name_regex))
colnames(result_params) <- c("path", "clients", "threads", "repetition")
result_params <- result_params  %>%
  mutate(path=as.character(path))
  # group_by(clients, threads) %>%
  #summarise(paths=paste0(path, collapse=";"))

results <- NA
mw_results <- NA
client_thread_combinations <- result_params %>%
  select(clients, threads) %>%
  unique()

for(i in 1:nrow(client_thread_combinations)) {
  n_clients <- client_thread_combinations[i,]$clients
  n_threads <- client_thread_combinations[i,]$threads
  repetitions <- result_params %>%
    filter(clients==n_clients & threads==n_threads)
  
  combined_result <- NA
  combined_mw_result <- NA
  for(j in 1:nrow(repetitions)) {
    params <- repetitions[j,]
    print(dirname(params$path))
    rep_id <- params$repetition
    file_path <- params$path
    mw_file_path <- paste0(dirname(file_path), "/request.log")
    repetition_result <- file_to_df(file_path) %>%
      mutate(repetition=rep_id)
    mw_result <- file_to_df(mw_file_path, sep=",") %>%
      mutate(repetition=rep_id) %>%
      normalise_request_log_df()
    
    if(is.na(combined_result)) {
      combined_result <- repetition_result
      combined_mw_result <- mw_result
    } else {
      combined_result <- rbind(combined_result, repetition_result)
      combined_mw_result <- rbind(combined_mw_result, mw_result)
    }
  }
  
  if(n_clients == OPTIMAL_CLIENTS & n_threads == OPTIMAL_THREADS) {
    print("OPTIMAL")
    optimal_mw_df <- combined_mw_result
  }
  
  combined_ms_result_row <- memaslap_summary(combined_result)
  combined_mw_result_row <- middleware_summary(combined_mw_result)
  combined_result_row <- cbind(combined_ms_result_row, combined_mw_result_row)
  
  if(is.na(results)) {
    results <- combined_result_row
  } else {
    results <- rbind(results, combined_result_row)
  }
}

all_results <- cbind(client_thread_combinations, results) %>%
  mutate(clients=as.numeric(as.character(clients)),
         threads=as.numeric(as.character(threads)))

# ------------------
# ---- PLOTTING ----
# ------------------

# ---- Throughput vs clients ----
data1 <- all_results %>%
  filter(!is.na(tps_mean)) %>%
  mutate(threads=paste0(threads, ifelse(threads==1, " thread", " threads")))
g1 <- ggplot(data1, aes(x=clients, y=tps_mean)) +
  geom_errorbar(aes(ymin=tps_mean-tps_confidence_delta,
                    ymax=tps_mean+tps_confidence_delta),
                color=color_triad2, width=20, size=0.5) +
  geom_line(color=color_dark) +
  geom_point(color=color_dark) +
  facet_wrap(~threads) +
  xlab("Number of clients") +
  ylab("Total throughput [requests/s]") +
  asl_theme
g1
ggsave(paste0(result_dir_base, "/graphs/tp_vs_clients.pdf"), g1,
       width=fig_width, height=fig_height, device=cairo_pdf)

# ---- Response time vs clients ----
data3 <- all_results %>%
  filter(!is.na(tps_mean)) %>%
  mutate(threads=paste0(threads, ifelse(threads==1, " thread", " threads")))
data3_melt <- all_results %>%
  select(clients, threads, response_time_q01:response_time_q99) %>%
  melt(id.vars=c("clients", "threads")) %>%
  mutate(variable=paste0(as.numeric(substr(variable, 16, 17))), "%") %>%
  rename(Percentile=variable)
g3 <- ggplot(data3_melt, aes(x=clients, y=value, color=Percentile)) +
  geom_line() +
  geom_point() +
  facet_wrap(~threads) +
  ylim(NA, 100) +
  xlab("Number of clients") +
  ylab("Response time [ms]") +
  asl_theme +
  theme(legend.position="top")
g3
ggsave(paste0(result_dir_base, "/graphs/response_time_vs_clients.pdf"), g3,
       width=fig_width, height=fig_height, device=cairo_pdf)

# ---- Throughput not within 95% confidence interval ----
not_confident <- data1 %>%
  filter(tps_confidence_delta_rel > 0.05) %>%
  select(clients, threads, tps_confidence_delta_rel)

cat(paste0(nrow(data1), " experiments total, ", nrow(not_confident),
           " experiments' 95% confidence interval is not within 5% of mean:"))
print(not_confident)


# ---- Response time diff vs clients ----
data2 <- all_results %>%
  mutate(delta=ifelse(response_time_beginning > response_time_end, "faster", "slower"))
colour_scale <- scale_colour_manual(name = "grp", values = c("green", "red"))
g2 <- ggplot(data2) +
  geom_segment(aes(x=clients, xend=clients,
                   y=response_time_beginning,yend=response_time_end,
                   color=delta),
               arrow=arrow(length=unit(0.02, "npc"), type="closed")) +
  ylim(0, 100) +
  colour_scale +
  ylab("Response time beginning -> end [ms]") + xlab("Number of clients") +
  facet_wrap(~threads) +
  asl_theme
g2
ggsave(paste0(result_dir_base, "/graphs/response_time_diff.pdf"), g2,
       width=fig_width, height=fig_height, device=cairo_pdf)


# ---- Maximum throughput ----
max_tp <- all_results %>%
  arrange(desc(tps_mean)) %>%
  head(5) %>%
  select(threads, clients, tps_mean, tps_std, tps_confidence_delta_rel)
max_tp

# ---- Maximum 95% confidence lower bound in throughput ----
max_tp_conf <- all_results %>%
  mutate(tps_lower_bound=tps_mean-tps_confidence_delta) %>%
  arrange(desc(tps_lower_bound)) %>%
  head(5) %>%
  select(threads, clients, tps_lower_bound, tps_mean, tps_std, tps_confidence_delta_rel)
max_tp_conf

# ---- Response time breakdown of optimal run ----
OPTIMAL_CLIENTS <- 432
OPTIMAL_THREADS <- 32
run0_filename <- "results/throughput/clients432_threads32_rep1/request.log"
run1_filename <- "results/throughput/clients432_threads32_rep1/request.log"
run0_df <- file_to_df(run0_filename, sep=",") %>%
  normalise_request_log_df()
run1_df <- file_to_df(run1_filename, sep=",") %>%
  normalise_request_log_df()

data4 <- rbind(run0_df, run1_df) %>%
  mutate(tLoadBalancer=timeEnqueued-timeCreated,
         tQueue=timeDequeued-timeEnqueued,
         tWorker=timeForwarded-timeDequeued,
         tMemcached=timeReceived-timeForwarded,
         tReturn=timeReturned-timeReceived,
         tAll=timeReturned-timeCreated)
  

g4 <- ggplot(data4 %>% select(type, tLoadBalancer:tReturn) %>% melt(id.vars=c("type"))) +
  geom_histogram(aes(x=value, xmin=0, fill=type), fill=color_medium) +
  facet_wrap(~variable, ncol=5, scales="free_y") +
  xlim(-1, 50) +
  xlab("Time spent [ms]") +
  ylab("Number of requests") +
  ggtitle("Distribution of time that requests spend in different parts of SUT") +
  asl_theme +
  theme(legend.position="none")
g4
ggsave(paste0(result_dir_base, "/graphs/response_time_breakdown.pdf"), g4,
       width=fig_width, height=fig_height/2, device=cairo_pdf)

# Means
means <- data4 %>%
  summarise(tLoadBalancer=mean(tLoadBalancer),
            tQueue=mean(tQueue),
            tWorker=mean(tWorker),
            tMemcached=mean(tMemcached),
            tReturn=mean(tReturn),
            tAll=mean(tAll))
means
