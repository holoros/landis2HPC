#!/usr/bin/env Rscript
# fig_disturbance_compare.R - CONUS reserve carbon: no-disturbance ceiling vs the
# disturbance-aware overlay. Shows the overlay lowers the central estimate and
# narrows the inter-model envelope (the divergence lived in the no-disturbance ceiling).
suppressPackageStartupMessages({library(data.table); library(ggplot2)})
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
nd <- fread(file.path(FIA,"uncertainty_conus.csv"))[, set:="No-disturbance ceiling"]
di <- fread(file.path(FIA,"uncertainty_conus_disturbed.csv"))[, set:="Disturbance-aware"]
d <- rbind(nd, di, fill=TRUE)
d[, set:=factor(set, levels=c("No-disturbance ceiling","Disturbance-aware"))]
theme_pub <- theme_bw(base_size=12) +
  theme(panel.grid.minor=element_blank(), legend.position="top",
        legend.title=element_blank(), plot.title=element_text(face="bold"))
p <- ggplot(d, aes(year)) +
  geom_ribbon(aes(ymin=lo, ymax=hi, fill=set), alpha=.35) +
  geom_line(aes(y=ensemble_median, colour=set), linewidth=1.1) +
  geom_point(aes(y=ensemble_median, colour=set), size=2) +
  scale_fill_manual(values=c("No-disturbance ceiling"="#bdbdbd","Disturbance-aware"="#3182bd")) +
  scale_colour_manual(values=c("No-disturbance ceiling"="#636363","Disturbance-aware"="#08519c")) +
  scale_y_continuous(limits=c(0,NA)) +
  labs(title="CONUS reserve carbon: disturbance overlay lowers and tightens the projection",
       subtitle="full-model envelope (FVS/YC/CBM); 2100 CV 21.5% -> 17.3%, median 24.3 -> 20.6 Pg C",
       x=NULL, y="Aboveground live C (Tg)") + theme_pub
ggsave(file.path(FIA,"fig_disturbance_compare.png"), p, width=8, height=5, dpi=200)
cat("figure written\n")
