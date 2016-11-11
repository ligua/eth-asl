source("scripts/r/common.r")

FIGURE_TYPE = ".pdf"

ms2_report_graphs = "report/figures"

# ---- Experiment 2: Replication ----
data1 <- read.csv("report/exp2_hypothesis.csv") %>%
  mutate(replication_factor=get_replication_factor(servers, replication)) %>%
  mutate(servers=paste0(servers, " servers"))

g1 <- ggplot(data1, aes(x=replication_factor, y=responsetime, group=1)) +
  geom_point(color=color_dark) +
  geom_line(color=color_dark) +
  facet_wrap(~type+servers, ncol=3) +
  ylim(0, NA) +
  ylab("Response time") +
  xlab("Replication") +
  asl_theme +
  theme(axis.text.y=element_blank(),
        axis.ticks.y=element_blank())
g1
ggsave(paste0(ms2_report_graphs, "/hypothesis_replication", FIGURE_TYPE), g1,
       width=fig_width, height=fig_height, device=cairo_pdf)