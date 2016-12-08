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
  
  filename_regex <- paste0("clients(\\d{1,3})_threads(\\d{1,2})_rep(\\d{1,2})") # exp1
  filename_match <- grep(filename_regex, results_dir, value=TRUE, perl=TRUE)
  result_params <- as.data.frame(str_match(filename_match, filename_regex))
  colnames(result_params) <- c("path", "clients", "threads", "repetition")
  result_params <- result_params %>%
    mutate(clients=as.numeric(as.character(clients)),
           threads=as.numeric(as.character(threads)),
           repetition=as.numeric(as.character(repetition)))
  
  # ------------------
  # ---- Analysis ----
  # ------------------
  m <- 5
  WINDOW_SIZE <- 1 # seconds
  SAMPLING_RATE <- 100 # from exp1 setup
  MAX_THROUGHPUT <- 26500 # from exp1: clients=576, repetition=0
  service_rates <- requests %>%
    mutate(secondCreated=floor(timeCreated/1000/WINDOW_SIZE)) %>%
    group_by(secondCreated) %>%
    summarise(count=n()) %>%
    arrange(desc(count))
  
  # ---- Parameters ----
  arrival_rate <- mean(service_rates$count) / WINDOW_SIZE * SAMPLING_RATE
  total_service_rate <- MAX_THROUGHPUT # max(service_rates$count) / WINDOW_SIZE * SAMPLING_RATE
  single_service_rate <- total_service_rate / m
  rho <- arrival_rate / total_service_rate    # traffic intensity
  p0 <- get_mmm_p0(m, rho)                    # prob. of 0 jobs in system
  weird_rho <- get_mmm_weird_rho(m, rho, p0)  # prob. of >=m jobs in system
  print(paste0("Traffic intensity: ", round(rho, digits=2)))
  
  
  # ---- Predictions ---- # TODO
  predicted = list()
  predicted$type <- "predicted"
  predicted$traffic_intensity <- rho
  predicted$utilisation <- rho
  predicted$response_time_mean <-
    get_mmm_response_time_mean(rho, weird_rho, single_service_rate, m) * 1000 # ms
  predicted$response_time_std <-
    get_mmm_response_time_std(rho, weird_rho, single_service_rate, m) * 1000 # ms
  Ew <- weird_rho / (m * single_service_rate * (1 - rho))
  # predicted$mean_waiting_time <- Ew
  predicted$response_time_q50 <- max(0, Ew / weird_rho * log(weird_rho / (1 - 0.5))) * 1000 # ms
  predicted$response_time_q95 <- max(0, Ew / weird_rho * log(weird_rho / (1 - 0.95))) * 1000 # ms
  predicted$arrival_rate <- NA
  predicted$total_service_rate <- NA
  
  # ---- Actual results ----
  actual = list()
  
  response_times <- requests$timeReturned - requests$timeEnqueued
  
  actual$type <- "actual"
  actual$traffic_intensity <- NA
  actual$utilisation <- NA # can't measure this on a per-server basis here
  actual$response_time_mean <- mean(response_times)
  actual$response_time_std <- sd(response_times)
  actual$response_time_q50 <- quantile(response_times, probs=c(0.5))
  actual$response_time_q95 <- quantile(response_times, probs=c(0.95))
  actual$arrival_rate <- arrival_rate
  actual$total_service_rate <- total_service_rate
  
  comparison <- rbind(data.frame(predicted), data.frame(actual)) %>%
    mutate(clients=result_params$clients[[1]],
           threads=result_params$threads[[1]],
           repetition=result_params$repetition[[1]])
}


# ---- Directories ----
output_dir <- "results/analysis/part2_mmm"
result_dir_base <- "results/throughput"

# ---- Extracting data
dir_name_regex <- paste0(result_dir_base,
                          "/clients(\\d{1,3})_threads(32)_rep(0)$")
unfiltered_dirs <- list.dirs(path=result_dir_base, recursive=TRUE)
filtered_dirs <- grep(dir_name_regex, unfiltered_dirs, value=TRUE, perl=TRUE)

comparisons <- NA
for(i in 1:length(filtered_dirs)) {
  dirname = filtered_dirs[i]
  dirname_match <- grep(dir_name_regex, dirname, value=TRUE, perl=TRUE)
  n_clients <- as.numeric(as.character(as.data.frame(str_match(dirname_match, dir_name_regex))$V2))
  print(paste0("DIR: ", dirname))
  
  if(n_clients == 1 | n_clients == 180 | n_clients > 576) {
    print("skipping")
    next
  } else {
    summary <- get_mmm_summary(dirname)
  }
  
  if(is.na(comparisons)) {
    comparisons <- summary
  } else {
    comparisons <- rbind(comparisons, summary)
  }
}

# Saving table
comparisons_to_save <- comparisons %>%
  select(clients, type, response_time_mean:response_time_std) %>%
  melt(id.vars=c("type", "clients")) %>%
  dcast(variable + clients ~ type)
comparison_table <- xtable(comparisons_to_save, caption="Comparison of experimental results and predictions of the M/M/m model.",
                           label="tbl:part2:comparison_table")
print(comparison_table, file=paste0(output_dir, "/comparison_table.txt"))


# ---- Plotting ----

# Traffic intensity
ggplot(comparisons %>% filter(type=="predicted"), aes(x=clients, y=traffic_intensity, color=type)) +
  geom_line(size=1) +
  geom_point(size=2) +
  ylim(0, 1) +
  xlab("Number of clients") +
  ylab("Traffic intensity") +
  asl_theme +
  theme(legend.position="none")
ggsave(paste0(output_dir, "/graphs/traffic_intensity_vs_clients.pdf"),
       width=fig_width/2, height=fig_height/2)

# Mean response time
ggplot(comparisons, aes(x=clients, y=response_time_mean, color=type, fill=type)) +
  geom_ribbon(aes(ymin=response_time_mean-response_time_std,
                  ymax=response_time_mean+response_time_std),
              alpha=0.3, color=NA) +
  geom_line(size=1) +
  geom_point(size=2) +
  facet_wrap(~type, scales="free_y", nrow=1) +
  #ylim(0, NA) +
  xlab("Number of clients") +
  ylab("Mean response time") +
  asl_theme +
  theme(legend.position="none")
ggsave(paste0(output_dir, "/graphs/response_time_predicted_and_actual.pdf"),
       width=fig_width, height=0.75 * fig_height)


