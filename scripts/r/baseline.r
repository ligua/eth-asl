# Rscript crap
library_location <- "/Users/taivo/Library/R/3.2/library"
library.path <- cat(.libPaths())

library(dplyr, lib.loc=library_location)
library(ggplot2, lib.loc=library_location)

source("scripts/r/common.r")

data <- read.csv("results/baseline/aggregated.csv", header=TRUE, sep=";")

# ---- Mean throughput as a function of concurrency
data1 <- data %>%
  group_by(concurrency, repetition) %>%
  summarise(tps=sum(tps)) %>%  # Sum over the two clients
  group_by(concurrency) %>%
  summarise(mean_tps=mean(tps))

g1 <- ggplot(data1, aes(x=concurrency, y=mean_tps)) +
  geom_line() +
  geom_point() + 
  xlab("Concurrency") +
  ylab("Mean throughput (requests / second)") +
  asl_theme
ggsave("results/baseline/graphs/throughput.svg", g1, width=8, height=5)

# ---- Average response time as a function of concurrency
data2 <- data %>%
  group_by(concurrency) %>%
  summarise(t_mean=mean(tavg), t_std=mean(tstd))  # TODO this is probably not good

g2 <- ggplot(data2, aes(x=concurrency)) +
  geom_line(aes(y=t_mean)) +
  geom_point(aes(y=t_mean)) + 
  geom_errorbar(aes(ymin=t_mean-t_std, ymax=t_mean+t_std)) +
  xlab("Concurrency") +
  ylab("Mean response time (ms)") +
  asl_theme
ggsave("results/baseline/graphs/responsetime.svg", g2, width=8, height=5)
