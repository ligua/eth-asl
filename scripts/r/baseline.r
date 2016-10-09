library(tidyr)
library(dplyr)
library(ggplot2)

source("scripts/r/common.r")

data = read.csv("results/baseline/aggregated.csv", header=TRUE, sep=";")

# Mean throughput as a function of concurrency
data1 = data %>%
  group_by(concurrency, repetition) %>%
  summarise(tps=sum(tps)) %>%  # Sum over the two clients
  group_by(concurrency) %>%
  summarise(mean_tps=mean(tps))

ggplot(data1) +
  geom_line(aes(x=concurrency, y=mean_tps)) +
  xlab("Concurrency") +
  ylab("Mean throughput (requests / second)") +
  asl_theme