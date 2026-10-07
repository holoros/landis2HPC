# Session 35, 6 Oct 2026. Replaces t2cal_diag_20261003.R, whose ecoregion and landscape figures are WRONG:
# it overlaid LANDIS output rasters on ecoregions.tif cell by cell, but the output rasters are written
# unreferenced and do not align with the input grid when read by terra (MI: 843,417 biomass cells fell on
# NA ecoregion cells and ecoregion 55 read as empty), so it summed a displaced subset of the landscape.
# v2 takes ecoregion and species totals from LANDIS's own spp-biomass-log.csv
# (mean g m-2 per active site x NumActiveSites x CellLength^2) and gates them against the
# TotalBiomass map sums over all cells, which need no alignment.
# Gates (hard): G1 log total at t=0 and t=10 equals map total to 0.1 pct, both runs, both states;
#   G2 base run reproduces the 1 Oct gate (MI 703.29 Tg, ratio 1.462; WI 624.69, 1.154) to 0.01 Tg and 0.001;
#   G3 t2cal year zero equals base year zero to 0.1 pct (same IC).
# Diagnostic: test whether a vertical flip of the output map aligns it with ecoregions.tif.
suppressMessages({library(terra); library(data.table)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"
runs <- c(base = "smoke_20261001_d10_unitfix", t2cal = "smoke_20261003_d10_unitfix_t2cal")
ref <- data.table(state = c("MI","WI"), ref_t0 = c(703.29, 624.69), ref_ratio = c(1.462, 1.154))
fail <- character(); L <- list(); M <- list(); FL <- list()
for (st in c("MI","WI")) for (k in names(runs)) {
  R <- file.path(D, st, "runs", runs[[k]])
  cell <- fread(file.path(R, "build_summary.csv"))$cell_m
  lg <- fread(file.path(R, "spp-biomass-log.csv"), strip.white = TRUE)
  lg <- lg[EcoName != "nodata" & !is.na(suppressWarnings(as.integer(EcoName)))]
  lg[, eco := as.integer(EcoName)]
  sc <- grep("^AboveGroundBiomass_", names(lg), value = TRUE)
  long <- melt(lg[, c("Time","eco","NumActiveSites", sc), with = FALSE], id.vars = c("Time","eco","NumActiveSites"),
               variable.name = "species", value.name = "mean_gm2")
  long[, species := sub("^AboveGroundBiomass_", "", species)]
  long[is.na(mean_gm2), mean_gm2 := 0]
  long[, Tg := mean_gm2 * NumActiveSites * cell^2 / 1e12][, `:=`(state = st, run = k)]
  L[[length(L) + 1]] <- long
  for (t in c(0, 10)) {
    mt <- sum(values(rast(file.path(R, "output/biomass", sprintf("biomass-TotalBiomass-%d.tif", t))))[, 1], na.rm = TRUE) * cell^2 / 1e12
    M[[length(M) + 1]] <- data.table(state = st, run = k, Time = t, map_Tg = mt, log_Tg = long[Time == t, sum(Tg)])
  }
  if (k == "base") {
    e <- values(rast(file.path(R, "ecoregions.tif")))[, 1]
    t0r <- rast(file.path(R, "output/biomass/biomass-TotalBiomass-0.tif"))
    for (fx in c("none", "vertical")) {
      tv <- values(if (fx == "none") t0r else flip(t0r, "vertical"))[, 1]
      FL[[length(FL) + 1]] <- data.table(state = st, flip = fx,
        biomass_cells_on_NA_eco = sum(tv > 0 & is.na(e), na.rm = TRUE),
        active_eco_cells_without_biomass = sum(!is.na(e) & e > 0 & !(tv > 0), na.rm = TRUE))
    }
  }
  gc()
}
L <- rbindlist(L); M <- rbindlist(M); FL <- rbindlist(FL)
M[, rel := abs(log_Tg / map_Tg - 1)]
if (M[, any(rel > 0.001)]) fail <- c(fail, "G1 log total != map total")
land <- dcast(M, state + run ~ Time, value.var = "map_Tg"); setnames(land, c("0","10"), c("t0_Tg","t10_Tg"))
land[, ratio := t10_Tg / t0_Tg]
g2 <- merge(land[run == "base"], ref, by = "state")
if (g2[, any(abs(t0_Tg - ref_t0) > 0.01 | abs(round(ratio, 3) - ref_ratio) > 0.001)]) fail <- c(fail, "G2 base does not reproduce 1 Oct gate")
g3 <- dcast(land, state ~ run, value.var = "t0_Tg")
if (g3[, any(abs(t2cal / base - 1) > 0.001)]) fail <- c(fail, "G3 year zero differs")
byeco <- dcast(L[, .(Tg = sum(Tg)), by = .(state, run, eco, Time)], state + eco + run ~ Time, value.var = "Tg")
setnames(byeco, c("0","10"), c("t0_Tg","t10_Tg")); byeco[, ratio := round(t10_Tg / t0_Tg, 3)]
byspp <- dcast(L[, .(Tg = sum(Tg)), by = .(state, run, species, Time)], state + species + run ~ Time, value.var = "Tg")
setnames(byspp, c("0","10"), c("t0_Tg","t10_Tg")); byspp[, ratio := round(t10_Tg / t0_Tg, 3)]
byspp[, share_of_increase := round((t10_Tg - t0_Tg) / sum(t10_Tg - t0_Tg), 3), by = .(state, run)]
O <- file.path(D, "gates")
fwrite(M, file.path(O, "t2cal_v2_log_vs_map_20261006.csv")); fwrite(land, file.path(O, "t2cal_v2_landscape_20261006.csv"))
fwrite(byeco, file.path(O, "t2cal_v2_by_ecoregion_20261006.csv")); fwrite(byspp, file.path(O, "t2cal_v2_by_species_20261006.csv"))
fwrite(FL, file.path(O, "t2cal_v2_raster_alignment_20261006.csv"))
print(M); print(land); print(FL)
print(dcast(byeco, state + eco ~ run, value.var = "ratio"))
top <- byspp[run == "base"][order(state, -t0_Tg)][, head(.SD, 10), by = state]
print(dcast(byspp[species %in% top$species], state + species ~ run, value.var = c("ratio", "share_of_increase")))
cat("GATES:", if (length(fail)) paste(fail, collapse = "; ") else "ALL PASS", "\n")
if (length(fail)) quit(status = 1)
