source("scripts/r/common.r")
source("scripts/r/ms3_common.r")

# ---- Directories and files ----
output_dir <- "results/analysis/part3_network"
octave_dir_base <- paste0(output_dir, "/mva")
data_source_dir <- "results/replication"

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

get_network_results <- function(exp_dir) {
  memaslap_file <- paste0(exp_dir, "/memaslap_stats.csv")
  requests_file <- paste0(exp_dir, "/request.log")
  
  # ---- Reading data ----
  memaslap <- file_to_df(memaslap_file) %>% mutate(repetition=0)
  requests <- file_to_df(requests_file, sep=",") %>%
    normalise_request_log_df()
  
  # ---- Preprocessing ----
  dir_name_regex <- paste0("/S(\\d)_R(\\d)_rep(\\d)$")
  result_params <- as.data.frame(str_match(exp_dir, dir_name_regex))
  
  dir_name_end <- substr(result_params$V1, 2,
                         nchar(as.character(result_params$V1)))
  num_servers = result_params$V2
  num_replication = result_params$V3
  num_repetition = result_params$V4
  num_threads = 32
  num_clients = 180
  perc_writes = 5
  
  mss <- memaslap_summary(memaslap) %>%
    mutate(type="actual")
  
  inputs_get <- model_inputs(requests, mss, "GET") %>% as.data.frame()
  inputs_set <- model_inputs(requests, mss, "SET") %>% as.data.frame()
  inputs <- inputs_get %>% rbind(inputs_set)
  
  # ---- Actual results ----
  octave_output_dir <- paste0(octave_dir_base, "/model1/", dir_name_end)
  system(paste0("mkdir -p ", octave_output_dir))
  octave_output_file <- paste0(octave_output_dir, "/results.mat")
  arg_list <- paste(octave_output_file,
                    num_servers, num_threads, num_clients, perc_writes,
                    inputs_get$network_delay, inputs_set$network_delay,
                    inputs_get$lb_time, inputs_set$lb_time,
                    inputs_get$mwcomponent_time, inputs_set$mwcomponent_time,
                    collapse=" ")
  system(paste0("octave scripts/oct/mva_main.m ", arg_list))
  mva <- readMat(octave_output_file)
  
  # ---- Analyse results ----
  
  predicted <- list()
  predicted$type <- "predicted"
  predicted$tps_mean <- sum(mva$X[1:2,1])
  predicted$mean_response_time_get <- sum((mva$R * mva$V)[1,])*1000
  predicted$mean_response_time_set <- sum((mva$R * mva$V)[2,])*1000
  predicted$mean_response_time <-
    (1 - perc_writes / 100) * predicted$mean_response_time_get +
    perc_writes / 100 * predicted$mean_response_time_set
  
  comparison <- mss %>%
    select(-std_response_time) %>%
    rbind(as.data.frame(predicted)) %>%
    mutate(servers=num_servers, threads=num_threads, clients=num_clients,
           writes=perc_writes, replication=num_replication,
           repetition=num_repetition)
  comparison
  return(comparison)
}

# ---- Loop through files ----
dir_name_regex <- paste0(data_source_dir,
                          "/S(\\d)_R(\\d)_rep([5-7])$")
unfiltered_dirs <- list.dirs(path=".", recursive=TRUE)
filtered_dirs <- grep(dir_name_regex, unfiltered_dirs, value=TRUE, perl=TRUE)

results <- NA
for(i in 1:length(filtered_dirs)) {
  dirname <- filtered_dirs[i]
  comparison <- get_network_results(dirname)
  
  if(is.na(results)) {
    results <- comparison
  } else {
    results <- rbind(results, comparison)
  }
}

write.csv(results, file=paste0(output_dir, "/results.csv"),
          row.names=FALSE)

# ---- Plotting ----
all_results <- results %>%
  mutate(servers=as.numeric(as.character(servers)),
         replication=as.numeric(as.character(replication)),
         replication_str=get_replication_factor(servers, replication),
         servers_str=paste0(servers, " servers"))
ggplot(all_results %>% filter(repetition==6),
             aes(x=replication_str, y=mean_response_time_set, group=type)) +
  geom_line(aes(color=type)) +
  facet_wrap(~servers_str, ncol=3) +
  ylim(0, NA) +
  asl_theme
