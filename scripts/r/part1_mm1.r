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
service_rate <- max(service_rates$count) / WINDOW_SIZE * SAMPLING_RATE
arrival_rate <- mean(service_rates$count) / WINDOW_SIZE * SAMPLING_RATE
traffic_intensity = arrival_rate / service_rate
print(paste0("Traffic intensity: ", round(traffic_intensity, digits=2)))

# ---- Predictions ----
predicted = list()
predicted$type <- "predicted"
predicted$utilisation <- 1 - traffic_intensity
predicted$mean_response_time <- 1 / (service_rate) / (1 - traffic_intensity) * 1000 # ms
predicted$response_time_q50 <- predicted$mean_response_time * log(1 / (1-0.5))
predicted$response_time_q95 <- predicted$mean_response_time * log(1 / (1-0.95))

# ---- Actual results ----
actual = list()

response_times <- requests$timeReturned - requests$timeCreated

actual$type <- "actual"
actual$utilisation <- 1 - (distributions %>% filter(num_elements==0))$total
actual$mean_response_time <- mean(response_times)
actual$response_time_q50 <- quantile(response_times, probs=c(0.5))
actual$response_time_q95 <- quantile(response_times, probs=c(0.95))

comparison <- rbind(data.frame(predicted), data.frame(actual)) %>%
  melt(id.vars=c("type")) %>%
  dcast(variable ~ type)

comparison_table <- xtable(comparison, caption="Comparison of experimental results and predictions of the M/M/1 model.",
                           label="tbl:part1:comparison_table")
print(comparison_table, file=paste0(output_dir, "/comparison_table.txt"))


# ---- Plots ----
# Quantiles of response time
quantiles <- c(0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99)
actual_response_times <- quantile(response_times, probs=quantiles)
predicted_response_times <- predicted$mean_response_time * log(100 / (100-quantiles))
predicted_response_times <- ifelse(quantiles > 1-traffic_intensity, predicted_response_times, 0)

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
ggsave(paste0(output_dir, "/graphs/quantiles_actual_and_predicted.pdf"),
       width=fig_width, height=fig_height/2)



