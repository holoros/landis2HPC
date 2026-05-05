#!/usr/bin/env Rscript
#
# aggregate_subtile_factorial.R
#
# Walk the subtile_factorial directory, sum biomass per (scenario,tile,year),
# group by (owner,climate,year), produce summary CSVs and figures showing
# climate x owner sensitivity even with partial completion.
#
# Usage on Cardinal:
#   Rscript aggregate_subtile_factorial.R
#   Rscript aggregate_subtile_factorial.R --state ME
#   Rscript aggregate_subtile_factorial.R --years 0,5,10,25,50

suppressPackageStartupMessages({
  library(terra)
  library(data.table)
  library(ggplot2)
  library(scales)
  library(viridisLite)
  library(patchwork)
  library(optparse)
})

opts <- list(
  make_option("--state", type = "character", default = "ME"),
  make_option("--years", type = "character", default = "0,5,10,25,50"),
  make_option("--out",   type = "character", default = NULL)
)
opt <- parse_args(OptionParser(option_list = opts))
ST <- opt$state
years <- as.integer(strsplit(opt$years, ",")[[1]])

LANDIS <- "/fs/scratch/PUOM0008/crsfaaron/landis2"
FACT_DIR <- file.path(LANDIS, "states", ST, "runs", "subtile_factorial")
OUT_DIR <- ifelse(is.null(opt$out),
                  file.path(FACT_DIR, "_analysis"), opt$out)
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat(sprintf("=== Aggregating %s subtile factorial ===\n", ST))
cat(sprintf("  scanning %s\n", FACT_DIR))

##############################################################################
# Discover scenarios
##############################################################################
dirs <- list.dirs(FACT_DIR, recursive = FALSE)
dirs <- dirs[!grepl("_cache|_analysis", basename(dirs))]
cat(sprintf("  scenario dirs: %d\n", length(dirs)))

# Parse scenario name: tile_NNN__own_X_clim_Y_harv_Z
parse_name <- function(n) {
  m <- regmatches(n, regexec(
    "^(tile_\\d+)__own_([a-z]+)_clim_([a-z0-9]+)_harv_([a-z]+)$", n))[[1]]
  if (length(m) < 5) return(NULL)
  list(tile = m[2], owner = m[3], climate = m[4], harvest = m[5])
}

##############################################################################
# Per scenario per year totals
##############################################################################
totals <- data.table()
for (d in dirs) {
  meta <- parse_name(basename(d))
  if (is.null(meta)) next
  bm <- file.path(d, "output", "biomass")
  if (!dir.exists(bm)) next

  for (yr in years) {
    f <- file.path(bm, sprintf("biomass-TotalBiomass-%d.tif", yr))
    if (!file.exists(f)) next
    r <- tryCatch(rast(f), error = function(e) NULL)
    if (is.null(r)) next
    # LANDIS output rasters often lack CRS; res(r) returns 1 not 30.
    # Hardcode cell area from scenario.txt CellLength = 30 m.
    cell_m2 <- 900
    v <- values(r, mat = FALSE)
    v <- v[is.finite(v) & v > 0]
    tg <- sum(as.numeric(v)) * cell_m2 / 1e12
    n_cells <- length(v)
    totals <- rbind(totals, data.table(
      tile = meta$tile, owner = meta$owner, climate = meta$climate,
      harvest = meta$harvest, year = yr,
      n_cells = n_cells, total_tg = tg
    ))
  }
}
cat(sprintf("  extracted %d (scenario, year) records from %d scenarios\n",
            nrow(totals), uniqueN(totals[, .(tile, owner, climate, harvest)])))

if (nrow(totals) == 0) {
  cat("  no data extracted; aborting\n"); quit(status = 0)
}

fwrite(totals, file.path(OUT_DIR, sprintf("%s_subtile_totals_long.csv", ST)))

##############################################################################
# Aggregate to (owner, climate, year) — sum across tiles
##############################################################################
agg <- totals[, .(
  n_tiles = .N,
  total_tg = sum(total_tg),
  total_cells = sum(n_cells)
), by = .(owner, climate, year)]

# Number of unique tiles available for this owner-climate combo.
# Bug fix: the prior `totals[owner == owner & climate == climate]` form
# matched every row because `owner` on the right resolved to the column,
# not the per-group value. Use a join via .EACHI scoping instead.
complete_lookup <- totals[, .(complete_tiles = uniqueN(tile)),
                          by = .(owner, climate)]
agg <- complete_lookup[agg, on = .(owner, climate)]

