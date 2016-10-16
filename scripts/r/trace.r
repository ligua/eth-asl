# Rscript crap
library_location <- "/Users/taivo/Library/R/3.2/library"
library.path <- cat(.libPaths())

library(dplyr, lib.loc=library_location)
library(reshape2, lib.loc=library_location)
library(ggplot2, lib.loc=library_location)

source("scripts/r/common.r")

FIGURE_TYPE = ".pdf"
SHOULD_FILTER = FALSE


# ---- Parse command line args ----
args <- commandArgs(trailingOnly=TRUE)
if (length(args) == 0) {
  result_dir_base <- "results/trace"
} else if(length(args) == 1) {
  result_dir_base <- args[1]
} else {
  stop("Arguments: [<results_directory>]")
}

requests <- read.csv(paste0(result_dir_base, "/request.log"), header=TRUE, sep=",")
memaslap <- read.csv(paste0(result_dir_base, "/memaslap_stats.csv"), header=TRUE, sep=";") %>%
  mutate(min=min/1000, max=max/1000, avg=avg/1000, std=std/1000)

# ---- Filter out beginning and end ----
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
ggsave(paste0(result_dir_base, "/graphs/dist_tAll", FIGURE_TYPE), g1,
       width=fig_width, height=fig_height, device=cairo_pdf)


# ---- Throughput over time ----
data2 <- memaslap %>%
  filter(type=="t") %>%
  group_by(time) %>%
  summarise(tps=sum(tps))

g2 <- ggplot(data2) +
  geom_line(aes(x=time, y=tps, ymin=0), color=color_dark, size=2) +
  xlab("Time since start of experiment (s)") +
  ylab("Total throughput (requests / s)") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/throughput", FIGURE_TYPE), g2,
       width=fig_width, height=fig_height, device=cairo_pdf)


# ---- Latency over time ----
data3 <- memaslap %>%
  filter(type=="t") %>%
  group_by(time, request_type) %>%
  summarise(avg=sum(avg * ops) / sum(ops))

data3summarised <- memaslap %>%
  filter(type=="t") %>%
  group_by(time) %>%
  summarise(avg=sum(avg * ops) / sum(ops))

g3 <- ggplot(data3) +
  geom_line(aes(x=time, y=avg, ymin=0, color=request_type), size=2) +
  xlab("Time since start of experiment (s)") +
  ylab("Response time measured by memaslap (ms)") +
  facet_wrap(~request_type, nrow=2, scales="free") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/latency_breakdown", FIGURE_TYPE), g3,
       width=fig_width, height=fig_height, device=cairo_pdf)

g3summarised <- ggplot(data3summarised) +
  geom_line(aes(x=time, y=avg, ymin=0), color=color_dark, size=2) +
  xlab("Time since start of experiment (s)") +
  ylab("Response time measured by memaslap (ms)") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/responsetime", FIGURE_TYPE), g3summarised,
       width=fig_width, height=fig_height, device=cairo_pdf)

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
  geom_histogram(aes(x=value, xmin=0, fill=type)) +
  facet_wrap(~variable + type, ncol=2, scales="free") +
  xlab("Time spent (ms)") +
  ylab("Number of requests") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/time_breakdown", FIGURE_TYPE), g4,
       width=fig_width, height=1.5*fig_width, device=cairo_pdf)