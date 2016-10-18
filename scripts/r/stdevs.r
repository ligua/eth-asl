library_location <- "/Users/taivo/Library/R/3.2/library"
library.path <- cat(.libPaths())

library(dplyr, lib.loc=library_location)
library(reshape2, lib.loc=library_location)
library(ggplot2, lib.loc=library_location)

source("scripts/r/common.r")


requests <- read.csv("results/trace_rep3/request.log", header=TRUE, sep=",")

# Evolution of percentiles over time
# exp_start = min(requests$timeCreated)
# exp_end = min(requests$timeReturned)
NUM_BUCKETS = 20

h <- hist(requests$timeCreated, breaks=NUM_BUCKETS, plot=FALSE)
requests2 <- requests %>%
  mutate(bucket = as.numeric(cut(requests$timeCreated, NUM_BUCKETS)),
         totalTime = timeReturned-timeCreated) %>%
  select(totalTime, bucket) %>%
  group_by(bucket) %>%
  summarise(q01=quantile(totalTime, 0.1),
            q03=quantile(totalTime, 0.3),
            q05=quantile(totalTime, 0.5),
            q07=quantile(totalTime, 0.7),
            q09=quantile(totalTime, 0.9)) %>%
  melt(id.vars=c("bucket"))


ggplot(requests2) +
  geom_line(aes(x=bucket, y=value, color=variable)) +
  asl_theme