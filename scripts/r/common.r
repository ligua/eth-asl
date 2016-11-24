# ---- Loading libraries ----
library_location <- "/Users/taivo/Library/R/3.2/library"
library.path <- cat(.libPaths())

library(dplyr, lib.loc=library_location)
library(ggplot2, lib.loc=library_location)
library(reshape2, lib.loc=library_location)
library(stringr, lib.loc=library_location)

# ---- Theme ----

asl_theme = theme_bw() +
  theme(panel.grid.minor=element_blank()) +
  theme(panel.grid.major=element_line(color="#888888")) +
  theme(plot.title=element_text(face="bold", size=14))

color_dark = "#322270"
color_medium = "#7963cf"
color_light = "#cdc4ed"
color_triad1 = "#b9cf63"
color_triad1_dark = "#74823e"
color_triad2 = "#cf6e63"
color_triad2_dark = "#7b413b"

fig_width = 10
fig_height = 5

# ---- Helper functions ----
get_writes_factor <- function(W) {
  vec <- paste0(W, "%")
  fac <- factor(vec, levels=paste0(seq(1, 10, 1), "%"))
  return(fac)
}

get_replication_factor <- function(S, R) {
  vec <- ifelse(R==1, "none", 
                ifelse(R==S, "full", "half"))
  fac <- factor(vec, levels=c("none", "half", "full"))
  return(fac)
}

get_replication_factor_vocal <- function(S, R) {
  vec <- ifelse(R==1, "no replication", 
                ifelse(R==S, "full replication", "half replication"))
  fac <- factor(vec, levels=c("no replication", "half replication", "full replication"))
  return(fac)
}