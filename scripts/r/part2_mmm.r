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
  SAMPLING_RATE <- 10 # from exp2 setup
  service_rates <- requests %>%
    mutate(secondCreated=floor(timeCreated/1000/WINDOW_SIZE)) %>%
    group_by(secondCreated) %>%
    summarise(count=n()) %>%
    arrange(desc(count))
  
  # ---- Parameters ----
  arrival_rate <- mean(service_rates$count) / WINDOW_SIZE * SAMPLING_RATE
  total_service_rate <- max(service_rates$count) / WINDOW_SIZE * SAMPLING_RATE
  single_service_rate <- total_service_rate / m
  rho <- arrival_rate / total_service_rate    # traffic intensity
  p0 <- get_mmm_p0(m, rho)                    # prob. of 0 jobs in system
  weird_rho <- get_mmm_weird_rho(m, rho, p0)  # prob. of >=m jobs in system
  print(paste0("Traffic intensity: ", round(rho, digits=2)))
  
  
  # ---- Predictions ---- # TODO
  predicted = list()
  predicted$type <- "predicted"
  predicted$mean_num_jobs_in_system <- m * rho + rho * weird_rho / (1 - rho)
  predicted$std_num_jobs_in_system <-
    m * rho + rho * weird_rho * ((1 + rho - rho * weird_rho)/((1 - rho)^2) + m)
  predicted$mean_num_jobs_in_queue <- rho * weird_rho * (1 - rho)
  predicted$utilisation <- rho
  predicted$mean_response_time <-
    1 / single_service_rate * (1 + weird_rho / (m * (1 - rho))) * 1000 # ms
  Ew <- weird_rho / (m * single_service_rate * (1 - rho))
  # predicted$mean_waiting_time <- Ew
  predicted$response_time_q50 <- max(0, Ew / weird_rho * log(weird_rho / (1 - 0.5))) * 1000 # ms
  predicted$response_time_q95 <- max(0, Ew / weird_rho * log(weird_rho / (1 - 0.95))) * 1000 # ms
  
  # ---- Actual results ----
  actual = list()
  
  # Number of jobs in system
  time_zero <- min(requests$timeCreated)
  N_SAMPLES <- 5000
  requests2 <- requests %>%
    select(timeCreated, timeDequeued, timeReturned) %>%
    mutate(timeCreated=timeCreated-time_zero,
           timeDequeued=timeDequeued-time_zero,
           timeReturned=timeReturned-time_zero) %>%
    top_n(N_SAMPLES, wt=desc(timeCreated))
  
  distributions <- get_service_and_queue_distributions(requests2)
  means <- distributions %>%
    summarise(queue=sum(num_elements * queue),
              service=sum(num_elements * service),
              total=sum(num_elements * total))
  
  response_times <- requests$timeReturned - requests$timeEnqueued
  
  actual$type <- "actual"
  actual$mean_num_jobs_in_system <- means$total
  actual$std_num_jobs_in_system <- sum(distributions$total * (distributions$num_elements-means$total)^2)
  actual$mean_num_jobs_in_queue <- means$queue
  actual$utilisation <- 1 - (distributions %>% filter(num_elements==0))$total
  actual$mean_response_time <- mean(response_times)
  actual$response_time_q50 <- quantile(response_times, probs=c(0.5))
  actual$response_time_q95 <- quantile(response_times, probs=c(0.95))
  
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
                          "/clients(\\d{2,3})_threads(32)_rep(0)$")
unfiltered_dirs <- list.dirs(path=result_dir_base, recursive=TRUE)
filtered_dirs <- grep(dir_name_regex, unfiltered_dirs, value=TRUE, perl=TRUE)

comparisons <- NA
for(i in 1:length(filtered_dirs)) {
  dirname = filtered_dirs[i]
  print(paste0("DIR: ", dirname))
  summary <- get_mmm_summary(dirname)
  
  if(is.na(comparisons)) {
    comparisons <- summary
  } else {
    comparisons <- rbind(comparisons, summary)
  }
}


# ---- Plotting ----
data1 <- comparisons %>%
  filter(clients != 180)
ggplot(data1, aes(x=clients, y=mean_response_time, color=type)) +
  geom_line() +
  asl_theme
  

