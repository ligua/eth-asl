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
NUM_BUCKETS = 120

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
  geom_line(data=stds, aes(x=bucket, y=mean), color="black", size=2) +
  facet_wrap(~type) +
  asl_theme

LIM_Y <- 50
NUM_BUCKETS_Y <- min(LIM_Y, 0)
data2 <- requests %>%
  mutate(bucketx = as.numeric(cut(requests$timeCreated, NUM_BUCKETS)),
         totalTime = timeReturned-timeCreated) %>%
  select(totalTime, bucketx, type) %>%
  filter(totalTime <= LIM_Y) %>%
  mutate(buckety = as.numeric(cut(totalTime, NUM_BUCKETS_Y))) %>%
  group_by(bucketx, buckety) %>%
  summarise(count=n())
  
ggplot(data2) +
  geom_raster(aes(x=bucketx, y=buckety, fill=count), alpha=0.6) +
  scale_fill_gradient(low="gray", high="red") +
  asl_theme
