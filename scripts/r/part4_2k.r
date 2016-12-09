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
  select(servers, replication, writes, repetition, tps_mean) %>%
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

# ---- Analysis ----
# Allocation of variation
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

# Save data table
data_df <- exp_results %>%
  select(servers, replication_str, writes, repetition, tps_mean) %>%
  rename(throughput=tps_mean, repetition_id=repetition, replication=replication_str)
data_table <- xtable(data_df, caption="\\todo{} caption",
                          label="tbl:part4:data",
                          digits=0)
print(data_table, file=paste0(output_dir, "/data_table.txt"))

# Save variation table
variation_table <- xtable(variations, caption="\\todo{} caption",
                           label="tbl:part4:variation",
                           digits=c(NA, NA, 3))
print(variation_table, file=paste0(output_dir, "/variation_table.txt"))

# Save coefficient table
coefficient_df <- data.frame(value=coefficients) %>%
  mutate(coefficient=variable_names) %>%
  select(coefficient, value)
coefficient_table <- xtable(coefficient_df, caption="\\todo{} caption",
                          label="tbl:part4:coefficients",
                          digits=c(NA, NA, 1))
print(coefficient_table, file=paste0(output_dir, "/coefficient_table.txt"))


# Error analysis
mean_error = mean(abs(with_predictions$error))
print(paste0("Mean error magnitude: ", round(mean_error, digits=1), " requests/s [",
             round(mean_error/tps_overall_mean*100), "%]"))
mean_error_no_outlier = mean(abs((with_predictions %>% filter(!(servers==3&replication==1)))$error))
print(paste0("Mean error magnitude without outlier: ", round(mean_error_no_outlier, digits=1), " requests/s [",
             round(mean_error_no_outlier/tps_overall_mean*100), "%]"))

# Confidence intervals
s_e <- sqrt(var$error / (2^K * (R - 1)))
s_q <- s_e / (2^K * R)
n_eff <- 2^K * R / (1 + length(coefficients))
s_y <- s_e * sqrt(1/n_eff + 1/R)

two_sided_t_val <- qt(c(.025, .975), df=2^K * (R - 1))[2]
tps_confidence_delta <- two_sided_t_val * s_y
with_predictions$tps_confidence_delta <- tps_confidence_delta

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

# Distribution of errors
ggplot(with_predictions, aes(x=error)) +
  geom_histogram(bins=9, color=color_medium, fill=color_light, alpha=0.8) +
  xlab("Error [requests/s]") +
  ylab("Number of experiments") +
  asl_theme
ggsave(paste0(output_dir, "/graphs/error_distribution.pdf"),
       width=fig_width, height=fig_height)

# Quantile-quantile plot
quantiles <- seq(1/24, 1-1/24, 1/24)
vals_residual <- quantile(with_predictions$error, probs=quantiles)
vals_normal <- qnorm(quantiles)
data2 <- data.frame(quantile=quantiles, residual=vals_residual, normal=vals_normal)
fit <- lm(residual ~ normal, data=data2)
ggplot(data2, aes(x=normal, y=residual)) +
  geom_point() +
  geom_abline(aes(yintercept=0), color=color_triad1_dark, slope=fit$coefficients[["normal"]]) +
  xlab("Quantiles of standard normal distribution") +
  ylab("Quantiles of residual distribution [requests/s]") +
  asl_theme
ggsave(paste0(output_dir, "/graphs/quantile_quantile.pdf"),
       width=fig_width, height=fig_height)

# Predictions vs actual results
df_predicted <- with_predictions %>%
  select(servers, replication, writes, repetition, tps_predicted)

data3 <- exp_results %>%
  select(servers, replication, writes, repetition, tps_mean) %>%
  mutate(replication_str=get_replication_factor_vocal(servers, replication),
         servers_str=paste0(servers, " servers"),
         writes_str=get_writes_factor(writes)) %>%
  left_join(df_predicted, by=c("servers", "replication", "writes", "repetition"))
  
ggplot(data3, aes(x=writes_str, group=repetition)) +
  geom_ribbon(aes(ymin=tps_predicted-tps_confidence_delta,
                  ymax=tps_predicted+tps_confidence_delta), fill=color_triad2, alpha=0.2) +
  geom_line(aes(y=tps_predicted), color=color_triad2_dark, size=1) +
  geom_line(aes(y=tps_mean), color=color_dark) +
  geom_point(aes(y=tps_mean), color=color_dark) +
  facet_wrap(~replication_str+servers_str, nrow=1) +
  xlab("Proportion of writes") +
  ylab("Throughput [requests/s]") +
  ylim(0, NA) +
  asl_theme
ggsave(paste0(output_dir, "/graphs/actual_and_predicted_vs_servers_and_writes.pdf"),
       width=fig_width, height=fig_height/2)
