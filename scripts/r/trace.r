# Rscript crap
library_location <- "/Users/taivo/Library/R/3.2/library"
library.path <- cat(.libPaths())

library(dplyr, lib.loc=library_location)
library(ggplot2, lib.loc=library_location)

source("scripts/r/common.r")

requests <- read.csv("results/trace/request.log", header=TRUE, sep=",")

data1 <- requests %>%
  mutate(dtAll=timeReturned-timeCreated) %>%
  select(dtAll)

g1 = ggplot(data1, aes(x=dtAll)) +
  geom_histogram(aes(y=..count../sum(..count..))) +
  xlab("Time from receiving request to responding (ms)") +
  ylab("Proportion of requests") +
  asl_theme
ggsave("results/trace/graphs/dist_tAll.svg", g1, width=8, height=5)