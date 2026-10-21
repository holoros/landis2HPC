# Session 37, 7 Oct 2026. Scores smoke_bmxcal_20261007.sh. Landscape totals from the TotalBiomass maps summed
# over all cells (no cell overlay, so the vertical flip of LANDIS output does not matter) x CellLength^2.
# Gates (hard, all runs): B1 log says complete, no ERROR or Exception, active sites equal the build.
# Formal anchored runs: B2 year 0 within 0.2 pct of the FIA EVALIDator 2024 stock (grm_realism_fourstate_20261006.csv);
#   B3 10 year ratio within 0.5 pct of the 6 Oct run copy (gates/anch_landscape_20261006.csv, job 15303879).
# Calibration runs: B4 year 0 identical to the formal anchored run (BiomassMax does not enter initialisation at
#   these stocks if LANDIS caps nothing; reported, and a difference over 0.1 pct is a FLAG, not a failure).
# Calibration: annual change (t10 - t0)/10 against FIA net growth (gross growth minus mortality, 95 pct CI) by
#   BiomassMax multiplier; m* by linear interpolation inside the grid only, never extrapolated.
suppressMessages({library(terra); library(data.table)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"
fia <- fread(file.path(D, "gates/grm_realism_fourstate_20261006.csv"))
rc  <- fread(file.path(D, "gates/anch_landscape_20261006.csv"))[run == "anch", .(state, rc_ratio = t10_Tg / t0_Tg)]
runs <- rbind(data.table(state = c("NH","VT","WI","MI"), run = "smoke_20261007_d10_anchored", m = 1),
              CJ(state = c("NH","VT","WI"), m = c(1.25, 1.5, 2.0))[, run := paste0("smoke_20261007_d10_anch_bmx", c("1.25","1.5","2.0")[match(m, c(1.25, 1.5, 2))])], use.names = TRUE)
fail <- character(); res <- list()
for (i in seq_len(nrow(runs))) {
  st <- runs$state[i]; R <- file.path(D, st, "runs", runs$run[i])
  lg <- if (file.exists(file.path(R, "Landis-log.txt"))) readLines(file.path(R, "Landis-log.txt"), warn = FALSE) else character()
  bs <- fread(file.path(R, "build_summary.csv")); cell <- bs$cell_m
  al <- grep("Sites: .* active", lg, value = TRUE)[1]
  act <- if (is.na(al)) NA else as.numeric(gsub(",", "", sub(".*Sites: ([0-9,]+) active.*", "\\1", al)))
  b1 <- any(grepl("Model run is complete", lg)) && !length(grep("ERROR|Exception", lg)) && isTRUE(act == bs$active_cells)
  if (!b1) { fail <- c(fail, paste("B1", st, runs$run[i])); res[[i]] <- data.table(state = st, m = runs$m[i], B1 = FALSE); next }
  tg <- function(t) sum(values(rast(file.path(R, sprintf("output/biomass/biomass-TotalBiomass-%d.tif", t))))[, 1], na.rm = TRUE) * cell^2 / 1e12
  t0 <- tg(0); t10 <- tg(10)
  res[[i]] <- data.table(state = st, m = runs$m[i], run = runs$run[i], B1 = TRUE, t0_Tg = t0, t10_Tg = t10,
                         ratio = t10 / t0, annual_Tg = (t10 - t0) / 10)
  gc()
}
res <- rbindlist(res, fill = TRUE)
f <- merge(res[m == 1], fia[, .(state, stock_Tg, fia_net_growth, fia_ng_lo, fia_ng_hi)], by = "state")
f <- merge(f, rc, by = "state")
f[, `:=`(B2 = abs(t0_Tg / stock_Tg - 1) < 0.002, B3 = abs(ratio / rc_ratio - 1) < 0.005)]
if (f[, any(!B2)]) fail <- c(fail, "B2 formal year 0 not at FIADB")
if (f[, any(!B3)]) fail <- c(fail, "B3 formal ratio differs from run copy")
base0 <- res[m == 1, .(state, t0_base = t0_Tg)]
res <- merge(res, base0, by = "state", all.x = TRUE)[, B4_t0_rel := round(t0_Tg / t0_base - 1, 5)]
cal <- merge(res[state %in% c("NH","VT","WI")], fia[, .(state, fia_net_growth, fia_ng_lo, fia_ng_hi)], by = "state")
cal[, ratio_to_fia := annual_Tg / fia_net_growth]
mstar <- cal[order(state, m), {
  interp <- function(target) { x <- m; y <- annual_Tg; j <- which(diff(sign(y - target)) != 0)
    if (!length(j)) NA_real_ else { j <- j[1]; x[j] + (target - y[j]) * (x[j + 1] - x[j]) / (y[j + 1] - y[j]) } }
  .(m_star = interp(fia_net_growth[1]), m_star_lo = interp(fia_ng_lo[1]), m_star_hi = interp(fia_ng_hi[1]),
    max_ratio_on_grid = max(ratio_to_fia))
}, by = state]
O <- file.path(D, "gates")
fwrite(res, file.path(O, "bmxcal_runs_20261007.csv")); fwrite(f, file.path(O, "formal_anchored_smoke_20261007.csv"))
fwrite(cal, file.path(O, "bmxcal_curve_20261007.csv")); fwrite(mstar, file.path(O, "bmxcal_mstar_20261007.csv"))
print(f[, .(state, t0_Tg, stock_Tg, ratio, rc_ratio, annual_Tg, fia_net_growth, B2, B3)])
print(cal[order(state, m), .(state, m, annual_Tg = round(annual_Tg, 3), fia_net_growth, ratio_to_fia = round(ratio_to_fia, 3), B4_t0_rel)])
print(mstar)
cat("GATES:", if (length(fail)) paste(fail, collapse = "; ") else "ALL PASS", "\n")
if (length(fail)) quit(status = 1)
