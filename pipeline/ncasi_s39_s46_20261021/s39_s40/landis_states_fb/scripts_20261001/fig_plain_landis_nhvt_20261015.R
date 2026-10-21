# Session 39, 15 Oct 2026. Plain language figure for the 16 Oct Sounding Board deck: how fast forests grow at different
# stand densities, measured on FIA plots versus LANDIS as first built and after recalibration (best behavioural run so
# far). Reads gates/behav_bins_20261015.csv (or a later behav file passed as argument 1 with a run name as argument 2).
suppressMessages({library(data.table); library(ggplot2)})
a <- commandArgs(TRUE)
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"; O <- file.path(D, "gates")
f <- if (length(a) >= 1) a[1] else file.path(O, "behav_bins_20261015.csv")
best <- if (length(a) >= 2) a[2] else "fit_20261007_d10_a2.5_b3"
x <- fread(f)[state %in% c("NH", "VT")]
lv <- c("[0,50)", "[50,100)", "[100,150)", "[150,200)", "[200,250)", "[250,300)", "[300,Inf)")
lab <- c("<50", "50-100", "100-150", "150-200", "200-250", "250-300", ">300")
st <- c(NH = "New Hampshire", VT = "Vermont")
l <- x[run %in% c("smoke_20261007_d10_anchored", best) & area_share >= 0.005,
       .(state, bin, src = fifelse(run == best, "Model, recalibrated", "Model, as first built"), g = mean_anpp)]
m <- unique(x[plots >= 20, .(state, bin, src = "Measured (FIA plots)", g = fia_gg)])
d <- rbind(m, l)[, bin := factor(bin, lv, lab)][, state := factor(st[state], st)]
d[, src := factor(src, c("Measured (FIA plots)", "Model, as first built", "Model, recalibrated"))]
p <- ggplot(d, aes(bin, g / 100, colour = src, group = src)) + geom_line(linewidth = 1.1) + geom_point(size = 2.4) +
  facet_wrap(~state, nrow = 1) +
  scale_colour_manual(values = c("Measured (FIA plots)" = "#1B1B1B", "Model, as first built" = "#C0392B", "Model, recalibrated" = "#2471A3"), name = NULL) +
  labs(x = expression("Wood already standing (tonnes ha"^-1*")"), y = expression("Yearly growth (tonnes ha"^-1*" yr"^-1*")")) +
  theme_classic(base_size = 14) + theme(legend.position = "top", axis.text.x = element_text(angle = 35, hjust = 1),
                                        strip.background = element_blank(), strip.text = element_text(face = "bold", size = 15))
ggsave(file.path(O, "fig_plain_landis_nhvt_20261015.png"), p, width = 10, height = 4.6, dpi = 300, device = ragg::agg_png)
cat("FIG_DONE", best, "\n")
