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
service_rates <- requests %>%
  mutate(secondCreated=floor(timeCreated/1000/WINDOW_SIZE)) %>%
  group_by(secondCreated) %>%
  summarise(count=n()) %>%
  arrange(desc(count))

# ---- Parameters ----
# TODO atm using kind of a shitty way to calc params
service_rate <- max(service_rates$count) / WINDOW_SIZE * 100 # 1/100 sampling
arrival_rate <- mean(service_rates$count) / WINDOW_SIZE * 100 # 1/100 sampling
traffic_intensity = arrival_rate / service_rate
print(paste0("Traffic intensity: ", round(traffic_intensity, digits=2)))

# ---- Predictions ----
predicted = list()
predicted$type <- "predicted"
predicted$mean_num_jobs_in_system <- traffic_intensity / (1-traffic_intensity)
predicted$mean_num_jobs_in_queue <- traffic_intensity^2 / (1-traffic_intensity)
predicted$utilisation <- 1 - traffic_intensity
predicted$mean_response_time <- 1 / (service_rate) / (1 - traffic_intensity) * 1000 # ms
predicted$response_time_q50 <- predicted$mean_response_time * log(100 / (100-50))
predicted$response_time_q95 <- predicted$mean_response_time * log(100 / (100-95))

# ---- Actual results ----
actual = list()

# Number of jobs in system
time_zero <- min(requests$timeCreated)
N_SAMPLES <- 5000
requests2 <- requests %>%
  select(timeEnqueued, timeDequeued, timeReturned) %>%
  mutate(timeEnqueued=timeEnqueued-time_zero,
         timeDequeued=timeDequeued-time_zero,
         timeReturned=timeReturned-time_zero) %>%
  top_n(N_SAMPLES, wt=desc(timeEnqueued))

distributions <- get_service_and_queue_distributions(requests2)
means <- distributions %>%
  summarise(queue=sum(num_elements * queue),
            service=sum(num_elements * service),
            total=sum(num_elements * total))

response_times <- requests$timeReturned - requests$timeEnqueued

actual$type <- "actual"
actual$mean_num_jobs_in_system <- means$total
actual$mean_num_jobs_in_queue <- means$queue
actual$utilisation <- 1 - (distributions %>% filter(num_elements==0))$total
actual$mean_response_time <- mean(response_times)
actual$response_time_q50 <- quantile(response_times, probs=c(0.5))
actual$response_time_q95 <- quantile(response_times, probs=c(0.95))

comparison <- rbind(data.frame(predicted), data.frame(actual))
