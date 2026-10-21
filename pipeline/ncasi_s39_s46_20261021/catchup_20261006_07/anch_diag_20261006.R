# Session 35, 6 Oct 2026. Scores the anchored run copy smoke (smoke_20261006_d10_unitfix_anch) against
# the 1 Oct unit fix smoke, NH VT MI WI, with the log based method of t2cal_diag_v2_20261006.R.
# Gates (hard): A1 run complete with no ERROR or Exception, LANDIS active sites equal the build;
#   A2 log total equals map total at t = 0 and 10 to 0.1 pct; A3 the unit fix base reproduces the 1 Oct gate
#   (NH 238.61, VT 233.04, MI 703.29, WI 624.69 Tg; ratios 1.032, 1.036, 1.462, 1.154);
#   A4 anchored year zero within 0.5 pct of FIADB (G8.3 by construction; integer rounding allows a little).
# Report: ten year ratio, ecoregion and species ratios, against FIADB 2015 to 2024 change.
suppressMessages({library(terra); library(data.table)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"
runs <- c(unitfix = "smoke_20261001_d10_unitfix", anch = "smoke_20261006_d10_unitfix_anch")
ref <- data.table(state = c("NH","VT","MI","WI"), ref_t0 = c(238.61, 233.04, 703.29, 624.69),
                  ref_ratio = c(1.032, 1.036, 1.462, 1.154), fia_change_pct = c(11.0, 7.8, 4.1, 10.6))
fia <- fread(file.path(D, "gates/fiadb_live_agb_fourstate_20261001.csv"))
fail <- character(); L <- list(); M <- list(); G <- list()
for (st in ref$state) for (k in names(runs)) {
  R <- file.path(D, st, "runs", runs[[k]])
  lgf <- file.path(R, "Landis-log.txt")
  if (!file.exists(lgf)) { fail <- c(fail, paste("A1 no log", st, k)); next }
  lg <- readLines(lgf, warn = FALSE); bs <- fread(file.path(R, "build_summary.csv")); cell <- bs$cell_m
  done <- any(grepl("Model run is complete", lg)); errs <- grep("ERROR|Exception", lg, value = TRUE)
  al <- grep("Sites: .* active", lg, value = TRUE)[1]
  act <- as.numeric(gsub(",", "", sub(".*Sites: ([0-9,]+) active.*", "\\1", al)))
  ok <- done && !length(errs) && !is.na(act) && act == bs$active_cells
  G[[length(G) + 1]] <- data.table(state = st, run = k, A1 = if (ok) "PASS" else "FAIL")
  if (!ok) { fail <- c(fail, paste("A1", st, k)); next }
  sb <- fread(file.path(R, "spp-biomass-log.csv"), strip.white = TRUE)
  sb <- sb[!is.na(suppressWarnings(as.integer(EcoName)))][, eco := as.integer(EcoName)]
  sc <- grep("^AboveGroundBiomass_", names(sb), value = TRUE)
  lo <- melt(sb[, c("Time","eco","NumActiveSites", sc), with = FALSE], id.vars = c("Time","eco","NumActiveSites"),
             variable.name = "species", value.name = "m")
  lo[, species := sub("^AboveGroundBiomass_", "", species)][is.na(m), m := 0]
  lo[, Tg := m * NumActiveSites * cell^2 / 1e12][, `:=`(state = st, run = k)]
  L[[length(L) + 1]] <- lo
  for (t in c(0, 10)) {
    mt <- sum(values(rast(file.path(R, "output/biomass", sprintf("biomass-TotalBiomass-%d.tif", t))))[, 1], na.rm = TRUE) * cell^2 / 1e12
    M[[length(M) + 1]] <- data.table(state = st, run = k, Time = t, map_Tg = mt, log_Tg = lo[Time == t, sum(Tg)])
  }
  gc()
}
G <- rbindlist(G); L <- rbindlist(L); M <- rbindlist(M)
if (nrow(M) && M[, any(abs(log_Tg / map_Tg - 1) > 0.001)]) fail <- c(fail, "A2 log != map")
land <- dcast(M, state + run ~ Time, value.var = "map_Tg"); setnames(land, c("0","10"), c("t0_Tg","t10_Tg"))
land[, ratio := t10_Tg / t0_Tg]
a3 <- merge(land[run == "unitfix"], ref, by = "state")
if (a3[, any(abs(t0_Tg - ref_t0) > 0.01 | abs(round(ratio, 3) - ref_ratio) > 0.001)]) fail <- c(fail, "A3 unitfix base not reproduced")
a4 <- merge(land[run == "anch"], fia[, .(state, fiadb_live_agb_Tg)], by = "state")[, rel := t0_Tg / fiadb_live_agb_Tg]
if (a4[, any(abs(rel - 1) > 0.005)]) fail <- c(fail, "A4 anchored year zero not at FIADB")
summ <- merge(dcast(land, state ~ run, value.var = "ratio"), ref[, .(state, fia_change_pct)], by = "state")
summ[, `:=`(unitfix_pct_10yr = round(100 * (unitfix - 1), 1), anch_pct_10yr = round(100 * (anch - 1), 1))]
byeco <- dcast(L[, .(Tg = sum(Tg)), by = .(state, run, eco, Time)], state + eco + run ~ Time, value.var = "Tg")
setnames(byeco, c("0","10"), c("t0_Tg","t10_Tg"), skip_absent = TRUE); byeco[, ratio := round(t10_Tg / t0_Tg, 3)]
byspp <- dcast(L[, .(Tg = sum(Tg)), by = .(state, run, species, Time)], state + species + run ~ Time, value.var = "Tg")
setnames(byspp, c("0","10"), c("t0_Tg","t10_Tg"), skip_absent = TRUE); byspp[, ratio := round(t10_Tg / t0_Tg, 3)]
O <- file.path(D, "gates")
fwrite(G, file.path(O, "anch_gates_20261006.csv")); fwrite(M, file.path(O, "anch_log_vs_map_20261006.csv"))
fwrite(land, file.path(O, "anch_landscape_20261006.csv")); fwrite(summ, file.path(O, "anch_summary_20261006.csv"))
fwrite(a4, file.path(O, "anch_year0_vs_fiadb_20261006.csv"))
fwrite(byeco, file.path(O, "anch_by_ecoregion_20261006.csv")); fwrite(byspp, file.path(O, "anch_by_species_20261006.csv"))
print(G); print(land); print(a4); print(summ)
print(dcast(byeco, state + eco ~ run, value.var = "ratio"))
cat("GATES:", if (length(fail)) paste(fail, collapse = "; ") else "ALL PASS", "\n")
if (length(fail)) quit(status = 1)
