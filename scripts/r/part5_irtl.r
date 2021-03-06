source("scripts/r/common.r")
source("scripts/r/ms3_common.r")

# ---- Directories ----
output_dir <- "results/analysis/part5_irtl"
result_dir_base <- "results/replication"

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
    repetition_result <- file_to_df(file_path) %>%
      mutate(repetition=rep_id)
    
    ms_result_row <- memaslap_summary(repetition_result)
    ms_result_row$repetition_id <- rep_id
    ms_result_row$replication <- n_replication
    ms_result_row$servers <- n_servers
    
    if(is.na(results)) {
      results <- ms_result_row
    } else {
      results <- rbind(results, ms_result_row)
    }
  }
}

all_results <- sr_combinations %>%
  full_join(results, by=c("servers", "replication")) %>%
  mutate(servers=as.numeric(as.character(servers)),
         replication=as.numeric(as.character(replication)),
         repetition=as.numeric(as.character(repetition_id))) %>%
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
  X <- X / 1000  # convert throughput from s to ms
  return((N / X - R))
}
get_response_time <- function(N, X, Z) {
  return(N / X - Z)
}
get_throughput <- function(N, R, Z) {
  X <- N / (R + Z)
  return(X * 1000) # convert from ms to s
}

N = 180 # constant

data <- all_results %>%
  select(servers, replication, repetition,
         tps_mean, mean_response_time) %>%
  rename(X=tps_mean, R=mean_response_time) %>%
  mutate(Z_est=get_wait_time(N, R, X)) %>%
  mutate(X_est=get_throughput(N, R, 0))

# Predicted throughput vs actual throughput
ggplot(data, aes(x=X, y=X_est)) +
  geom_abline(intercept=0, slope=1, color="red") +
  geom_point(color=color_dark) +
  geom_line(color=color_dark) +
  xlab("Actual throughput") +
  ylab("Predicted throughput") +
  ylim(0, NA) +
  asl_theme
ggsave(paste0(output_dir, "/graphs/predicted_vs_actual_throughput.pdf"),
       width=fig_width/2, height=fig_height/2)

# Error percentage distribution
ggplot(data, aes(x=(X_est-X)/X)) +
  geom_histogram(bins=10, fill=color_light, color=color_medium) +
  scale_x_continuous(labels = scales::percent) +
  xlab("Relative error in predicted throughput") +
  ylab("Number of experiments") +
  asl_theme
ggsave(paste0(output_dir, "/graphs/error_percentage.pdf"),
       width=fig_width/2, height=fig_height/2)

# Mean error
mean_err <- mean((data$X_est-data$X)/data$X)
print(paste0("Mean prediction error for throughput: ",
             round(mean_err*100, digits=2), "%"))

# Mean Z_est
mean_Z_est <- mean(data$Z_est)
print(paste0("Mean estimated wait time (Z_est): ",
             round(mean_Z_est, digits=3), "ms"))

# ------------------------------------
# ---- Error vs number of clients ----
# ------------------------------------
file_name_regex <- paste0("results/throughput/clients(\\d{1,3})_threads(\\d{1,2})_rep(\\d{1,2})/memaslap_stats\\.csv$")
unfiltered_files <- list.files(path=".", "memaslap_stats.csv", recursive=TRUE)
filtered_files <- grep(file_name_regex, unfiltered_files, value=TRUE, perl=TRUE)

result_params <- as.data.frame(str_match(filtered_files, file_name_regex))
colnames(result_params) <- c("path", "clients", "threads", "repetition")
result_params <- result_params  %>%
  mutate(path=as.character(path))

result_temp <- NA
for(i in 1:nrow(result_params)) {
  n_clients <- result_params[i,]$clients
  n_threads <- result_params[i,]$threads
  rep_id <- result_params[i,]$repetition
  memaslap <- file_to_df(result_params[i,]$path, sep=";") %>%
    mutate(repetition=rep_id, clients=n_clients)
  
  mss <- memaslap_summary(memaslap) %>%
    mutate(repetition=rep_id, clients=n_clients, threads=n_threads)
  
  if(is.na(result_temp)) {
    result_temp <- mss
  } else {
    result_temp <- rbind(result_temp, mss)
  }
}

result <- result_temp %>%
  select(repetition, clients, threads, tps_mean, mean_response_time_get) %>%
  mutate(clients=as.numeric(as.character(clients)),
         threads=as.factor(paste0(threads, " threads"))) %>%
  rename(N=clients, X=tps_mean, R=mean_response_time_get) %>%
  mutate(X_est=get_throughput(N, R, 0)) %>%
  mutate(X_rel_err=(X_est-X)/X)


ggplot(result %>% group_by(N, threads) %>% top_n(1) %>% filter(threads=="32 threads"),
       aes(x=N)) +
  geom_point(aes(y=X), size=2) +
  geom_line(aes(y=X), size=1) +
  geom_line(aes(y=X_est), color="red") +
  xlab("Number of clients") +
  ylim(0, NA) +
  asl_theme

ggplot(result %>% group_by(N, threads) %>% summarise(X_rel_err=mean(X_rel_err)),
       aes(x=N, y=abs(X_rel_err), color=threads)) +
  geom_point(size=2) +
  geom_line(size=1) +
  xlab("Number of clients") +
  ylab("Magnitude of relative error in predicted throughput") +
  ylim(0, NA) +
  asl_theme
ggsave(paste0(output_dir, "/graphs/irtl_error_vs_clients_and_threads.pdf"),
       width=fig_width, height=fig_height)


# ---- IRTL for baseline ----
# 2 memaslaps
X <- 17376 + 16464
R <- (1051320*3.674 + 996672*3.880) / (1051320+996672)
N <- 128
X_est <- get_throughput(N, R, 0)
(X_est - X) / X_est * 100

# 1 memaslap
X <- 1552
R <- 0.641
N <- 1
X_est <- get_throughput(N, R, 0)
(X_est - X) / X_est * 100

