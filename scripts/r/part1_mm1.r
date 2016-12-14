source("scripts/r/common.r")
source("scripts/r/ms3_common.r")

# ---- Directories ----
output_dir <- "results/analysis/part1_mm1"
trace_dir <- "results/trace_rep3"

# ---- Reading data ----
memaslap <- file_to_df(paste0(trace_dir, "/memaslap_stats.csv"))
requests <- file_to_df(paste0(trace_dir, "/request.log"), sep=",")


# ---- Preprocessing ----
DROP_TIMES_BEFORE_MS = 2 * 60 # How many seconds in the beginning we want to drop
DROP_TIMES_AFTER_MS = max((memaslap %>% filter(type=="t"))$time) - 2 * 60

first_request_time <- min(requests$timeCreated)
last_request_time <- max(requests$timeCreated)
DROP_TIMES_BEFORE_MW = first_request_time + 2 * 60 * 1000
DROP_TIMES_AFTER_MW = last_request_time - 2 * 60 * 1000

requests <- requests %>%
  filter(timeCreated > DROP_TIMES_BEFORE_MW & timeCreated <= DROP_TIMES_AFTER_MW)

# ------------------
# ---- Analysis ----
# ------------------
WINDOW_SIZE <- 1 # seconds
SAMPLING_RATE <- 100 # from exp1 setup
service_rates <- requests %>%
  mutate(secondCreated=floor(timeCreated/1000/WINDOW_SIZE)) %>%
  group_by(secondCreated) %>%
  summarise(count=n()) %>%
  arrange(desc(count))

# ---- Parameters ----
# TODO atm using kind of a shitty way to calc params
mu <- max(service_rates$count) / WINDOW_SIZE * SAMPLING_RATE # service rate
arrival_rate <- mean(service_rates$count) / WINDOW_SIZE * SAMPLING_RATE
rho = arrival_rate / mu # traffic intensity
print(paste0("Traffic intensity: ", round(rho, digits=2)))

# ---- Predictions ----
predicted = list()
predicted$type <- "predicted"
predicted$response_time_mean <- 1 / (mu) / (1 - rho) * 1000 # ms
predicted$response_time_std <- sqrt((mu^-2)/((1-rho)^2)) * 1000
predicted$response_time_quantile50 <- predicted$response_time_mean * log(1 / (1-0.5))
predicted$response_time_quantile95 <- predicted$response_time_mean * log(1 / (1-0.95))
predicted$waiting_time_mean <- rho * (1 / mu) / (1 - rho) * 1000 # ms
predicted$waiting_time_std <- sqrt((2-rho) * rho / (mu^2 * (1-rho)^2)) * 1000 # ms
predicted$utilisation <- rho
predicted$num_jobs_in_system_mean <- rho / (1-rho)		
predicted$num_jobs_in_system_std <- sqrt(rho / (1-rho)^2)
predicted$num_jobs_in_queue_mean <- rho^2 / (1-rho)
predicted$num_jobs_in_queue_std <- sqrt(rho^2 * (1 + rho - rho^2) / ((1-rho)^2))
predicted$num_jobs_served_in_busy_period_mean <- 1 / (1-rho)
predicted$num_jobs_served_in_busy_period_std <- sqrt(rho * (1 + rho) / (1 - rho)^3)
predicted$busy_period_duration_mean <- 1 / (mu * (1 - rho)) * 1000
predicted$busy_period_duration_std <- sqrt(1 / (mu^2 * (1-rho)^3) - 1 / (mu^2 * (1-rho)^2)) * 1000

# ---- Actual results ----
actual = list()

response_times <- requests$timeReturned - requests$timeCreated
queue_times <- requests$timeDequeued - requests$timeEnqueued

actual$type <- "actual"
actual$response_time_mean <- mean(response_times)
actual$response_time_std <- sd(response_times)
actual$response_time_quantile50 <- quantile(response_times, probs=c(0.5))
actual$response_time_quantile95 <- quantile(response_times, probs=c(0.95))
actual$waiting_time_mean <- mean(queue_times)
actual$waiting_time_std <- sd(queue_times)
actual$utilisation <- NA
actual$num_jobs_in_system_mean <- arrival_rate * actual$response_time_mean / 1000 # ms -> s # Little's law
actual$num_jobs_in_system_std <- NA
actual$num_jobs_in_queue_mean <- arrival_rate * actual$waiting_time_mean / 1000# TODO Little's law?
actual$num_jobs_in_queue_std <- NA
actual$num_jobs_served_in_busy_period_mean <- NA
actual$num_jobs_served_in_busy_period_std <- NA
actual$busy_period_duration_mean <- NA
actual$busy_period_duration_std <- NA

comparison <- rbind(data.frame(predicted), data.frame(actual)) %>%
  melt(id.vars=c("type")) %>%
  dcast(variable ~ type) %>%
  rename(metric=variable)

comparison_table <- xtable(comparison, caption="Comparison of experimental results ('actual') and predictions of the M/M/1 model ('predicted') for different metrics. Where the 'actual' column is empty, experimental data was not detailed enough to calculate the desired metric. All time units are milliseconds.",
                           label="tbl:part1:comparison_table")
print(comparison_table, file=paste0(output_dir, "/comparison_table.txt"))


# ---- Plots ----
# Quantiles of response time
quantiles <- c(0.01, seq(0.1, 0.9, 0.1), 0.99)
actual_response_times <- quantile(response_times, probs=quantiles)
predicted_response_times <- predicted$response_time_mean * log(1 / (1-quantiles))
predicted_response_times <- ifelse(quantiles > 1-rho, predicted_response_times, 0)

data2 <- data.frame(quantiles, actual=actual_response_times,
                    predicted=predicted_response_times) %>%
  melt(id.vars=c("quantiles"))
ggplot(data2, aes(x=value, y=quantiles, color=variable)) +
  geom_line(size=1) +
  geom_point(size=2) +
  facet_wrap(~variable, scales="free_x") +
  xlab("Response time") +
  ylab("Quantile") +
  asl_theme +
  theme(legend.position="none")
ggsave(paste0(output_dir, "/graphs/response_time_quantiles_actual_and_predicted.pdf"),
       width=fig_width, height=fig_height/2)


# Quantiles of waiting time
quantiles <- c(0.01, seq(0.1, 0.9, 0.1), 0.99)
actual_queue_times <- quantile(queue_times, probs=quantiles)
predicted_queue_times <- pmax(0, predicted$waiting_time_mean / rho * log((rho)/(1-quantiles)))

data3 <- data.frame(quantiles, actual=actual_queue_times,
                    predicted=predicted_queue_times) %>%
  melt(id.vars=c("quantiles"))
ggplot(data3, aes(x=value, y=quantiles, color=variable)) +
  geom_line(size=1) +
  geom_point(size=2) +
  facet_wrap(~variable, scales="free_x") +
  xlab("Waiting time") +
  ylab("Quantile") +
  asl_theme +
  theme(legend.position="none")
ggsave(paste0(output_dir, "/graphs/queue_time_quantiles_actual_and_predicted.pdf"),
       width=fig_width, height=fig_height/2)

