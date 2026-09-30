#!/usr/bin/env Rscript
# stage4_state_ba.R: live basal-area composition by FIA SPCD for NH VT MI WI (plus ME, MN refs if present).
# Each plot's latest INVYR only; live trees (STATUSCD 1) DIA >= 1 in; BA = sum(TPA_UNADJ * 0.005454154 * DIA^2) (ft2/ac, plot-sum).
# No coordinates are read. Output: work_20260929/state_ba_by_spcd.csv (shares only, no plot identifiers).
suppressPackageStartupMessages(library(data.table))
R <- path.expand("~/restricted/ncasi-modeleval/fia_data_landis")
out <- list()
for (ST in c("NH", "VT", "MI", "WI")) {
  t <- fread(file.path(R, paste0(ST, "_TREE.csv")), select = c("STATECD", "UNITCD", "COUNTYCD", "PLOT", "INVYR", "STATUSCD", "SPCD", "DIA", "TPA_UNADJ"))
  t <- t[INVYR < 9999]
  t[, pid := paste(STATECD, UNITCD, COUNTYCD, PLOT)]
  last <- t[, .(INVYR = max(INVYR)), by = pid]
  t <- t[last, on = .(pid, INVYR)][STATUSCD == 1 & DIA >= 1 & !is.na(TPA_UNADJ)]
  b <- t[, .(ba = sum(TPA_UNADJ * 0.005454154 * DIA^2), ntree = .N), by = SPCD]
  b[, share := ba / sum(ba)]; b[, state := ST]
  cat(ST, "plots", nrow(last), "live trees", nrow(t), "INVYR range", paste(range(last$INVYR), collapse = "-"), "\n")
  out[[ST]] <- b
}
o <- rbindlist(out)
nm <- unique(fread(path.expand("~/landis2_fb/TREEMAP/TM2022/TreeMap2022_CONUS_Tree_Table.csv"), select = c("SPCD", "COMMON_NAME", "SCIENTIFIC_NAME")), by = "SPCD")
o <- merge(o, nm, by = "SPCD", all.x = TRUE)
setorder(o, state, -share)
fwrite(o, path.expand("~/landis2_fb/work_20260929/state_ba_by_spcd.csv"))
print(o[share >= 0.002, .(state, SPCD, COMMON_NAME, share = round(share, 4))], nrows = 400)
