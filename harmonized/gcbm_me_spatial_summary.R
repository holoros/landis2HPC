# =============================================================================
# Title: GCBM Maine spatial summary - trajectory, engine gap, carbon map
# Author: A. Weiskittel
# Date: 2026-06-13
# Description: From the retained GCBM Maine mosaics (AG_Biomass_C, Total_Ecosystem_C
#   per 5-yr step), compute (1) the state total carbon trajectory (Tg C), (2) the
#   MEASURED GCBM-over-libcbm engine gap vs the harmonized libcbm ME reserve, and
#   (3) a publication carbon map of aboveground live C. This turns the spatial run
#   into the measured ME engine value (replacing the +21% regional default) and the
#   spatial deliverable.
# Dependencies: FIA/gcbm_rasters/ME/{AG_Biomass_C,Total_Ecosystem_C}_<year>.tif,
#               FIA/cbm_reserve_raw_anchored.csv
# =============================================================================
suppressPackageStartupMessages({library(terra); library(data.table); library(ggplot2)})
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
RAS <- file.path(FIA, "gcbm_rasters/ME"); OUT <- file.path(FIA, "figures")
dir.create(OUT, showWarnings = FALSE)

# --- (1) state total carbon per year (Mg C/ha density * cell area -> Tg) -----
years <- sort(as.integer(gsub(".*_(\\d+)\\.tif$", "\\1",
            list.files(RAS, pattern = "^AG_Biomass_C_.*\\.tif$"))))
tot <- rbindlist(lapply(years, function(y) {
  ag  <- rast(file.path(RAS, sprintf("AG_Biomass_C_%d.tif", y)))
  te_f <- file.path(RAS, sprintf("Total_Ecosystem_C_%d.tif", y))
  area <- cellSize(ag, unit = "ha")                       # WGS84-correct per-cell ha
  ag_tg <- as.numeric(global(ag * area, "sum", na.rm = TRUE)) / 1e6
  te_tg <- if (file.exists(te_f)) as.numeric(global(rast(te_f) * area, "sum", na.rm = TRUE))/1e6 else NA_real_
  data.table(year = y, gcbm_ag_TgC = round(ag_tg, 2), gcbm_toteco_TgC = round(te_tg, 2))
}))
fwrite(tot, file.path(FIA, "gcbm_ME_spatial_trajectory.csv"))

# --- (2) measured engine gap: GCBM vs libcbm ME aboveground live C ------------
lib <- fread(file.path(FIA, "cbm_reserve_raw_anchored.csv"))[as.integer(dom) == 23 & scenario == "reserve"]
gap <- merge(tot[, .(year, gcbm_ag_TgC)],
             lib[, .(year, libcbm_TgC = agc_TgC_anchored)], by = "year")
gap[, gcbm_over_libcbm_pct := round(100 * (gcbm_ag_TgC - libcbm_TgC) / libcbm_TgC, 1)]
fwrite(gap, file.path(FIA, "gcbm_ME_engine_gap_measured.csv"))
cat("GCBM Maine aboveground live C vs libcbm (measured engine gap):\n"); print(gap)
cat(sprintf("\nMEAN measured GCBM-over-libcbm gap (ME): %+.1f%% (regional default was +21%%)\n",
            mean(gap$gcbm_over_libcbm_pct)))

# --- (3) carbon map (latest year AG live C) ----------------------------------
yr <- max(years); r <- rast(file.path(RAS, sprintf("AG_Biomass_C_%d.tif", yr)))
df <- as.data.frame(r, xy = TRUE); names(df)[3] <- "agc"
df <- df[is.finite(df$agc) & df$agc > 0, ]
p <- ggplot(df, aes(x, y, fill = agc)) + geom_raster() +
  scale_fill_viridis_c(option = "D", name = expression("AG live C (Mg C ha"^-1*")")) +
  coord_quickmap() +
  labs(title = sprintf("GCBM Maine aboveground live carbon, %d", yr),
       subtitle = "Spatially explicit (moja FLINT); harmonized reserve", x = NULL, y = NULL) +
  theme_minimal(base_size = 11) +
  theme(legend.position = "right", panel.grid = element_blank(),
        axis.text = element_text(size = 7), plot.title = element_text(face = "bold"))
ggsave(file.path(OUT, "fig_gcbm_ME_carbon_map.png"), p, width = 16, height = 16,
       units = "cm", dpi = 200, bg = "white")
cat("saved fig_gcbm_ME_carbon_map.png + gcbm_ME_spatial_trajectory.csv + engine_gap_measured.csv\n")
