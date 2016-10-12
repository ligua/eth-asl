# Rscript crap
library_location <- "/Users/taivo/Library/R/3.2/library"
library.path <- cat(.libPaths())

library(dplyr, lib.loc=library_location)
library(reshape2, lib.loc=library_location)
library(ggplot2, lib.loc=library_location)

source("scripts/r/common.r")

requests <- read.csv("results/trace/request.log", header=TRUE, sep=",")
result_dir_base <- "results/trace"

# ---- Distribution of response times
data1 <- requests %>%
  mutate(dtAll=timeReturned-timeCreated) %>%
  select(dtAll)

g1 = ggplot(data1, aes(x=dtAll)) +
  geom_histogram(aes(y=..count../sum(..count..))) +
  xlab("Time from receiving request to responding (ms)") +
  ylab("Proportion of requests") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/dist_tAll.svg"), g1, width=8, height=5)


# ---- Throughput over time
options(digits.secs=3)
origin <- ISOdatetime(1970,1,1,0,0,0)
data2 <- requests %>%
  select(timeReturned) %>%
  mutate(timeReturned=origin+timeReturned/1000) %>%
  mutate(timeReturned=as.numeric(difftime(timeReturned, min(timeReturned), units="mins")))

min_val <- min(data2$timeReturned)
max_val <- max(data2$timeReturned)
total_time_in_minutes <- (max_val-min_val)
num_bins = 30
binwidth_in_minutes = total_time_in_minutes / num_bins

h <- hist(data2$timeReturned, plot=FALSE, breaks=num_bins)
tps_values <- h$counts / binwidth_in_minutes * 100 / 60



#ggsave(paste0(result_dir_base, "/graphs/throughput_over_time.svg"), g2, width=8, height=5)

# ---- Time spent in different parts of the system
data3 <- requests %>%
  mutate(tLoadBalancer=timeEnqueued-timeCreated,
         tQueue=timeDequeued-timeEnqueued,
         tWorker=timeForwarded-timeDequeued,
         tMemcachedAndReturn=timeReturned-timeForwarded) %>%
  select(type, tLoadBalancer:tMemcachedAndReturn) %>%
  melt(id.vars=c("type"))

g3 <- ggplot(data3) +
  geom_histogram(aes(x=value, fill=type)) +
  facet_wrap(~variable) +
  xlab("Time spent (ms)") +
  ylab("Number of requests") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/time_breakdown.svg"), g3, width=8, height=5)