# Session 36, 6 Oct 2026. Pointer for decision 3, decides nothing. For the anchored run copy smoke
# (smoke_20261006_d10_unitfix_anch), how close is year zero biomass to the BiomassMax ceiling?
# Per state and ecoregion: mean live biomass per active site at t = 0 (sum of species means in
# spp-biomass-log.csv, g m-2) against the biomass weighted mean BiomassMax of the species present
# (SppEcoregionData_fia.csv in the run, Year 0), and against the largest species BiomassMax present.
# Also reported for the unit fix run, where stocks were 0.67 to 0.79 of FIADB.
# Gate S1: the summed species means reproduce the landscape t0 total in anch_landscape_20261006.csv to 0.1 pct.
suppressMessages(library(data.table))
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"
land <- fread(file.path(D, "gates/anch_landscape_20261006.csv"))
res <- list(); fail <- character()
for (st in c("NH","VT","MI","WI")) for (rn in c("smoke_20261006_d10_unitfix_anch", "smoke_20261001_d10_unitfix")) {
  R <- file.path(D, st, "runs", rn); cell <- fread(file.path(R, "build_summary.csv"))$cell_m
  sb <- fread(file.path(R, "spp-biomass-log.csv"), strip.white = TRUE)
  sb <- sb[!is.na(suppressWarnings(as.integer(EcoName))) & Time == 0][, eco := as.integer(EcoName)]
  sc <- grep("^AboveGroundBiomass_", names(sb), value = TRUE)
  lo <- melt(sb[, c("eco","NumActiveSites", sc), with = FALSE], id.vars = c("eco","NumActiveSites"), variable.name = "sp", value.name = "m")
  lo[, sp := sub("^AboveGroundBiomass_", "", sp)][is.na(m), m := 0]
  key <- if (grepl("anch", rn)) "anch" else "unitfix"
  tot <- lo[, sum(m * NumActiveSites) * cell^2 / 1e12]
  ref <- land[state == st & run == key, t0_Tg]
  if (abs(tot / ref - 1) > 0.001) fail <- c(fail, paste("S1", st, key))
  bm <- fread(file.path(R, "SppEcoregionData_fia.csv"))[Year == 0, .(eco = as.integer(EcoregionName), sp = SpeciesCode, BMX = BiomassMax, ANPP = ANPPmax)]
  x <- merge(lo, bm, by = c("eco","sp"), all.x = TRUE)
  r <- x[, .(sites = NumActiveSites[1], mean_B = sum(m), wBMX = sum(m * BMX, na.rm = TRUE) / sum(m[!is.na(BMX)]),
             maxBMX_present = max(BMX[m > 0], na.rm = TRUE), wANPP = sum(m * ANPP, na.rm = TRUE) / sum(m[!is.na(ANPP)])), by = eco]
  r[, `:=`(state = st, run = key, B_over_wBMX = round(mean_B / wBMX, 3), B_over_maxBMX = round(mean_B / maxBMX_present, 3))]
  res[[length(res) + 1]] <- r
}
res <- rbindlist(res)
st_sum <- res[, .(mean_B = weighted.mean(mean_B, sites), wBMX = weighted.mean(wBMX, sites),
                  B_over_wBMX = round(weighted.mean(B_over_wBMX, sites), 3), B_over_maxBMX = round(weighted.mean(B_over_maxBMX, sites), 3),
                  wANPP = round(weighted.mean(wANPP, sites))), by = .(state, run)]
fwrite(res, file.path(D, "gates/bmx_saturation_by_ecoregion_20261006.csv"))
fwrite(st_sum, file.path(D, "gates/bmx_saturation_by_state_20261006.csv"))
print(st_sum[order(run, state)]); print(res[run == "anch", .(state, eco, sites, mean_B = round(mean_B), wBMX = round(wBMX), B_over_wBMX, B_over_maxBMX)])
cat("GATES:", if (length(fail)) paste(fail, collapse = "; ") else "ALL PASS", "\n")
if (length(fail)) quit(status = 1)
