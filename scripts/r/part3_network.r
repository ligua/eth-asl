source("scripts/r/common.r")
source("scripts/r/ms3_common.r")

# ---- Directories and files ----
output_dir <- "results/analysis/part3_network"
exp_dir <- "results/throughput/clients180_threads32_rep0"
memaslap_file <- paste0(exp_dir, "/memaslap_stats.csv")
requests_file <- paste0(exp_dir, "/request.log")

# ---- Reading data ----
memaslap <- file_to_df(memaslap_file) %>% mutate(repetition=0)
requests <- file_to_df(requests_file, sep=",") %>%
  filter(type == "GET")

# ---- Preprocessing ----
mss <- memaslap_summary(memaslap)
mean_rt_memaslap <- mss$mean_response_time_get
mean_rt_middleware <- mean(requests$timeReturned-requests$timeCreated)
mean_network_delay <- (mean_rt_memaslap-mean_rt_middleware)/2
mean_lb_time <- mean(requests$timeEnqueued-requests$timeCreated)
mean_mwcomponent_time <- mean(requests$timeReturned-requests$timeEnqueued)
