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

model_inputs <- function(requests, mss) {
  
  requests_get <- requests %>% filter(type == "GET")
  requests_set <- requests %>% filter(type == "SET")
  
  res <- list()
  res$tLB_get <- mean(requests_get$timeEnqueued-requests_get$timeCreated)
  res$tLB_set <- mean(requests_set$timeEnqueued-requests_set$timeCreated)
  res$tRW <- mean(requests_get$timeReturned-requests_get$timeDequeued)
  res$tWW <- mean(requests_set$timeForwarded-requests_set$timeDequeued)
  res$tMC <- mean(requests_set$timeReceived-requests_set$timeForwarded)
  res$tWWR <- mean(requests_set$timeReturned-requests_set$timeReceived)
  
  rt_middleware_get <- mean(requests_get$timeReturned-requests_get$timeCreated)
  rt_middleware_set <- mean(requests_set$timeReturned-requests_set$timeCreated)
  rt_memaslap_get <- mss$mean_response_time_get
  rt_memaslap_set <- mss$mean_response_time_set
  
  res$tNW_get <- (rt_memaslap_get-rt_middleware_get)/2
  res$tNW_set <- (rt_memaslap_set-rt_middleware_set)/2
  
  return(res)
}

exp_dir <- "./results/replication/S5_R5_rep5"

memaslap_file <- paste0(exp_dir, "/memaslap_stats.csv")
requests_file <- paste0(exp_dir, "/request.log")

# ---- Reading data ----
memaslap <- file_to_df(memaslap_file) %>% mutate(repetition=0)
requests <- file_to_df(requests_file, sep=",") %>%
  normalise_request_log_df()
requests_get <- requests %>% filter(type=="GET")
requests_set <- requests %>% filter(type=="SET")

# ---- Preprocessing ----
dir_name_regex <- paste0("/S(\\d)_R(\\d)_rep(\\d)$")
result_params <- as.data.frame(str_match(exp_dir, dir_name_regex))

dir_name_end <- substr(result_params$V1, 2,
                       nchar(as.character(result_params$V1)))
num_servers = as.numeric(as.character(result_params$V2))
num_replication = as.numeric(as.character(result_params$V3))
num_repetition = result_params$V4
num_threads = 32
num_clients = 180
perc_writes = 5
prop_writes = perc_writes / 100

mss <- memaslap_summary(memaslap) %>%
  mutate(type="actual")

inputs <- model_inputs(requests, mss) %>% as.data.frame()

# ---- Model results ----
octave_output_dir <- paste0(octave_dir_base, "/model2/", dir_name_end)
system(paste0("mkdir -p ", octave_output_dir))
octave_output_file <- paste0(octave_output_dir, "/results.mat")
arg_list <- paste(octave_output_file,
                  num_servers, num_replication, num_threads, num_clients,
                  perc_writes,
                  inputs$tNW_get, inputs$tNW_set,
                  inputs$tLB_get, inputs$tLB_set,
                  inputs$tWW, inputs$tRW, inputs$tMC, inputs$tWWR,
                  collapse=" ")
system(paste0("octave scripts/oct/mva2_main.m ", arg_list))
mva <- readMat(octave_output_file)

K <- ncol(mva$U) # number of nodes in the network
ind_RW = 3:(3+num_servers-1) # ReadWorker devices
ind_WW = (3+num_servers):(3+2*num_servers-1) # WriteWorker devices
ind_MC = (3+2*num_servers):(3+3*num_servers-1)
ind_WWR = (3+3*num_servers):(K-1) # WriteWorkerRet

predicted <- list()
predicted$type <- "predicted"
predicted$tps_mean <- sum(mva$X[1:2,1])
predicted$mean_response_time_get <- sum((mva$R * mva$V)[1,])*1000
predicted$mean_response_time_set <- sum((mva$R * mva$V)[2,])*1000
predicted$mean_response_time <-
  (1 - prop_writes) * predicted$mean_response_time_get +
  prop_writes / 100 * predicted$mean_response_time_set
predicted$rt_rw <- sum((mva$R * mva$V)[,ind_RW])*1000
predicted$rt_ww <- sum((mva$R * mva$V)[,c(ind_WW)])*1000

# ---- Actual results ----
tps_get <- (1-prop_writes) * mss$tps_mean # TODO this is an estimate -- could get precise!
tps_set <- prop_writes * mss$tps_mean
actual <- as.list(mss)
actual$rt_rw <- mean(requests_get$timeReturned-requests_get$timeEnqueued)
actual$rt_ww <- mean(requests_set$timeReceived-requests_set$timeEnqueued)



# ---- Analysis ----

comparison <- as.data.frame(actual) %>%
  select(-std_response_time) %>%
  rbind(as.data.frame(predicted)) %>%
  mutate(servers=num_servers, threads=num_threads, clients=num_clients,
         writes=perc_writes, replication=num_replication,
         repetition=num_repetition)
comparison

# Time breakdown: actual vs predicted
data1 <- comparison %>%
  select(rt_rw, rt_ww, type) %>%
  melt(id.vars=c("type"))

ggplot(data1, aes(x=type, y=value, fill=type)) +
  geom_bar(stat="identity") +
  facet_wrap(~variable) +
  asl_theme
