# Gates for the LANDIS stage eight smoke runs, NH VT MI WI (states_fb_20260930).
# Reads the LANDIS log, not the exit code. Three gates per state, plus diagnostics:
#   G8.1 run_complete     Landis-log.txt contains "Model run is complete" and no ERROR or Exception line
#   G8.2 active_cells     cells LANDIS reports active equal the build's active cells, and the
#                         active share of 270 m ecoregion cells is reported
#   G8.3 year0_vs_fiadb   year zero TotalBiomass summed over the landscape (Tg) against the
#                         FIADB design-based live AGB for the state's latest EXPVOL EVALID;
#                         PASS inside 0.80 to 1.25, otherwise FLAG (IC is unanchored by design)
#   diag year0_vs_ic      year zero Tg against the IC-implied Tg from the build (initialisation check)
#   diag year10_over_0    landscape biomass ratio, year 10 over year 0 (biological realism)
# Appends rows to gates/smoke_gates_20261001.tsv in the gates_20260929.tsv layout.
suppressMessages({library(terra); library(data.table)})
D   <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"
DUR <- 10
fia <- fread(file.path(D, "gates/fiadb_live_agb_fourstate_20261001.csv"))
rows <- list(); now <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
add <- function(st, gate, val, thr, res, note = "")
  rows[[length(rows) + 1]] <<- data.table(time = now, state = st, stage = paste0("stage8_", TAG),
                                          gate = gate, value = val, threshold = thr, result = res, note = note)
# LANDIS writes output rasters without georeferencing (res 1), so cell area comes from the
# build's CellLength, not from res(). First version used res() and read every total as 0.00 Tg.
TAG <- commandArgs(TRUE)[1]; if (is.na(TAG)) TAG <- paste0("smoke_20261001_d", DUR)
tg_of <- function(f, cell) { r <- rast(f); sum(values(r), na.rm = TRUE) * cell^2 / 1e12 }
for (st in c("NH", "VT", "MI", "WI")) {
  R <- file.path(D, st, "runs", TAG)
  lg <- file.path(R, "Landis-log.txt")
  log <- if (file.exists(lg)) readLines(lg, warn = FALSE) else character()
  done <- any(grepl("Model run is complete", log))
  errs <- grep("ERROR|Exception", log, value = TRUE)
  add(st, "G8.1 run_complete", as.character(done), "TRUE and no ERROR/Exception",
      if (done && !length(errs)) "PASS" else "FAIL",
      if (length(errs)) substr(errs[1], 1, 160) else "")
  bs <- fread(file.path(R, "build_summary.csv"))
  # LANDIS writes "Sites: 259,296 active (40.8%), ..."; strip thousands commas before parsing
  al <- grep("Sites: .* active", log, value = TRUE)[1]
  rep_act <- if (!is.na(al)) as.numeric(gsub(",", "", sub(".*Sites: ([0-9,]+) active.*", "\\1", al))) else NA
  add(st, "G8.2 active_cells", sprintf("landis %s build %d share_of_eco %.4f", rep_act, bs$active_cells, bs$active_share_of_eco),
      "landis == build", if (!is.na(rep_act) && rep_act == bs$active_cells) "PASS" else "CHECK",
      paste("log line:", substr(paste(al, collapse = " | "), 1, 160)))
  f0 <- file.path(R, "output/biomass/biomass-TotalBiomass-0.tif")
  f10 <- file.path(R, sprintf("output/biomass/biomass-TotalBiomass-%d.tif", DUR))
  if (file.exists(f0)) {
    t0 <- tg_of(f0, bs$cell_m); ref <- fia[state == st, fiadb_live_agb_Tg]; ratio <- t0 / ref
    add(st, "G8.3 year0_vs_fiadb", sprintf("%.2f Tg vs %.2f Tg ratio %.3f", t0, ref, ratio), "0.80 to 1.25",
        if (ratio >= 0.80 && ratio <= 1.25) "PASS" else "FLAG", sprintf("EVALID %s", fia[state == st, evalid]))
    add(st, "diag year0_vs_ic", sprintf("%.2f Tg vs IC %.2f ratio %.3f", t0, bs$ic_implied_year0_Tg, t0 / bs$ic_implied_year0_Tg),
        "report", "INFO")
    if (file.exists(f10)) add(st, "diag year10_over_0", sprintf("%.3f", tg_of(f10, bs$cell_m) / t0), "report", "INFO")
    add(st, "diag mean_density", sprintf("%.1f Mg ha-1 on %.0f ha", t0 * 1e6 / bs$active_ha, bs$active_ha), "report", "INFO")
  } else add(st, "G8.3 year0_vs_fiadb", "no year 0 map", "map exists", "FAIL")
}
out <- rbindlist(rows); print(out[, .(state, gate, value, result)])
fwrite(out, file.path(D, paste0("gates/gates_", TAG, ".tsv")), sep = "\t")
