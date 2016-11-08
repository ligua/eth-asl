source("scripts/r/common.r")

FIGURE_TYPE = ".pdf"

ms2_report_graphs = "report/figures"

# ---- Experiment 1: Throughput ----
clients = c(1, seq(50, 500, 50))
tp_1client = 100
tp_saturated = 10000
throughput = c(tp_1client, c(0.5, 0.8, 0.88, 0.93, 0.97, 0.98, 0.99, 1, 0.95, 0.87)*tp_saturated)


data1 <- data.frame(clients, throughput)

g1 <- ggplot(data1, aes(x=clients, y=throughput)) +
  geom_line(color=color_dark) +
  geom_point(color=color_dark) +
  xlab("Number of clients") + ylab("Throughput [requests/s]") +
  ggtitle("Hypothesis: shape of the throughput graph") +
  asl_theme
ggsave(paste0(ms2_report_graphs, "/hypothesis_throughput", FIGURE_TYPE), g1,
       width=fig_width, height=fig_height / 2, device=cairo_pdf)