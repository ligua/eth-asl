source("scripts/r/common.r")

memaslap_summary <- function(df) {
  DROP_TIMES_BEFORE = 0 #2 * 60 # How many seconds in the beginning we want to drop
  DROP_TIMES_AFTER = max((df %>% filter(type=="t"))$time) # - 2 * 60
  
  df2 <- df %>%
    mutate(min=min/1000, max=max/1000, avg=avg/1000, std=std/1000) %>%
    filter(type=="t" & time > DROP_TIMES_BEFORE & time <= DROP_TIMES_AFTER)
  
  means <- df2 %>%
    group_by(request_type) %>%
    summarise(mean_response_time=sum(ops*avg)/sum(ops))
  
  res <- list()
  tps_summed <- df2 %>% group_by(time, repetition) %>%
    summarise(tps=sum(tps))
  tps_values <- tps_summed$tps
  res$tps_mean <- mean(tps_values)
  res$mean_response_time_get <- (means %>% filter(request_type=="GET"))$mean_response_time[1]
  res$mean_response_time_set <- (means %>% filter(request_type=="SET"))$mean_response_time[1]
  res$mean_response_time <- (res$mean_response_time_get * sum((df2 %>% filter(request_type=="GET"))$ops) +
                               res$mean_response_time_set * sum((df2 %>% filter(request_type=="SET"))$ops)) / sum(df2$ops)
  res$std_response_time <- sqrt(sum(df2$ops * df2$std * df2$std) / sum(df2$ops))
  
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