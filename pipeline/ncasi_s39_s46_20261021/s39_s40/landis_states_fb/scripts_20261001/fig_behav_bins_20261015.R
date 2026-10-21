# Session 39, 15 Oct 2026. Figure: gross production by stand biomass class, FIA remeasured plots against LANDIS
# year 5 ANPP, for the anchored runs and the best behavioural NH and VT grid runs. Reads gates/behav_bins_20261015.csv.
suppressMessages({library(data.table); library(ggplot2)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"; O <- file.path(D, "gates")
x <- fread(file.path(O, "behav_bins_20261015.csv"))
lv <- c("[0,50)", "[50,100)", "[100,150)", "[150,200)", "[200,250)", "[250,300)", "[300,Inf)")
lab <- c("<50", "50-100", "100-150", "150-200", "200-250", "250-300", ">300")
keep <- c("smoke_20261007_d10_anchored", "fit_20261007_d10_a2.5_b3", "fit_20261007_d10_confirm_a1.20_b1.75")
l <- x[run %in% keep & area_share >= 0.005, .(state, bin, src = fifelse(run == keep[1], "LANDIS anchored, base table",
        fifelse(run == keep[2], "LANDIS ANPPmax x2.5, BiomassMax x3", "LANDIS WI fitted table")), g = mean_anpp)]
f <- unique(x[plots >= 20, .(state, bin, src = "FIA remeasured plots", g = fia_gg)])
d <- rbind(l, f)[, bin := factor(bin, lv, lab)][, state := factor(state, c("NH", "VT", "WI", "MI"))]
p <- ggplot(d, aes(bin, g, colour = src, group = src)) + geom_line(linewidth = 0.6) + geom_point(size = 1.6) +
  facet_wrap(~state, nrow = 1) +
  scale_colour_manual(values = c("FIA remeasured plots" = "black", "LANDIS anchored, base table" = "#C0392B",
                                 "LANDIS ANPPmax x2.5, BiomassMax x3" = "#2471A3", "LANDIS WI fitted table" = "#7D3C98"), name = NULL) +
  labs(x = expression("Stand live aboveground biomass (Mg ha"^-1*")"),
       y = expression("Gross production (g m"^-2*" yr"^-1*")")) +
  theme_classic(base_size = 9) + theme(legend.position = "bottom", axis.text.x = element_text(angle = 45, hjust = 1),
                                       strip.background = element_blank(), strip.text = element_text(face = "bold"))
ggsave(file.path(O, "fig_behav_bins_20261015.png"), p, width = 7.5, height = 3.4, dpi = 300, device = ragg::agg_png)
cat("FIG_DONE\n")
