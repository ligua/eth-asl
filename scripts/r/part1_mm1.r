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
actual = list()
predicted$mean_num_jobs_in_system <- traffic_intensity / (1-traffic_intensity)
predicted$utilisation <- 1 - traffic_intensity
predicted$mean_response_time <- 1 / (service_rate) / (1 - traffic_intensity)
predicted$response_time_q50 <- predicted$mean_response_time * log(100 / (100-50))
predicted$response_time_q95 <- predicted$mean_response_time * log(100 / (100-95))

print(predicted)


