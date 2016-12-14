source("scripts/r/common.r")
source("scripts/r/ms3_common.r")

# ---- Helper function ----
normalise_request_log_df <- function(df) {
  
  first_request_time <- min(df$timeCreated)
  last_request_time <- max(df$timeCreated)
  DROP_TIMES_BEFORE = first_request_time + 2 * 60 * 1000
  DROP_TIMES_AFTER = last_request_time - 2 * 60 * 1000
  
  df2 <- df %>% filter(timeCreated > DROP_TIMES_BEFORE &
                          timeCreated <= DROP_TIMES_AFTER)
  return(df2)
}

# ---- Directories and files ----
output_dir <- "results/analysis/part3_network"
octave_dir_base <- paste0(output_dir, "/mva")
exp_dir <- "results/replication/S5_R1_rep5"
memaslap_file <- paste0(exp_dir, "/memaslap_stats.csv")
requests_file <- paste0(exp_dir, "/request.log")

# ---- Reading data ----
memaslap <- file_to_df(memaslap_file) %>% mutate(repetition=0)
requests <- file_to_df(requests_file, sep=",") %>%
  normalise_request_log_df()

# ---- Preprocessing ----
num_servers = 5 # TODO
num_threads = 32
num_clients = 180
perc_writes = 5 # TODO possibly

mss <- memaslap_summary(memaslap)

model_inputs <- function(requests, mss, request_type) {
  
  requests <- requests %>%
    filter(type == request_type)
  
  res <- list()
  res$type <- request_type
  res$lb_time <- mean(requests$timeEnqueued-requests$timeCreated)
  res$mwcomponent_time <- mean(requests$timeReturned-requests$timeDequeued)
  
  rt_middleware <- mean(requests$timeReturned-requests$timeCreated)
  
  if(request_type == "GET") {
    rt_memaslap <- mss$mean_response_time_get
  } else {
    rt_memaslap <- mss$mean_response_time_set
  }
  
  res$network_delay <- (rt_memaslap-rt_middleware)/2
  
  return(res)
}
inputs_get <- model_inputs(requests, mss, "GET") %>% as.data.frame()
inputs_set <- model_inputs(requests, mss, "SET") %>% as.data.frame()
inputs <- inputs_get %>% rbind(inputs_set)

# ---- Actual results ----
octave_output_file <- paste0(octave_dir_base, "/testing/results.mat")
arg_list <- paste(octave_output_file,
                  num_servers, num_threads, num_clients, perc_writes,
                  inputs_get$network_delay, inputs_set$network_delay,
                  inputs_get$lb_time, inputs_set$lb_time,
                  inputs_get$mwcomponent_time, inputs_set$mwcomponent_time,
                  collapse=" ")
system(paste0("octave scripts/oct/mva_main.m ", arg_list))

mva_results <- readMat(octave_output_file)



