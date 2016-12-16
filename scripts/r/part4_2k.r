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
data_table <- xtable(data_df, caption="Data used in building the $2^k$ model in Section~\\ref{sec:part4-2k-experiment}.",
                          label="tbl:part4:data",
                          digits=0,
                     align="|rllrr|r|")
print(data_table, file=paste0(output_dir, "/data_table.txt"), size="\\fontsize{9pt}{10pt}\\selectfont")

# Save coefficient table
coefficient_and_var_df <- data.frame(value=coefficients) %>%
  mutate(variable_names=variable_names) %>%
  rename(variable=variable_names, coefficient_value=value) %>%
  select(variable, coefficient_value) %>%
  full_join(variations, by=c("variable"))
coefficient_and_var_table <- xtable(coefficient_and_var_df, caption="Values of coefficients and allocation of variation for all variables in the $2^k$ model.",
                          label="tbl:part4:coefficients",
                          digits=c(NA, NA, 1, 3),
                          align="|rl|rr|")
print(coefficient_and_var_table, file=paste0(output_dir, "/coefficient_and_var_table.txt"), size="\\fontsize{9pt}{10pt}\\selectfont")


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



# -----------------------
# -------- Plots --------
# -----------------------

# Error vs predicted throughput
ggplot(with_predictions, aes(x=tps_predicted, y=error)) +
  geom_point(size=2, color=color_dark) +
  geom_hline(yintercept=0, color="black") +
  xlab("Predicted throughput [requests / s]") +
  ylab("Error [requests/s]") +
  asl_theme
ggsave(paste0(output_dir, "/graphs/error_vs_predicted_tps.pdf"),
       width=fig_width/2, height=fig_height/2)

# Error vs throughput, by repetition
ggplot(with_predictions, aes(x=tps_predicted, y=error)) +
  geom_point(size=2, color=color_dark) +
  geom_hline(yintercept=0, color="black") +
  facet_wrap(~repetition, nrow=1) +
  xlab("Predicted throughput [requests / s]") +
  ylab("Error [requests/s]") +
  asl_theme
ggsave(paste0(output_dir, "/graphs/error_vs_predicted_tps_by_rep.pdf"),
       width=fig_width, height=fig_height/2)

# Error vs experiment order
data_ordered <- with_predictions %>%
  arrange(repetition, servers, replication, writes) %>%
  mutate(order=seq(1, nrow(with_predictions), 1)) %>%
  mutate(repetition=as.factor(repetition))
ggplot(data_ordered, aes(x=order, y=error)) +
  geom_point(aes(color=repetition), size=2) +
  geom_hline(yintercept=0, color="black") +
  xlab("Order of running experiments") +
  ylab("Error [requests/s]") +
  asl_theme +
  theme(legend.position="top")
ggsave(paste0(output_dir, "/graphs/error_vs_order.pdf"),
       width=fig_width, height=fig_height/2)

# Error vs level -- for ALL factors!
data_level <- with_predictions %>%
  select(servers_str, replication_str, writes_str, repetition, error)

factor_servers <- data_level %>%
  mutate(factor="servers", level=as.numeric(as.factor(servers_str)))
factor_replication <- data_level %>%
  mutate(factor="replication", level=as.numeric(as.factor(replication_str)))
factor_writes <- data_level %>%
  mutate(factor="writes", level=as.numeric(as.factor(paste0(writes_str, "asd"))))
data_level_combined <- rbind(factor_servers, factor_replication, factor_writes) %>%
  mutate(level=as.factor(level))

ggplot(data_level_combined, aes(x=level, y=error)) +
  geom_boxplot(fill=color_triad1) +
  geom_point(size=1) +
  facet_wrap(~factor, nrow=1) +
  xlab("Factor level") +
  ylab("Error [requests/s]") +
  asl_theme
ggsave(paste0(output_dir, "/graphs/dist_vs_level.pdf"),
       width=fig_width/2, height=fig_height/2)

# Distribution of errors
ggplot(with_predictions, aes(x=error)) +
  geom_histogram(bins=9, color=color_medium, fill=color_light, alpha=0.8) +
  xlab("Error [requests/s]") +
  ylab("Number of experiments") +
  asl_theme
ggsave(paste0(output_dir, "/graphs/error_distribution.pdf"),
       width=fig_width/2, height=fig_height/2)

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
  ylab("Quantiles of error distribution\n[requests/s]") +
  asl_theme
ggsave(paste0(output_dir, "/graphs/quantile_quantile.pdf"),
       width=fig_width/2, height=fig_height/2)

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