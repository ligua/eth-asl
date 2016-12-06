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


get_service_and_queue_distributions <- function(requests2) {
  
  total_timestamps <- c()
  queue_timestamps <- c()
  service_timestamps <- c()
  for(i in 1:nrow(requests2)) {
    if(i %% 1000 == 0) {
      print(paste0("At row ", i, " out of ", nrow(requests2)))
    }
    row <- requests2[i,]
    total_expanded <- seq(row$timeEnqueued, row$timeReturned, 1)
    queue_expanded <- seq(row$timeEnqueued, row$timeDequeued, 1)
    service_expanded <- seq(row$timeDequeued, row$timeReturned, 1)
    total_timestamps <- append(total_timestamps, total_expanded)
    queue_timestamps <- append(queue_timestamps, queue_expanded)
    service_timestamps <- append(service_timestamps, service_expanded)
  }
  
  total_counts <- data.frame(timestamp=total_timestamps) %>%
    group_by(timestamp) %>%
    summarise(num_elements=n())
  zeros <- data.frame(timestamp=seq(0, max(total_counts$timestamp), 1))
  total_counts <- total_counts %>%
    full_join(zeros, by=c("timestamp")) %>%
    mutate(num_elements=ifelse(is.na(num_elements), 0, num_elements)) %>%
    group_by(num_elements) %>%
    summarise(count=n())
  
  queue_counts <- data.frame(timestamp=queue_timestamps) %>%
    group_by(timestamp) %>%
    summarise(num_elements=n())
  zeros <- data.frame(timestamp=seq(0, max(queue_counts$timestamp), 1))
  queue_counts <- queue_counts %>%
    full_join(zeros, by=c("timestamp")) %>%
    mutate(num_elements=ifelse(is.na(num_elements), 0, num_elements)) %>%
    group_by(num_elements) %>%
    summarise(count=n())
  
  service_counts <- data.frame(timestamp=service_timestamps) %>%
    group_by(timestamp) %>%
    summarise(num_elements=n())
  zeros <- data.frame(timestamp=seq(0, max(service_counts$timestamp), 1))
  service_counts <- service_counts %>%
    full_join(zeros, by=c("timestamp")) %>%
    mutate(num_elements=ifelse(is.na(num_elements), 0, num_elements)) %>%
    group_by(num_elements) %>%
    summarise(count=n())
  
  counts <- queue_counts %>%
    full_join(service_counts, by=c("num_elements")) %>%
    rename(queue=count.x, service=count.y) %>%
    full_join(total_counts, by=c("num_elements")) %>%
    rename(total=count) %>%
    mutate(queue=ifelse(is.na(queue), 0, queue),
           service=ifelse(is.na(service), 0, service),
           total=ifelse(is.na(total), 0, total)) %>%
    mutate(queue=queue/sum(queue),
           service=service/sum(service),
           total=total/sum(total))
  
  return(counts)
}