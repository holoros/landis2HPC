#!/usr/bin/env Rscript
# extract_hcs_plot_prob.R
#
# Per-plot harvest-probability driver for the harmonized scenarios. Samples the
# CONUS 30 m HCS phase5_v1 harvest-probability rasters (TreeMap 2016 grid) at each
# FIA plot location, giving every plot a spatially explicit harvest probability.
#
#   p_any      = P(any harvest) in the HCS observation window  -> BAU driver
#   p_partial  = P(partial)                                    -> conservation prescription
#   p_clearcut = P(clearcut)                                   -> intensive prescription
#
# Scenario harvest probability per plot = base prob * multiplier:
#   reserve 0 | BAU p_any x1 | conservation p_any x0.6 (partial) | intensive p_any x2 (clearcut)
#
# Output: plot_hcs_prob.csv  (state, PLT_CN, lon, lat, p_any, p_partial, p_clearcut)
# module load gcc/12.3.0; module load gdal/3.7.3 geos/3.12.0 proj/9.2.1; module load R/4.4.0

suppressPackageStartupMessages({ library(terra); library(data.table) })
args   <- commandArgs(trailingOnly = TRUE)
states <- strsplit(if (length(args) >= 1) args[1] else "WA,MN,IN,OH,WI,MI", ",")[[1]]
tools  <- "/fs/scratch/PUOM0008/crsfaaron/landis2/tools"
hdir   <- "/fs/scratch/PUOM0008/crsfaaron/conus_hcs/output/phase5_v1"

r_any  <- rast(file.path(hdir, "p_harvest_any_TM2016_v1.tif"))
r_part <- rast(file.path(hdir, "p_harvest_partial_TM2016_v1.tif"))
r_cc   <- rast(file.path(hdir, "p_harvest_clearcut_TM2016_v1.tif"))

res <- rbindlist(lapply(states, function(st) {
  f <- file.path(tools, paste0("untreated_plots_", st, ".csv"))
  if (!file.exists(f)) return(NULL)
  d <- fread(f)
  ll <- grep("LON", names(d), value = TRUE)[1]; la <- grep("LAT", names(d), value = TRUE)[1]
  cn <- grep("PLTCN|PLT_CN|FIRST_PLTCN", names(d), value = TRUE)[1]
  d <- d[!is.na(get(ll)) & !is.na(get(la))]
  pts <- vect(d, geom = c(ll, la), crs = "EPSG:4326")
  pts <- project(pts, crs(r_any))
  data.table(state = st,
             PLT_CN = as.character(d[[cn]]),
             lon = d[[ll]], lat = d[[la]],
             p_any      = terra::extract(r_any,  pts)[, 2],
             p_partial  = terra::extract(r_part, pts)[, 2],
             p_clearcut = terra::extract(r_cc,   pts)[, 2])
}))

fwrite(res, file.path(tools, "plot_hcs_prob.csv"))
cat(sprintf("wrote plot_hcs_prob.csv: %d plots across %d states\n", nrow(res), length(states)))
print(res[, .(n = .N, mean_p_any = round(mean(p_any, na.rm=TRUE),3),
              mean_p_cc = round(mean(p_clearcut, na.rm=TRUE),3)), by = state])
