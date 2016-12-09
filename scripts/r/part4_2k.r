source("scripts/r/common.r")
source("scripts/r/ms3_common.r")

K <- 3
R <- 3

# ---- Directories and files ----
output_dir <- "results/analysis/part4_2k"
data_file <- "results/writes/detailed_results.csv"

make_predictions <- function(coeff, vec1, vec2, vec3, vec4, vec5, vec6, vec7, vec8) {
  return(coeff[[1]] * vec1 +
           coeff[[2]] * vec2 +
           coeff[[3]] * vec3 +
           coeff[[4]] * vec4 +
           coeff[[5]] * vec5 +
           coeff[[6]] * vec6 +
           coeff[[7]] * vec7 +
           coeff[[8]] * vec8)
}

# ---- Reading data ----
exp_results_raw <- read.csv(data_file)

# ---- Preprocessing ----
exp_results <- exp_results_raw %>%
  select(servers, replication, writes, repetition, tps_mean, mean_response_time) %>%
  filter(servers != 5) %>%
  filter(replication == 1 | replication == servers) %>%
  filter(writes == 1 | writes == 10) %>%
  mutate(replication_str=get_replication_factor(servers, replication),
         writes_str=get_writes_factor(writes),
         servers_str=paste0(servers, " servers")) %>%
  mutate(x0_constant=1,
         xa_servers=ifelse(servers==3, -1, 1),
         xb_replication=ifelse(replication_str=="none", -1, 1),
         xc_writes=ifelse(writes==1, -1, 1)) %>%
  mutate(x_ab=xa_servers*xb_replication,
         x_bc=xb_replication*xc_writes,
         x_ac=xa_servers*xc_writes,
         x_abc=xa_servers*xb_replication*xc_writes) %>%
  mutate(tps_mean=tps_mean)

# ---- Fitting model ----
averaged <- exp_results %>%
  group_by(x0_constant, xa_servers, xb_replication, xc_writes,
           x_ab, x_bc, x_ac, x_abc) %>%
  summarise(tps_mean=mean(tps_mean))

solution <- solve(averaged[1:8], as.matrix(averaged[9]))
coefficients <- c(solution)
variable_names <- attr(solution, "dimnames")[[1]]
names(coefficients) <- variable_names


# ---- Making predictions ----
with_predictions <- exp_results %>%
  mutate(tps_predicted=
           make_predictions(coefficients, x0_constant, xa_servers, xb_replication,
                            xc_writes, x_ab, x_bc, x_ac, x_abc)) %>%
  mutate(error=tps_predicted-tps_mean)

# ---- Allocation of variation ----
tps_overall_mean <- mean(with_predictions$tps_mean)
var <- list()
var$total <- sum((with_predictions$tps_mean-tps_overall_mean)^2)
var$error <- sum(with_predictions$error^2)
var$xa_servers <- sum(K^2 * R * coefficients["xa_servers"]^2)
var$xb_replication <- sum(K^2 * R * coefficients["xb_replication"]^2)
var$xc_writes <- sum(K^2 * R * coefficients["xc_writes"]^2)
var$x_ab <- sum(K^2 * R * coefficients["x_ab"]^2)
var$x_bc <- sum(K^2 * R * coefficients["x_bc"]^2)
var$x_ac <- sum(K^2 * R * coefficients["x_ac"]^2)
var$x_abc <- sum(K^2 * R * coefficients["x_abc"]^2)
variations <- data.frame(var) %>%
  melt() %>%
  mutate(value=value/var$total) %>%
  rename(variation=value) %>%
  filter(variable != "total")

# Save variation table
variation_table <- xtable(variations, caption="\\todo{} caption",
                           label="tbl:part4:variation",
                           digits=c(NA, NA, 3))
print(variation_table, file=paste0(output_dir, "/variation_table.txt"))

# Error analysis
mean_error = mean(abs(with_predictions$error))
print(paste0("Mean error magnitude: ", round(mean_error, digits=1), " requests/s"))

# ---- Plots ----
# Error vs predicted throughput
ggplot(with_predictions, aes(x=tps_predicted, y=error)) +
  geom_point(size=2, color=color_dark) +
  geom_hline(yintercept=0, color="black") +
  xlab("Predicted throughput [requests / s]") +
  ylab("Error") +
  asl_theme
ggsave(paste0(output_dir, "/graphs/error_vs_predicted_tps.pdf"),
       width=fig_width, height=fig_height)

# Quantile-quantile plot
quantiles <- seq(1/24, 1-1/24, 1/24)
vals_residual <- quantile(with_predictions$error, probs=quantiles)
vals_normal <- qnorm(quantiles)
data2 <- data.frame(quantile=quantiles, residual=vals_residual, normal=vals_normal)
fit <- lm(residual ~ normal, data=data2)
ggplot(data2, aes(x=normal, y=residual)) +
  geom_point() +
  geom_abline(aes(yintercept=0), color="red", slope=fit$coefficients[["normal"]]) +
  xlab("Quantiles of standard normal distribution") +
  ylab("Quantiles of residual distribution [requests/s]") +
  asl_theme
ggsave(paste0(output_dir, "/graphs/quantile_quantile.pdf"),
       width=fig_width, height=fig_height)



