# build_hcs_calibration.R
# Stage 2 of the consistent CONUS harvest recalibration. Calibrate the HCS common
# harvest layer to the FIA NFI removal benchmark (REMV_PERC) so each state's BAU
# effective removal rate h*f matches the empirical annual removal rate. Non
# destructive: writes a calibrated copy + a comparison table; the original is untouched.
suppressMessages({library(data.table)})

FIA  <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
HCS  <- "/users/PUOM0008/crsfaaron/cbm_states/cross_state/libcbm/tools_conus/14_outputs/uncertainty/hcs_harvest_rate_by_state.csv"
BDIR <- file.path(FIA, "nfi_benchmark")

F_CLEARCUT <- 0.85; F_PARTIAL <- 0.45   # match apply_harvest_scenarios.R

# FIA NFI benchmark: latest year REMV_PERC per state.
bf <- list.files(BDIR, pattern = "^nfi_removal_.*\\.csv$", full.names = TRUE)
bench <- rbindlist(lapply(bf, function(f){
  d <- fread(f); setnames(d, tolower(names(d)))
  d[which.max(year), .(state, remv_perc)]
}), fill = TRUE)

hcs <- fread(HCS)
hcs[, f := clearcut_frac * F_CLEARCUT + (1 - clearcut_frac) * F_PARTIAL]
hcs[, h_old := harvest_rate_pct_yr / 100]
hcs[, eff_old_pct := h_old * f * 100]          # our current BAU effective removal %/yr

cal <- merge(hcs, bench, by = "state", all.x = TRUE)
# Target: h_new * f = remv_perc/100  ->  new area rate so effective rate matches FIA.
cal[, h_new := fifelse(!is.na(remv_perc), (remv_perc/100) / f, h_old)]
cal[, rate_new_pct := h_new * 100]
cal[, factor := round(h_new / h_old, 3)]

# Scale the area columns proportionally, keep clearcut_frac.
for (col in c("clearcut_ha_yr","partial_ha_yr","total_ha_yr"))
  cal[, (col) := round(get(col) * h_new / h_old)]
cal[, harvest_rate_pct_yr := round(rate_new_pct, 3)]

# Write the calibrated HCS in the original schema.
keep <- c("state","forest_ha","clearcut_ha_yr","partial_ha_yr","total_ha_yr",
          "harvest_rate_pct_yr","clearcut_frac")
fwrite(cal[, ..keep], file.path(FIA, "hcs_harvest_rate_by_state_calibrated.csv"))

# Comparison table for review.
cmp <- cal[, .(state,
               rate_old = round(h_old*100,3), eff_old = round(eff_old_pct,3),
               fia_remv = round(remv_perc,3),
               rate_new = round(rate_new_pct,3), factor)][order(-factor)]
fwrite(cmp, file.path(FIA, "hcs_calibration_comparison.csv"))

cat("states calibrated:", sum(!is.na(cal$remv_perc)), "of", nrow(cal), "\n")
cat("missing benchmark (kept at old rate):",
    paste(cal[is.na(remv_perc), state], collapse=", "), "\n\n")
cat("Largest upward corrections (most under set):\n")
print(head(cmp[order(-factor)], 8))
cat("\nLargest downward corrections (most over set):\n")
print(head(cmp[order(factor)], 8))
