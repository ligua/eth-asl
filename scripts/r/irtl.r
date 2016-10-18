# Rscript crap
library_location <- "/Users/taivo/Library/R/3.2/library"
library.path <- cat(.libPaths())

library(dplyr, lib.loc=library_location)
library(reshape2, lib.loc=library_location)
library(ggplot2, lib.loc=library_location)

source("scripts/r/common.r")

memaslap <- read.csv(paste0(result_dir_base, "/memaslap_stats.csv"), header=TRUE, sep=";") %>%
  mutate(min=min/1000, max=max/1000, avg=avg/1000, std=std/1000)

DROP_TIMES_BEFORE = 3 * 60 # How many seconds in the beginning we want to drop
DROP_TIMES_AFTER = max((memaslap %>% filter(type=="t"))$time) - 2 * 60

# ---- Calculations ----
data1 <- memaslap %>%
  filter(type=="t" & time >= DROP_TIMES_BEFORE & time <= DROP_TIMES_AFTER) %>%
  summarise(avg=sum(avg * ops) / sum(ops))
mean_response_time <- data1$avg / 1000 # We want the value in seconds, not ms
  
data2 <- memaslap %>%
  filter(type=="t" & time >= DROP_TIMES_BEFORE & time <= DROP_TIMES_AFTER) %>%
  group_by(time) %>%
  summarise(tps=sum(tps)) %>%
  summarise(mean_tps=mean(tps))
true_mean_tps <- data2$mean_tps[1]

num_clients <- 3 * 64
think_time <- 0
predicted_mean_tps <- num_clients / (think_time + mean_response_time)
diff_perc <- 100 * (true_mean_tps - predicted_mean_tps) / true_mean_tps

cat(paste0("Predicted mean TPS is ", round(predicted_mean_tps),
           ", true mean TPS is ", round(true_mean_tps),
           " (difference ", round(diff_perc, digits=2), "%)."))
