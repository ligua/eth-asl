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
    mutate(type="actual") %>%
    as.list()
  
  inputs_get <- model_inputs(requests, mss, "GET") %>% as.data.frame()
  inputs_set <- model_inputs(requests, mss, "SET") %>% as.data.frame()
  inputs <- inputs_get %>% rbind(inputs_set)
  
  # ---- Model results ----
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
  
  K <- ncol(mva$U) # number of nodes in the network
  predicted <- list()
  predicted$type <- "predicted"
  predicted$tps_mean <- sum(mva$X[1:2,1])
  predicted$mean_response_time_get <- sum((mva$R * mva$V)[1,])*1000
  predicted$mean_response_time_set <- sum((mva$R * mva$V)[2,])*1000
  predicted$mean_response_time <-
    (1 - perc_writes / 100) * predicted$mean_response_time_get +
    perc_writes / 100 * predicted$mean_response_time_set
  predicted$mean_response_time_lb_get <- mva$R[1,2] * 1000
  predicted$mean_response_time_lb_set <- mva$R[2,2] * 1000
  predicted$mean_response_time_worker_get <- mva$R[1,3] * 1000
  predicted$util_lb_get <- mva$U[1,2]
  predicted$util_lb_set <- mva$U[2,2]
  predicted$util_worker_get <- mva$U[1,3]
  predicted$util_worker_set <- mva$U[2,K-1]
  predicted$items_network_get <- mva$Q[1,1]
  predicted$items_network_set <- mva$Q[2,1]
  predicted$items_lb_get <- mva$Q[1,2]
  predicted$items_lb_set <- mva$Q[2,2]
  predicted$items_worker_get <- mva$Q[1,3]
  predicted$items_worker_set <- mva$Q[2,K-1]
  predicted$tps_worker_get <- mva$X[1,3]
  predicted$tps_worker_set <- mva$X[2,K-1]
  
  
  # ---- Analysis ----
  
  comparison <- as.data.frame(mss) %>%
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

# Predicted response time and actual response time, vs servers and replication
data1 <- all_results %>%
  select(replication_str, servers_str, repetition, type,
         mean_response_time_get, mean_response_time_set) %>%
  group_by(replication_str, servers_str, type) %>%
  summarise(mean_response_time_get=mean(mean_response_time_get),
            mean_response_time_set=mean(mean_response_time_set)) %>%
  rename(GET=mean_response_time_get, SET=mean_response_time_set) %>%
  melt(id.vars=c("replication_str", "servers_str", "type"))
ggplot(data1,
             aes(x=replication_str, y=value, group=type)) +
  geom_line(aes(color=type), size=1) +
  facet_wrap(~ variable + servers_str, ncol=3) +
  ylim(0, NA) +
  asl_theme

# ---- Estimate memcached service time ----
mc_data <- read.csv("results/baseline/aggregated.csv", header=TRUE, sep=";") %>%
  mutate(tmin=tmin/1000, tmax=tmax/1000, tavg=tavg/1000, tgeo=tgeo/1000, tstd=tstd/1000)
fitting_data <- mc_data %>%
  filter(concurrency <= 3000) %>%
  select(concurrency, tavg, tmin) %>%
  group_by(concurrency) %>%
  summarise(tavg=mean(tavg), tmin=mean(tmin)) %>%
  mutate(tservice=tavg-tmin)
ggplot(fitting_data, aes(x=concurrency)) +
  geom_line(aes(y=tmin), color="red") +
  geom_line(aes(y=tavg)) +
  ylim(0, NA) +
  asl_theme