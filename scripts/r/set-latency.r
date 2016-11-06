source("scripts/r/common.r")


requests1 <- read.csv("results/trace_rep1/request.log", header=TRUE, sep=",") %>%
  mutate(replication="none")
requests3 <- read.csv("results/trace_rep3/request.log", header=TRUE, sep=",") %>%
  mutate(replication="full")
requests <- rbind(requests1, requests3)

# ---- Time spent in different parts of the system
data4 <- requests %>%
  filter(type == "SET") %>%
  mutate(tLoadBalancer=timeEnqueued-timeCreated,
         tQueue=timeDequeued-timeEnqueued,
         tWorker=timeForwarded-timeDequeued,
         tMemcached=timeReceived-timeForwarded,
         tReturn=timeReturned-timeReceived) %>%
  select(type, replication, tMemcached) %>%
  melt(id.vars=c("type", "replication"))

ggplot(data4) +
  geom_histogram(aes(x=value, xmin=0, fill=replication)) +
  facet_wrap(~replication, nrow=2, scales="free") +
  xlab("Time spent (ms)") +
  ylab("Number of requests") +
  asl_theme

mean((data4 %>% filter(replication=="none"))$value)
mean((data4 %>% filter(replication=="full"))$value)

# ggsave("", FIGURE_TYPE), g4, width=fig_width, height=1.5*fig_width, device=cairo_pdf)