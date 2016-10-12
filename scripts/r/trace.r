# Rscript crap
library_location <- "/Users/taivo/Library/R/3.2/library"
library.path <- cat(.libPaths())

library(dplyr, lib.loc=library_location)
library(ggplot2, lib.loc=library_location)

source("scripts/r/common.r")

requests <- read.csv("results/trace/request.log", header=TRUE, sep=",")

# ---- Distribution of response times
data1 <- requests %>%
  mutate(dtAll=timeReturned-timeCreated) %>%
  select(dtAll)

g1 = ggplot(data1, aes(x=dtAll)) +
  geom_histogram(aes(y=..count../sum(..count..))) +
  xlab("Time from receiving request to responding (ms)") +
  ylab("Proportion of requests") +
  asl_theme
ggsave("results/trace/graphs/dist_tAll.svg", g1, width=8, height=5)


# ---- Throughput over time
options(digits.secs=3)
origin <- ISOdatetime(1970,1,1,0,0,0)
data2 <- requests %>%
  select(timeReturned) %>%
  mutate(timeReturned=origin+timeReturned/1000) %>%
  mutate(timeReturned=as.numeric(difftime(timeReturned, min(timeReturned), units="mins")))

ggplot(data2, aes(x=timeReturned)) +
  geom_histogram(binwidth=0.1) +
  xlab("Time since the first request was returned (min)") +
  ylab("100 requests") +  # TODO
  asl_theme