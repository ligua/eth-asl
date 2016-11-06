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
  DROP_TIMES_BEFORE = 3 * 60 # How many seconds in the beginning we want to drop
  DROP_TIMES_AFTER = max((df %>% filter(type=="t"))$time) - 2 * 60
  
  df2 <- df %>%
    mutate(min=min/1000, max=max/1000, avg=avg/1000, std=std/1000) %>%
    filter(type=="t" & time >= DROP_TIMES_BEFORE & time <= DROP_TIMES_AFTER) %>%
    filter(request_type=="GET")
  
  res <- list()
  res$mean_tps <- mean(df2$tps)
  res$std_tps <- NA # TODO calculate tps std over reps too
  res$mean_response_time <- mean(df2$avg)
  res$std_response_time <- sqrt(sum(df2$ops * df2$std * df2$std) / sum(df2$ops))
  
  return(res)
}



# ---- Loop over result dirs ----
dir_name_regex <- "results/throughput/clients(\\d{1,3})_threads(\\d{1,2})_rep(\\d{1,2})$"
unfiltered_dirs <- list.dirs("results/throughput")
filtered_dirs <- grep(dir_name_regex, unfiltered_dirs, value=TRUE, perl=TRUE)

result_params <- as.data.frame(str_match(filtered_dirs, dir_name_regex))
colnames(result_params) <- c("path", "clients", "threads", "repetition")

results <- NA

for(i in 1:nrow(result_params)) {
  params <- result_params[i,]
  df <- read.csv(paste0(params$path, "/memaslap_stats.csv"), header=TRUE, sep=";")
  result <- as.data.frame(rep_summary(df))
  if(is.na(results)) {
    results <- result
  } else {
    results <- rbind(results, result)
  }
}









