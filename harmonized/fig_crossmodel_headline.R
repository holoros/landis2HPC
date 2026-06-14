# =============================================================================
# Title: Harmonized multi-model CONUS carbon - headline figure
# Author: A. Weiskittel
# Date: 2026-06-13
# Description: Three-panel publication figure from the harmonized assessment:
#   A) cross-model 2100 reserve carbon with 90% CIs at the full-overlap states
#      (IN, OH, NH) - the structural-divergence / distinguishability result
#   B) CONUS 2100 total carbon across the four harvest scenarios x disturbance mode
#   C) CONUS best-estimate reserve trajectory 2025-2100 with 90% credible band
# Dependencies: FIA/harmonized_crossmodel_ci.csv, harmonized_conus_by_scenario.csv,
#               harmonized_best_estimate.csv  (Cardinal scratch)
# =============================================================================
suppressPackageStartupMessages({library(ggplot2); library(patchwork); library(data.table)})
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
OUT <- file.path(FIA, "figures"); dir.create(OUT, showWarnings = FALSE)

theme_pub <- theme_classic(base_size = 11) +
  theme(panel.grid.major.y = element_line(color = "grey92", linewidth = 0.3),
        axis.title = element_text(size = 11), axis.text = element_text(size = 9),
        legend.position = "bottom", legend.title = element_text(size = 9),
        legend.text = element_text(size = 8), plot.title = element_text(size = 12, face = "bold"),
        plot.tag = element_text(size = 13, face = "bold"))
# colorblind-safe model palette
mcol <- c(FVS_def = "#D55E00", FVS_cal = "#E69F00", CBM = "#0072B2",
          YieldCurve = "#009E73", LANDIS = "#CC79A7", CEM = "#999999")
mlab <- c(FVS_def = "FVS (default)", FVS_cal = "FVS (calibrated)", CBM = "CBM",
          YieldCurve = "Yield curve", LANDIS = "LANDIS-II", CEM = "CEM")

# --- Panel A: cross-model 2100 reserve with 90% CI at IN/OH/NH --------------
ci <- fread(file.path(FIA, "harmonized_crossmodel_ci.csv"))
ci[, model := factor(model, levels = names(mcol))]
ci[, state := factor(state, levels = sort(unique(state)))]   # coverage-driven (4 now -> 9 when CEM lands)
# geometric-mean reference per state (dashed line) from the geomean ensemble
gmref <- tryCatch(fread(file.path(FIA, "harmonized_ensemble_geomean.csv"))[year == 2100,
            .(state, geom_mean)], error = function(e) NULL)
pA <- ggplot(ci, aes(x = value, y = model, color = model)) +
  {if (!is.null(gmref)) geom_vline(data = gmref, aes(xintercept = geom_mean),
       linetype = "dashed", color = "grey45", linewidth = 0.4)} +
  geom_errorbarh(aes(xmin = lo90, xmax = hi90), height = 0.32, linewidth = 0.6) +
  geom_point(size = 2.1) +
  facet_wrap(~state, scales = "free_x", nrow = 1) +
  scale_color_manual(values = mcol, labels = mlab, guide = "none") +
  scale_y_discrete(labels = mlab) +
  labs(x = "Reserve aboveground carbon in 2100 (Tg C)", y = NULL,
       title = "A) Structural divergence across models (90% CI; dashed = geometric-mean ensemble)") +
  theme_pub

# --- Panel B: CONUS scenario gradient by disturbance mode -------------------
cs <- fread(file.path(FIA, "harmonized_conus_by_scenario.csv"))
cs[, scenario := factor(scenario, levels = c("reserve","conservation","BAU","intensive"))]
cs[, dist_mode := factor(dist_mode, levels = c("nodisturb","disturbed"),
                         labels = c("No disturbance","Disturbance-aware"))]
cs[, pg := ensemble_median / 1000]; cs[, lo := ens_lo/1000]; cs[, hi := ens_hi/1000]
pB <- ggplot(cs, aes(x = scenario, y = pg, fill = dist_mode)) +
  geom_col(position = position_dodge(0.7), width = 0.62) +
  geom_errorbar(aes(ymin = lo, ymax = hi), position = position_dodge(0.7),
                width = 0.18, linewidth = 0.4, color = "grey30") +
  scale_fill_manual(values = c("No disturbance" = "#88B7D5", "Disturbance-aware" = "#1F6FA8"),
                    name = NULL) +
  labs(x = "Harvest scenario", y = "CONUS total carbon in 2100 (Pg C)",
       title = "B) Scenario gradient (ensemble median, model envelope)") +
  theme_pub

# --- Panel C: CONUS best-estimate reserve trajectory with 90% band ----------
be <- fread(file.path(FIA, "harmonized_best_estimate.csv"))
conus <- be[, .(equal = sum(ens_equal)/1000, lo = sum(lo90)/1000, hi = sum(hi90)/1000),
            by = year][order(year)]
# geometric-mean + median CONUS trajectories (FVS+YC+CBM full coverage) for comparison
gmc <- tryCatch(fread(file.path(FIA, "harmonized_conus_geomean.csv")), error = function(e) NULL)
pC <- ggplot(conus, aes(year, equal)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), fill = "#0072B2", alpha = 0.16) +
  geom_line(aes(color = "Equal-weight mean"), linewidth = 0.9) +
  geom_point(color = "#0072B2", size = 1.8) +
  {if (!is.null(gmc)) geom_line(data = gmc, aes(year, geom_Pg, color = "Geometric mean"), linewidth = 0.7)} +
  {if (!is.null(gmc)) geom_line(data = gmc, aes(year, median_Pg, color = "Median"), linewidth = 0.7, linetype = "longdash")} +
  scale_color_manual(values = c("Equal-weight mean" = "#0072B2", "Geometric mean" = "#D55E00",
                                "Median" = "grey35"), name = NULL) +
  scale_x_continuous(breaks = c(2025, 2050, 2075, 2100)) +
  labs(x = "Year", y = "CONUS reserve carbon (Pg C)",
       title = "C) Reserve trajectory: central-estimate choices (90% band on equal-weight)") +
  theme_pub

fig <- (pA / (pB | pC)) + plot_layout(heights = c(1, 1.05)) +
  plot_annotation(tag_levels = "A")
ggsave(file.path(OUT, "fig_crossmodel_headline.png"), fig, width = 19, height = 17,
       units = "cm", dpi = 300, bg = "white")
ggsave(file.path(OUT, "fig_crossmodel_headline.pdf"), fig, width = 19, height = 17, units = "cm")
cat("saved fig_crossmodel_headline.png/.pdf to", OUT, "\n")
