source("scripts/r/common.r")
source("scripts/r/ms3_common.r")

get_mmm_summary <- function(results_dir) {
  # ---- Reading data ----
  memaslap <- file_to_df(paste0(results_dir, "/memaslap_stats.csv"))
  requests <- file_to_df(paste0(results_dir, "/request.log"), sep=",")
  
  # ---- Preprocessing ----
  DROP_TIMES_BEFORE_MS = 2 * 60 # How many seconds in the beginning we want to drop
  DROP_TIMES_AFTER_MS = max((memaslap %>% filter(type=="t"))$time) - 2 * 60
  
  first_request_time <- min(requests$timeCreated)
  last_request_time <- max(requests$timeCreated)
  DROP_TIMES_BEFORE_MW = first_request_time + 2 * 60 * 1000
  DROP_TIMES_AFTER_MW = last_request_time - 2 * 60 * 1000
  
  requests <- requests %>%
    filter(timeCreated > DROP_TIMES_BEFORE_MW & timeCreated <= DROP_TIMES_AFTER_MW)
  
  filename_regex <- paste0("/S(\\d)_R(1)_rep([5])$") # exp1
  filename_match <- grep(filename_regex, results_dir, value=TRUE, perl=TRUE)
  result_params <- as.data.frame(str_match(filename_match, filename_regex))
  colnames(result_params) <- c("path", "servers", "replication", "repetition")
  result_params <- result_params %>%
    mutate(servers=as.numeric(as.character(servers)),
           replication=as.numeric(as.character(replication)),
           repetition=as.numeric(as.character(repetition)))
  
  # ------------------
  # ---- Analysis ----
  # ------------------
  num_threads <- 32 + 1 # also writes
  prop_writes <- 5 / 1000
  m <- result_params$servers * num_threads
  WINDOW_SIZE <- 1 # seconds
  SAMPLING_RATE <- 10 # from exp1 setup
  service_rates <- requests %>%
    mutate(secondCreated=floor(timeCreated/1000/WINDOW_SIZE)) %>%
    group_by(secondCreated) %>%
    summarise(count=n()) %>%
    arrange(desc(count))
  
  # ---- Parameters ----
  arrival_rate <- mean(service_rates$count) / WINDOW_SIZE * SAMPLING_RATE
  #total_service_rate <- max(service_rates$count) / WINDOW_SIZE * SAMPLING_RATE
  #single_service_rate <- total_service_rate / m
  single_service_rate <- 1/mean(requests$timeReturned-requests$timeDequeued) * 1000 # s
  rho <- arrival_rate / (m * single_service_rate)    # traffic intensity
  log_p0 <- get_mmm_log10_p0_approx(m, rho)
  p0 <- 10^log_p0 # prob. of 0 jobs in system
  weird_rho <- 10^get_mmm_log10_weird_rho_approx(m, rho, log_p0)  # prob. of >=m jobs in system
  print(paste0("Traffic intensity: ", round(rho, digits=2)))
  
  
  # ---- Predictions ---- # TODO
  predicted = list()
  predicted$type <- "predicted"
  predicted$utilisation <- rho
  predicted$response_time_mean <-
    get_mmm_response_time_mean(rho, weird_rho, single_service_rate, m) * 1000 # ms
  predicted$response_time_std <-
    get_mmm_response_time_std(rho, weird_rho, single_service_rate, m) * 1000 # ms
  Ew <- get_mmm_waiting_time_mean(rho, weird_rho, single_service_rate, m)
  predicted$response_time_q50 <- get_mmm_response_time_quantile(weird_rho, Ew, 0.5) * 1000 # ms
  predicted$response_time_q95 <- get_mmm_response_time_quantile(weird_rho, Ew, 0.95) * 1000 # ms # ms
  predicted$waiting_time_mean <- Ew * 1000 # ms
  
  # ---- Actual results ----
  actual = list()
  
  response_times <- requests$timeReturned - requests$timeEnqueued
  
  actual$type <- "actual"
  actual$utilisation <- arrival_rate * mean(requests$timeReturned-requests$timeDequeued) /
    result_params$servers / num_threads / 1000 # utilization law
  actual$response_time_mean <- mean(response_times)
  actual$response_time_std <- sd(response_times)
  actual$response_time_q50 <- quantile(response_times, probs=c(0.5))
  actual$response_time_q95 <- quantile(response_times, probs=c(0.95))
  actual$waiting_time_mean <- mean(requests$timeDequeued-requests$timeEnqueued)
  
  comparison <- rbind(data.frame(predicted), data.frame(actual)) %>%
    mutate(servers=result_params$servers[[1]],
           replication=result_params$replication[[1]],
           repetition=result_params$repetition[[1]],
           threads=num_threads)
}


# ---- Directories ----
output_dir <- "results/analysis/part2_mmm"
result_dir_base <- "results/replication"

# ---- Extracting data
dir_name_regex <- paste0(result_dir_base,
                          "/S(\\d)_R(1)_rep([5])$")
unfiltered_dirs <- list.dirs(path=result_dir_base, recursive=TRUE)
filtered_dirs <- grep(dir_name_regex, unfiltered_dirs, value=TRUE, perl=TRUE)

comparisons <- NA
for(i in 1:length(filtered_dirs)) {
  dirname = filtered_dirs[i]
  dirname_match <- grep(dir_name_regex, dirname, value=TRUE, perl=TRUE)
  print(paste0("DIR: ", dirname))
  
  summary <- get_mmm_summary(dirname)
  
  if(is.na(comparisons)) {
    comparisons <- summary
  } else {
    comparisons <- rbind(comparisons, summary)
  }
}

# Saving table
comparisons_to_save <- comparisons %>%
  select(servers, type, response_time_mean:response_time_std) %>%
  melt(id.vars=c("type", "servers")) %>%
  dcast(variable ~ type + servers) %>%
  select(variable, predicted_3, actual_3, predicted_5, actual_5,
         predicted_7, actual_7)
comparison_table <- xtable(comparisons_to_save, caption="Comparison of experimental results and predictions of the M/M/m model.",
                           label="tbl:part2:comparison_table",
                           digits=c(NA, NA, 2, 2, 2, 2, 2, 2))
print(comparison_table, file=paste0(output_dir, "/comparison_table.txt"))


# ---- Plotting ----

# Utilisation
ggplot(comparisons, aes(x=servers, y=utilisation, color=type)) +
  geom_line(size=1) +
  geom_point(size=2) +
  ylim(0, 1) +
  xlab("Number of clients") +
  ylab("Utilisation") +
  asl_theme
ggsave(paste0(output_dir, "/graphs/utilisation_vs_clients.pdf"),
       width=fig_width/2, height=fig_height/2)

# Mean response time
ggplot(comparisons, aes(x=servers, y=response_time_mean, color=type, fill=type)) +
  geom_ribbon(aes(ymin=response_time_mean-response_time_std,
                  ymax=response_time_mean+response_time_std),
              alpha=0.3, color=NA) +
  geom_line(size=1) +
  geom_point(size=2) +
  facet_wrap(~type, nrow=1) +
  #ylim(0, NA) +
  xlab("Number of clients") +
  ylab("Mean response time") +
  asl_theme +
  theme(legend.position="none")
ggsave(paste0(output_dir, "/graphs/response_time_predicted_and_actual.pdf"),
       width=fig_width, height=0.75 * fig_height)


