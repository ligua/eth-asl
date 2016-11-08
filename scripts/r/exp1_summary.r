source("scripts/r/common.r")

# ---- Parse command line args ----
args <- commandArgs(trailingOnly=TRUE)
if(length(args) == 0) {
  result_dir_base <- "results/throughput"
} else if(length(args) == 1) {
  result_dir_base <- args[1]
} else {
  stop("Arguments: [<results_directory>]")
}

# ---- Helper function ----
rep_summary <- function(df) {
  if(nrow(df) == 0) {
    res <- list()
    res$mean_tps <- NA
    res$std_tps <- NA
    res$mean_response_time <- NA
    res$std_response_time <- NA
    return(res)
  } 

  DROP_TIMES_BEFORE = 2 * 60 # How many seconds in the beginning we want to drop
  DROP_TIMES_AFTER = max((df %>% filter(type=="t"))$time) - 2 * 60
  
  df2 <- df %>%
    mutate(min=min/1000, max=max/1000, avg=avg/1000, std=std/1000) %>%
    filter(type=="t" & time > DROP_TIMES_BEFORE & time <= DROP_TIMES_AFTER) %>%
    filter(request_type=="GET")
  
  response_times <- df2 %>%
    group_by(time) %>%
    summarise(mean_response_time=sum(ops*avg)/sum(ops)) %>%
    select(time, mean_response_time)
  response_time_beginning <- (response_times %>%
    top_n(1, desc(time)))$mean_response_time
  response_time_end <- (response_times %>%
    top_n(1, time))$mean_response_time
  
  res <- list()
  tps_values <- (df2 %>% group_by(time) %>% summarise(tps=sum(tps)))$tps
  res$mean_tps <- mean(tps_values)
  res$std_tps <- sd(tps_values) # TODO calculate tps std over reps too
  res$mean_response_time <- mean(df2$avg)
  res$std_response_time <- sqrt(sum(df2$ops * df2$std * df2$std) / sum(df2$ops))
  res$response_time_beginning <- response_time_beginning
  res$response_time_end <- response_time_end
  
  return(res)
}



# ---- Loop over result dirs ----
file_name_regex <- paste0(result_dir_base,
                          "/clients(\\d{1,3})_threads(\\d{1,2})_rep(\\d{1,2})/memaslap_stats\\.csv$")
unfiltered_files <- list.files(path=".", "memaslap_stats.csv", recursive=TRUE)
filtered_files <- grep(file_name_regex, unfiltered_files, value=TRUE, perl=TRUE)

result_params <- as.data.frame(str_match(filtered_files, file_name_regex))
colnames(result_params) <- c("path", "clients", "threads", "repetition")
result_params <- result_params  %>%
  mutate(path=as.character(path))

results <- NA

for(i in 1:nrow(result_params)) {
  print(results)
  params <- result_params[i,]
  file_path <- params$path
  print(file_path)
  if(file.exists(file_path)) {
    df <- read.csv(file_path, header=TRUE, sep=";")
    result <- as.data.frame(rep_summary(df))
  } else {
    result <- data.frame()
  }
  
  if(is.na(results)) {
    results <- result
  } else {
    results <- rbind(results, result)
  }
}

all_results <- cbind(result_params, results) %>%
  mutate(clients=as.numeric(as.character(clients)),
         threads=as.numeric(as.character(threads)),
         repetition=as.numeric(as.character(repetition)))

# ---- Throughput vs clients ----
data1 <- all_results %>%
  filter(!is.na(mean_tps))
ggplot(data1, aes(x=clients, y=mean_tps)) +
  geom_ribbon(aes(ymin=mean_tps-std_tps, ymax=mean_tps+std_tps), fill=color_light, alpha=0.5) +
  geom_line(color=color_dark) +
  geom_point(color=color_dark) +
  facet_wrap(~threads) +
  asl_theme


# ---- Response time diff vs clients ----
data2 <- all_results %>%
  mutate(delta=ifelse(response_time_beginning > response_time_end, "faster", "slower"))
colour_scale <- scale_colour_manual(name = "grp", values = c("green", "red"))
ggplot(data2, aes(x=clients)) +
  geom_segment(aes(xend=clients, y=response_time_beginning, yend=response_time_end, color=delta),
               arrow=arrow(length=unit(0.02, "npc"), type="closed")) +
  ylim(0, NA) +
  colour_scale +
  ylab("Response time beginning -> end [ms]") + xlab("Number of clients") +
  facet_wrap(~threads) +
  asl_theme




