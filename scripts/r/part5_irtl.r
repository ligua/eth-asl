source("scripts/r/common.r")


# ---- Directories ----
output_dir <- "results/analysis/part5_irtl"
result_dir_base <- "results/replication"

# ---------------------------
# ---- HELPER FUNCTIONS -----
# ---------------------------

memaslap_summary <- function(df) {
  DROP_TIMES_BEFORE = 0 #2 * 60 # How many seconds in the beginning we want to drop
  DROP_TIMES_AFTER = max((df %>% filter(type=="t"))$time) # - 2 * 60
  
  df2 <- df %>%
    mutate(min=min/1000, max=max/1000, avg=avg/1000, std=std/1000) %>%
    filter(type=="t" & time > DROP_TIMES_BEFORE & time <= DROP_TIMES_AFTER)
  
  means <- df2 %>%
    group_by(request_type) %>%
    summarise(mean_response_time=sum(ops*avg)/sum(ops))
  
  response_times <- df2 %>%
    group_by(time) %>%
    summarise(mean_response_time=sum(ops*avg)/sum(ops)) %>%
    select(time, mean_response_time)
  
  res <- list()
  tps_summed <- df2 %>% group_by(time, repetition) %>%
    summarise(tps=sum(tps))
  tps_values <- tps_summed$tps
  res$tps_mean <- mean(tps_values)
  res$tps_std <- sd(tps_values)
  two_sided_t_val <- qt(c(.025, .975), df=length(tps_values)-1)[2]
  res$tps_confidence_delta <- two_sided_t_val * res$tps_std/sqrt(length(tps_values))
  res$tps_confidence_delta_rel <- res$tps_confidence_delta / res$tps_mean
  res$mean_response_time_get <- (means %>% filter(request_type=="GET"))$mean_response_time[1]
  res$mean_response_time_set <- (means %>% filter(request_type=="SET"))$mean_response_time[1]
  res$mean_response_time <- (res$mean_response_time_get * sum((df2 %>% filter(request_type=="GET"))$ops) +
                               res$mean_response_time_set * sum((df2 %>% filter(request_type=="SET"))$ops)) / sum(df2$ops)
  res$std_response_time <- sqrt(sum(df2$ops * df2$std * df2$std) / sum(df2$ops))
  
  return(as.data.frame(res))
}

middleware_summary <- function(dfmw) {
  num_requests <- length(dfmw$tAll)
  
  res <- list()
  res$num_requests <- num_requests
  res$response_time_mean <- mean(dfmw$tAll)
  res$response_time_std <- sd(dfmw$tAll)
  two_sided_t_val <- qt(c(.025, .975), df=num_requests-1)[2]
  res$response_time_confidence_delta <-
    two_sided_t_val * res$response_time_std/sqrt(num_requests)
  res$response_time_confidence_delta_rel <-
    res$response_time_confidence_delta / res$response_time_mean
  res$response_time_q01 <- quantile(dfmw$tAll, 0.01)
  res$response_time_q05 <- quantile(dfmw$tAll, 0.05)
  res$response_time_q25 <- quantile(dfmw$tAll, 0.25)
  res$response_time_q50 <- quantile(dfmw$tAll, 0.50)
  res$response_time_q75 <- quantile(dfmw$tAll, 0.75)
  res$response_time_q95 <- quantile(dfmw$tAll, 0.95)
  res$response_time_q99 <- quantile(dfmw$tAll, 0.99)
  res$tLoadBalancer <- mean(dfmw$tLoadBalancer)
  res$tQueue <- mean(dfmw$tQueue)
  res$tWorker <- mean(dfmw$tWorker)
  res$tMemcached <- mean(dfmw$tMemcached)
  res$tReturn <- mean(dfmw$tReturn)
  res$tAll <- mean(dfmw$tReturn)
  
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
    mutate(tLoadBalancer=timeEnqueued-timeCreated,
           tQueue=timeDequeued-timeEnqueued,
           tWorker=timeForwarded-timeDequeued,
           tMemcached=timeReceived-timeForwarded,
           tReturn=timeReturned-timeReceived,
           tAll=timeReturned-timeCreated)
  
  first_request_time <- min(df2$timeCreated)
  last_request_time <- max(df2$timeCreated)
  DROP_TIMES_BEFORE = first_request_time # + 2 * 60 * 1000
  DROP_TIMES_AFTER = last_request_time # - 2 * 60 * 1000
  
  df2 <- df2 %>% filter(timeCreated > first_request_time &
                          timeCreated >= DROP_TIMES_AFTER) %>%
    select(-timeCreated, -timeEnqueued, -timeDequeued, -timeForwarded,
           -timeReceived, -timeReturned)
  return(df2)
}

# ------------------
# ---- FILE IO -----
# ------------------

# ---- Loop over result dirs ----
file_name_regex <- paste0(result_dir_base,
                          "/S(\\d)_R(\\d)_rep([5-7])/memaslap_stats\\.csv$")
unfiltered_files <- list.files(path=".", "memaslap_stats.csv", recursive=TRUE)
filtered_files <- grep(file_name_regex, unfiltered_files, value=TRUE, perl=TRUE)

result_params <- as.data.frame(str_match(filtered_files, file_name_regex))
colnames(result_params) <- c("path", "servers", "replication", "repetition")
result_params <- result_params  %>%
  mutate(path=as.character(path))
# group_by(clients, threads) %>%
#summarise(paths=paste0(path, collapse=";"))

results <- NA
mw_results <- NA
sr_combinations <- result_params %>%
  select(servers, replication) %>%
  unique()

for(i in 1:nrow(sr_combinations)) {
  n_servers <- sr_combinations[i,]$servers
  n_replication <- sr_combinations[i,]$replication
  repetitions <- result_params %>%
    filter(servers==n_servers & replication==n_replication)
  
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
    
    ms_result_row <- memaslap_summary(repetition_result)
    mw_result_row <- middleware_summary(mw_result) %>%
      mutate(servers=n_servers, replication=n_replication)
    
    if(is.na(results)) {
      results <- ms_result_row
      mw_results <- mw_result_row
    } else {
      results <- rbind(results, ms_result_row)
      mw_results <- rbind(mw_results, mw_result_row)
    }
  }
}

all_results <- cbind(sr_combinations, results) %>%
  right_join(mw_results, by=c("servers", "replication")) %>%
  mutate(servers=as.numeric(as.character(servers)),
         replication=as.numeric(as.character(replication))) %>%
  mutate(replication_str=get_replication_factor(servers, replication),
         servers_str=paste0(servers, " servers"))

write.csv(all_results, file=paste0(output_dir, "/all_results.csv"),
          row.names=FALSE)


# ------------------
# ---- Analysis ----
# ------------------

# IRTL: R = N / X - Z  <==> Z = N / X - R <==> X = N / (R + Z)
# R - response time
# Z - think time
# N - number of users
# X - throughput

get_wait_time <- function(N, R, X) {
  return(N / X - R)
}
get_response_time <- function(N, X, Z) {
  return(N / X - Z)
}
get_throughput <- function(N, R, Z) {
  return(N / (R + Z))
}

N = 180 # constant



