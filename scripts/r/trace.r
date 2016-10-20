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

DROP_TIMES_BEFORE = 3 * 60 # How many seconds in the beginning we want to drop
DROP_TIMES_AFTER = max((memaslap %>% filter(type=="t"))$time) - 2 * 60

# ---- Distribution of response times -----
data1 <- requests %>%
  mutate(dtAll=timeReturned-timeCreated) %>%
  select(dtAll, type)

g1 = ggplot(data1, aes(x=dtAll)) +
  geom_histogram(aes(y=..count../sum(..count..)), fill=color_dark) +
  facet_wrap(~type, nrow=2, scales="free_y") +
  xlim(-10, 100) +
  xlab("Time from receiving request to responding (ms)") +
  ylab("Proportion of requests") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/dist_tAll", FIGURE_TYPE), g1,
       width=fig_width, height=fig_height, device=cairo_pdf)


# ---- Throughput over time ----
data2 <- memaslap %>%
  filter(type=="t" & time >= DROP_TIMES_BEFORE & time <= DROP_TIMES_AFTER) %>%
  group_by(time) %>%
  summarise(tps=sum(tps))

g2 <- ggplot(data2) +
  geom_line(aes(x=time, y=tps, ymin=0), color=color_dark, size=2) +
  xlab("Time since start of experiment [s]") +
  ylab("Total throughput [successful responses / s]") +
  ggtitle("Throughput of SUT in the trace experiment") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/throughput", FIGURE_TYPE), g2,
       width=fig_width, height=fig_height, device=cairo_pdf)


# ---- Response time ----
data3 <- memaslap %>%
  filter(type=="t" & time >= DROP_TIMES_BEFORE & time <= DROP_TIMES_AFTER) %>%
  group_by(time, request_type) %>%
  summarise(avg=sum(avg * ops) / sum(ops))

data3summarised <- memaslap %>%
  filter(type=="t" & time >= DROP_TIMES_BEFORE & time <= DROP_TIMES_AFTER) %>%
  group_by(time) %>%
  summarise(avg=sum(avg * ops) / sum(ops),
            std=sqrt(sum(std*std*ops)/sum(ops)))

g3 <- ggplot(data3) +
  geom_line(aes(x=time, y=avg, ymin=0, color=request_type), size=2) +
  xlab("Time since start of experiment [s]") +
  ylab("Mean response time [ms]") +
  facet_wrap(~request_type, nrow=2, scales="free") +
  ggtitle("Response time of SUT in the trace experiment") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/latency_breakdown", FIGURE_TYPE), g3,
       width=fig_width, height=fig_height, device=cairo_pdf)

g3summarised <- ggplot(data3summarised) +
  geom_ribbon(aes(x=time, ymin=avg-std, ymax=avg+std), fill=color_light,
              alpha=0.5) +
  geom_line(aes(x=time, y=avg, ymin=0), color=color_dark, size=2) +
  xlab("Time since start of experiment [s]") +
  ylab("Mean response time [ms]") +
  ggtitle("Response time of SUT in the trace experiment") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/responsetime", FIGURE_TYPE), g3summarised,
       width=fig_width, height=fig_height, device=cairo_pdf)

# ---- Time spent in different parts of the system
data4 <- requests %>%
  filter(timeCreated >= min(requests$timeCreated) + 1000 * DROP_TIMES_BEFORE &
         timeReturned <= min(requests$timeCreated) + 1000 * DROP_TIMES_AFTER) %>%
  mutate(tLoadBalancer=timeEnqueued-timeCreated,
         tQueue=timeDequeued-timeEnqueued,
         tWorker=timeForwarded-timeDequeued,
         tMemcached=timeReceived-timeForwarded,
         tReturn=timeReturned-timeReceived,
         tAll=timeReturned-timeCreated) %>%
  select(type, tLoadBalancer:tReturn) %>%
  melt(id.vars=c("type"))

g4 <- ggplot(data4) +
  geom_histogram(aes(x=value, xmin=0, fill=type)) +
  facet_wrap(~variable + type, ncol=2, scales="free_y") +
  xlim(-10, 50) +
  xlab("Time spent [ms]") +
  ylab("Number of requests") +
  ggtitle("Distribution of time that requests spend in different parts of SUT") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/time_breakdown", FIGURE_TYPE), g4,
       width=fig_width, height=1.3*fig_width, device=cairo_pdf)