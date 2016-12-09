source("scripts/r/common.r")
source("scripts/r/ms3_common.r")

K <- 2
R <- 3

# ---- Directories and files ----
output_dir <- "results/analysis/part4_2k"
data_file <- "results/analysis/part5_irtl/all_results.csv"

make_predictions <- function(coeff, vec1, vec2, vec3, vec4) {
  return(coeff[[1]] * vec1 +
           coeff[[2]] * vec2 +
           coeff[[3]] * vec3 +
           coeff[[4]] * vec4)
}

# ---- Reading data ----
exp_results_raw <- read.csv(data_file)

# ---- Preprocessing ----
exp_results <- exp_results_raw %>%
  select(servers, replication, repetition, tps_mean, mean_response_time,
         replication_str, servers_str) %>%
  filter(servers != 5 & replication_str != "half") %>%
  mutate(x_constant=1,
         x_servers=ifelse(servers==3, -1, 1),
         x_replication=ifelse(replication_str=="none", -1, 1)) %>%
  mutate(x_servers_times_replication=x_servers*x_replication)

# ---- Fitting model ----
averaged <- exp_results %>%
  group_by(x_constant, x_servers, x_replication, x_servers_times_replication) %>%
  summarise(tps_mean=mean(tps_mean)) %>%
  select(x_constant, x_servers, x_replication, x_servers_times_replication, tps_mean)

solution <- solve(averaged[1:4], as.matrix(averaged[5]))
coefficients <- c(solution)
names(coefficients) <- attr(solution, "dimnames")[[1]]


# ---- Making predictions ----
with_predictions <- exp_results %>%
  mutate(tps_predicted=make_predictions(coefficients, x_constant, x_servers, x_replication, x_servers_times_replication)) %>%
  mutate(error=tps_predicted-tps_mean)

# ---- Allocation of variation ----
tps_overall_mean <- mean(with_predictions$tps_mean)
var_total <- sum((with_predictions$tps_mean-tps_overall_mean)^2)
var_error <- sum(with_predictions$error^2)
var_servers <- sum(K^2 * R * coefficients["x_servers"]^2)
var_replication <- sum(K^2 * R * coefficients["x_replication"]^2)
var_servers_times_replication <- sum(K^2 * R * coefficients["x_servers_times_replication"]^2)
variations <- data.frame(var_servers, var_replication, var_servers_times_replication,
                         var_error, var_total) %>%
  melt() %>%
  mutate(value=value/var_total) %>%
  rename(variation=value) %>%
  filter(variable != "var_total")

# Save variation table
variation_table <- xtable(variations, caption="\\todo{} caption",
                           label="tbl:part4:variation",
                           digits=c(NA, NA, 3))
print(variation_table, file=paste0(output_dir, "/variation_table.txt"))


# ---- Plots ----
# Prediction and actual, vs servers and replication
data1 <- with_predictions %>%
  select(replication_str, servers_str, tps_mean, tps_predicted) %>%
  group_by(replication_str, servers_str) %>%
  summarise(actual=mean(tps_mean), predicted=mean(tps_predicted)) %>%
  melt(id.vars=c("replication_str", "servers_str"))
ggplot(data1,aes(x=replication_str, y=value, color=variable)) +
  geom_point(aes(y=value)) +
  facet_wrap(~servers_str, ncol=3) +
  #ylim(0, NA) +
  ylab("Throughput (requests per second)") +
  xlab("Replication") +
  asl_theme

# Error
ggplot(with_predictions, aes(x=tps_predicted, y=error)) +
  geom_point() +
  asl_theme