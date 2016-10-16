# Rscript crap
library_location <- "/Users/taivo/Library/R/3.2/library"
library.path <- cat(.libPaths())

library(dplyr, lib.loc=library_location)
library(ggplot2, lib.loc=library_location)

source("scripts/r/common.r")

FIGURE_TYPE = ".pdf"

# ---- Parse command line args ----
args <- commandArgs(trailingOnly=TRUE)
if (length(args) == 0) {
  result_dir_base <- "results/baseline"
} else if(length(args) == 1) {
  result_dir_base <- args[1]
} else {
  stop("Arguments: [<results_directory>]")
}


data <- read.csv(paste0(result_dir_base, "/aggregated.csv"), header=TRUE, sep=";") %>%
  mutate(tmin=tmin/1000, tmax=tmax/1000, tavg=tavg/1000, tgeo=tgeo/1000, tstd=tstd/1000)

# ---- Mean throughput as a function of concurrency
data1 <- data %>%
  group_by(concurrency, repetition) %>%
  summarise(tps=sum(tps)) %>%  # Sum over the two clients
  group_by(concurrency) %>%
  summarise(mean_tps=mean(tps))

g1 <- ggplot(data1, aes(x=concurrency, y=mean_tps, ymin=0)) +
  geom_line(color=color_dark, size=2) +
  geom_point(color=color_dark, size=3) + 
  xlab("Concurrency (# clients)") +
  ylab("Total throughput (requests / second)") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/throughput", FIGURE_TYPE), g1,
       width=fig_width, height=fig_height, device=cairo_pdf)

# ---- Average response time as a function of concurrency
data2 <- data %>%
  group_by(concurrency) %>%
  summarise(t_mean=sum(tavg*total_events)/sum(total_events),
            t_std=sqrt(sum(tstd*tstd*total_events)/sum(total_events)))  # TODO this is probably not good

g2 <- ggplot(data2, aes(x=concurrency)) +
  geom_errorbar(aes(ymin=t_mean-t_std, ymax=t_mean+t_std), color=color_light, size=1) +
  geom_line(aes(y=t_mean), color=color_dark, size=2) +
  geom_point(aes(y=t_mean), color=color_dark, size=3) + 
  xlab("Concurrency (# clients)") +
  ylab("Mean response time (ms)") +
  asl_theme
ggsave(paste0(result_dir_base, "/graphs/responsetime", FIGURE_TYPE), g2,
       width=fig_width, height=fig_height, device=cairo_pdf)
