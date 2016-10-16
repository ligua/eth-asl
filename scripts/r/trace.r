# Rscript crap
library_location <- "/Users/taivo/Library/R/3.2/library"
library.path <- cat(.libPaths())

library(dplyr, lib.loc=library_location)
library(reshape2, lib.loc=library_location)
library(ggplot2, lib.loc=library_location)

source("scripts/r/common.r")

result_dir_base <- "results/trace"

requests <- read.csv(paste0(result_dir_base, "/request.log"), header=TRUE, sep=",")
memaslap <- read.csv(paste0(result_dir_base, "/memaslap_stats.csv"), header=TRUE, sep=";") %>%
  mutate(min=min/1000, max=max/1000, avg=avg/1000, std=std/1000)

# ---- Filter out beginning and end ----
SHOULD_FILTER = FALSE
if(SHOULD_FILTER) {
  CUT_BEGINNING = 2 # minutes
  CUT_END = 1 # minutes
  min_time = min(requests$timeReturned) + 1e3 * 60 * CUT_BEGINNING
  max_time = max(requests$timeReturned) - 1e3 * 60 * CUT_END
  requests <- requests %>%
    filter(timeReturned > min_time & timeReturned < max_time)
}

# ---- Distribution of response times -----
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


# ---- Throughput over time ----
data2 <- memaslap %>%
  filter(type=="t") %>%
  group_by(time) %>%
  summarise(tps=sum(tps))

g2 <- ggplot(data2) +
  geom_line(aes(x=time, y=tps), color=color_dark, size=2) +
  xlab("Time since start of experiment (s)") +
  ylab("Total throughput (requests / s)") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/throughput.svg"), g2, width=8, height=5)


# ---- Latency over time ----
data3 <- memaslap %>%
  filter(type=="t") %>%
  group_by(time, request_type) %>%
  summarise(avg=sum(avg * ops) / sum(ops),
            std=sum(std * ops) / sum(ops)) # TODO this is very bad

g3 <- ggplot(data3) +
  geom_line(aes(x=time, y=avg, color=request_type), size=2) +
  geom_errorbar(aes(x=time, ymin=avg-std, ymax=avg+std)) +
  xlab("Time since start of experiment (s)") +
  ylab("Latency measured by memaslap (ms)") +
  facet_wrap(~request_type, nrow=2, scales="free") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/latency.svg"), g3, width=8, height=5)

# ---- Time spent in different parts of the system
data4 <- requests %>%
  mutate(tLoadBalancer=timeEnqueued-timeCreated,
         tQueue=timeDequeued-timeEnqueued,
         tWorker=timeForwarded-timeDequeued,
         tMemcached=timeReceived-timeForwarded,
         tReturn=timeReturned-timeReceived) %>%
  select(type, tLoadBalancer:tReturn) %>%
  melt(id.vars=c("type"))

g4 <- ggplot(data4) +
  geom_histogram(aes(x=value, fill=type)) +
  facet_wrap(~variable + type, ncol=2, scales="free") +
  xlab("Time spent (ms)") +
  ylab("Number of requests") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/time_breakdown.svg"), g4, width=8, height=5)