cat("\n  Aggregate by (owner, climate, year):\n")
print(agg[order(owner, climate, year)], row.names = FALSE)

fwrite(agg, file.path(OUT_DIR, sprintf("%s_subtile_aggregate.csv", ST)))

##############################################################################
# Year-50 climate x owner heatmap (sensitivity signal)
##############################################################################
yr_max <- max(agg$year)
heatmap_data <- agg[year == yr_max]

if (nrow(heatmap_data) > 0) {
  heatmap_data[, climate := factor(climate, levels = c("baseline", "ssp245", "ssp585"))]
  heatmap_data[, owner := factor(owner, levels = c("ind", "nipf", "public"),
                                 labels = c("Industrial", "NIPF", "Public"))]

  # Compute % delta vs baseline within each owner
  heatmap_data[, delta_pct := 100 * (total_tg - total_tg[climate == "baseline"]) / total_tg[climate == "baseline"],
               by = owner]

  p_heat <- ggplot(heatmap_data, aes(climate, owner, fill = delta_pct)) +
    geom_tile(color = "white", linewidth = 1.5) +
    geom_text(aes(label = sprintf("%.1f Tg\n(%+.1f%%)", total_tg, delta_pct)),
              color = "white", size = 3.5, fontface = "bold") +
    scale_fill_gradient2(low = "#E76F51", mid = "white", high = "#1B4332",
                         midpoint = 0, name = "% delta\nvs baseline") +
    theme_minimal(11) +
    theme(panel.grid = element_blank(),
          plot.title = element_text(face = "bold", size = 13, color = "#1B4332")) +
    labs(title = sprintf("%s year %d AGB sensitivity by climate x owner", ST, yr_max),
         subtitle = sprintf("Aggregated across %d completed scenarios. %% delta vs baseline within each owner row.",
                            sum(heatmap_data$n_tiles)),
         x = "Climate scenario", y = "Landowner class")

  ggsave(file.path(OUT_DIR, sprintf("%s_climate_owner_heatmap_year%d.png", ST, yr_max)),
         p_heat, width = 9, height = 6, dpi = 200, bg = "white")
}

##############################################################################
# Time series plot
##############################################################################
ts_data <- agg
ts_data[, climate := factor(climate, levels = c("baseline", "ssp245", "ssp585"))]
ts_data[, owner := factor(owner, levels = c("ind", "nipf", "public"),
                          labels = c("Industrial", "NIPF", "Public"))]

p_ts <- ggplot(ts_data, aes(year, total_tg, color = climate, linetype = owner)) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2) +
  scale_color_viridis_d(option = "G", end = 0.85) +
  scale_y_continuous(labels = comma) +
  theme_minimal(11) +
  theme(plot.title = element_text(face = "bold", size = 13, color = "#1B4332")) +
  labs(title = sprintf("%s biomass trajectories by climate x owner", ST),
       subtitle = "Aggregated across completed scenarios. No harvest extension applied (image bug).",
       y = "Total AGB (Tg)", x = "Simulation year")

ggsave(file.path(OUT_DIR, sprintf("%s_subtile_trajectories.png", ST)),
       p_ts, width = 11, height = 7, dpi = 200, bg = "white")

##############################################################################
# Coverage diagnostic
##############################################################################
cov_data <- totals[year == 0, .(n_completed = .N), by = .(owner, climate)]
cov_data[, climate := factor(climate, levels = c("baseline", "ssp245", "ssp585"))]
cov_data[, owner := factor(owner, levels = c("ind", "nipf", "public"),
                           labels = c("Industrial", "NIPF", "Public"))]

p_cov <- ggplot(cov_data, aes(climate, owner, fill = n_completed)) +
  geom_tile(color = "white", linewidth = 1.5) +
  geom_text(aes(label = n_completed), color = "white", fontface = "bold") +
  scale_fill_viridis_c(option = "G", name = "tiles\ncompleted") +
  theme_minimal(11) +
  theme(panel.grid = element_blank()) +
  labs(title = sprintf("%s subtile factorial completion coverage", ST),
       subtitle = "Number of tiles where year-50 finished per (owner, climate)",
       x = "Climate scenario", y = "Landowner class")

ggsave(file.path(OUT_DIR, sprintf("%s_completion_coverage.png", ST)),
       p_cov, width = 9, height = 6, dpi = 200, bg = "white")

cat(sprintf("\n  Wrote analysis to %s\n", OUT_DIR))
cat("  Files:\n")
list.files(OUT_DIR, full.names = FALSE)
