# Rscript crap
library_location <- "/Users/taivo/Library/R/3.2/library"
library.path <- cat(.libPaths())

library(dplyr, lib.loc=library_location)
library(reshape2, lib.loc=library_location)
library(ggplot2, lib.loc=library_location)

source("scripts/r/common.r")

requests <- read.csv("results/trace/request.log", header=TRUE, sep=",")
result_dir_base <- "results/trace"

# ---- Filter out beginning and end
CUT_BEGINNING = 2 # minutes
CUT_END = 1 # minutes
min_time = min(requests$timeReturned) + 1e3 * 60 * CUT_BEGINNING
max_time = max(requests$timeReturned) - 1e3 * 60 * CUT_END
requests <- requests %>%
  filter(timeReturned > min_time & timeReturned < max_time)

# ---- Distribution of response times
data1 <- requests %>%
  mutate(dtAll=timeReturned-timeCreated) %>%
  select(dtAll, type)

g1 = ggplot(data1, aes(x=dtAll)) +
  geom_histogram(aes(y=..count../sum(..count..)), fill=color_dark) +
  facet_wrap(~type, nrow=2, scales="free") +
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


num_bins = 60
h <- hist(data2$timeReturned, plot=FALSE, breaks=num_bins)
binwidth_in_minutes = h$breaks[2] - h$breaks[1]
tps_values <- h$counts / binwidth_in_minutes / 60 * 100

data2p <- data.frame(h$mids, tps_values) %>%
  rename(minute=h.mids)
g2 <- ggplot(data2p) +
  geom_line(aes(x=minute, y=tps_values), color=color_dark, size=2) +
  xlab("Time since start of experiment (min)") +
  ylab("Throughput (requests / s)") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/throughput.svg"), g2, width=8, height=5)




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
  facet_wrap(~variable + type, ncol=2, scales="free") +
  xlab("Time spent (ms)") +
  ylab("Number of requests") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/time_breakdown.svg"), g3, width=8, height=5)