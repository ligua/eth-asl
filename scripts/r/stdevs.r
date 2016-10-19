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

requests2 <- requests %>%
  mutate(bucket = as.numeric(cut(requests$timeCreated, NUM_BUCKETS)),
         totalTime = timeReturned-timeCreated) %>%
  select(totalTime, bucket, type) %>%
  group_by(bucket, type) %>%
  summarise(q01=quantile(totalTime, 0.1),
            q03=quantile(totalTime, 0.3),
            q05=quantile(totalTime, 0.5),
            q07=quantile(totalTime, 0.7),
            q09=quantile(totalTime, 0.9),
            q099=quantile(totalTime, 0.99),
            mean=mean(totalTime),
            std=sd(totalTime)) %>%
  melt(id.vars=c("bucket", "type"))

quantiles <- requests2 %>% filter(variable != "std" & variable != "mean")
stds <- requests2 <- requests %>%
  mutate(bucket = as.numeric(cut(requests$timeCreated, NUM_BUCKETS)),
         totalTime = timeReturned-timeCreated) %>%
  select(totalTime, bucket, type) %>%
  group_by(bucket, type) %>%
  summarise(mean=mean(totalTime),
            std=sd(totalTime))

ggplot() +
  geom_ribbon(data=stds, aes(x=bucket, ymin=mean-std, ymax=mean+std),
              fill="black", alpha=0.4) +
  geom_line(data=quantiles, aes(x=bucket, y=value, color=variable), size=2) +
  geom_line(data=stds, aes(x=bucket, y=mean), color="red", size=2) +
  facet_wrap(~type) +
  asl_theme
