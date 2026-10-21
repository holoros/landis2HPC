# Session 38, 7 Oct 2026. Scores fit_joint_20261007.sh (Decision 3: joint fit of ANPPmax and BiomassMax to FIA net growth).
# Same landscape total as smoke_bmxcal_diag_20261007.R: TotalBiomass maps summed over all cells x CellLength^2 (no cell
# overlay, so the vertical flip of LANDIS output does not matter). Run names are read as text from fit_grid_20261007.csv.
# Step 0, REPRODUCTION GATE: before any new run is scored, this code must reproduce known values from existing runs:
#   NH and VT smoke_20261007_d10_anch_bmx2.0_anpp2.0 at 0.611 and 0.748 of FIA net growth (job 15319635,
#   gates/anpp_probe_20261007.csv) and the four formal anchored runs (gates/formal_anchored_smoke_20261007.csv,
#   job 15319441). The recomputed annual change must equal the recorded one to 1e-6 Tg yr-1.
#   If any fails, nothing new is scored and the script exits 2.
# Step 1, gates on each new run: G1 log complete, no ERROR or Exception, active sites equal the build; G2 year 0 within
#   0.1 pct of the formal anchored run (multipliers should not move initialisation; a difference is a FLAG).
# Step 2, response surface per state: annual_Tg ~ a + b + a:b on the 3 x 3 grid (a = ANPPmax mult, b = BiomassMax mult),
#   with R2 and max residual. Solutions where the surface equals FIA net growth (and its CI ends) are reported only inside
#   the grid: for each grid b the a that hits the target, for each grid a the b, and the equal multiplier point (a = b)
#   where it lies inside both ranges. Never extrapolated.
# Step 3, controls: MI 1,1 ratio against the formal anchored 1.018; NH and VT a2_b2 against the probe a2 bmx2 replicate.
suppressMessages({library(terra); library(data.table)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"; O <- file.path(D, "gates")
fia <- fread(file.path(D, "gates/grm_realism_fourstate_20261006.csv"))[, .(state, stock_Tg, fia_net_growth, fia_ng_lo, fia_ng_hi)]
grid <- fread(file.path(D, "scripts_20261001/fit_grid_20261007.csv"), colClasses = "character")
score <- function(st, rn) {
  R <- file.path(D, st, "runs", rn)
  lg <- if (file.exists(file.path(R, "Landis-log.txt"))) readLines(file.path(R, "Landis-log.txt"), warn = FALSE) else character()
  bs <- fread(file.path(R, "build_summary.csv")); cell <- bs$cell_m
  al <- grep("Sites: .* active", lg, value = TRUE)[1]
  act <- if (is.na(al)) NA else as.numeric(gsub(",", "", sub(".*Sites: ([0-9,]+) active.*", "\\1", al)))
  g1 <- any(grepl("Model run is complete", lg)) && !length(grep("ERROR|Exception", lg)) && isTRUE(act == bs$active_cells)
  if (!g1) return(data.table(state = st, run = rn, G1 = FALSE))
  tg <- function(t) sum(values(rast(file.path(R, sprintf("output/biomass/biomass-TotalBiomass-%d.tif", t))))[, 1], na.rm = TRUE) * cell^2 / 1e12
  t0 <- tg(0); t10 <- tg(10); gc()
  data.table(state = st, run = rn, G1 = TRUE, t0_Tg = t0, t10_Tg = t10, annual_Tg = (t10 - t0) / 10)
}
# Step 0
kp <- fread(file.path(O, "anpp_probe_20261007.csv"))[run == "smoke_20261007_d10_anch_bmx2.0_anpp2.0", .(state, run, known_annual = annual_Tg)]
kf <- fread(file.path(O, "formal_anchored_smoke_20261007.csv"))[, .(state, run, known_annual = annual_Tg)]
known <- rbind(kp, kf)
rep0 <- rbindlist(Map(score, known$state, known$run), fill = TRUE)
rep0 <- merge(rep0, known, by = c("state", "run"))
rep0 <- merge(rep0, fia, by = "state")[, `:=`(ratio = annual_Tg / fia_net_growth, known_ratio = known_annual / fia_net_growth)]
rep0[, reproduced := abs(annual_Tg - known_annual) < 1e-6]
fwrite(rep0, file.path(O, "fit_joint_reproduce_20261007.csv"))
print(rep0[, .(state, run, annual_Tg, known_annual, ratio = round(ratio, 4), known_ratio = round(known_ratio, 4), reproduced)])
if (!all(rep0$reproduced)) { cat("REPRODUCTION GATE FAILED; nothing new scored\n"); quit(status = 2) }
cat("REPRODUCTION GATE PASS\n")
# Step 1
base0 <- rep0[run == "smoke_20261007_d10_anchored", .(state, t0_base = t0_Tg)]
res <- rbindlist(Map(score, grid$state, grid$run), fill = TRUE)
res <- cbind(res, grid[, .(a = as.numeric(anpp), b = as.numeric(bmx))])
res <- merge(merge(res, fia, by = "state"), base0, by = "state", all.x = TRUE)
res[, `:=`(ratio = annual_Tg / fia_net_growth, in_ci = annual_Tg >= fia_ng_lo & annual_Tg <= fia_ng_hi,
           G2_t0_rel = round(t0_Tg / t0_base - 1, 5))][, G2_flag := abs(G2_t0_rel) > 0.001]
fwrite(res, file.path(O, "fit_joint_runs_20261007.csv"))
print(res[order(state, a, b), .(state, a, b, G1, annual_Tg = round(annual_Tg, 3), fia_net_growth, ratio = round(ratio, 3), in_ci, G2_t0_rel)])
# Step 2
surf <- list(); sol <- list()
for (st in c("NH","VT","WI")) {
  x <- res[state == st & G1 == TRUE]; if (nrow(x) < 9) { cat("SURFACE SKIPPED", st, nrow(x), "runs\n"); next }
  m <- lm(annual_Tg ~ a * b, data = x); cf <- coef(m)
  surf[[st]] <- data.table(state = st, c0 = cf[1], ca = cf[2], cb = cf[3], cab = cf[4], r2 = summary(m)$r.squared,
                           max_abs_resid_Tg = max(abs(resid(m))))
  ar <- range(x$a); br <- range(x$b); f <- fia[state == st]
  for (tg in c("target","lo","hi")) {
    y <- switch(tg, target = f$fia_net_growth, lo = f$fia_ng_lo, hi = f$fia_ng_hi)
    a_at_b <- function(bb) (y - cf[1] - cf[3] * bb) / (cf[2] + cf[4] * bb)
    b_at_a <- function(aa) (y - cf[1] - cf[2] * aa) / (cf[3] + cf[4] * aa)
    cand <- rbind(data.table(path = "a_at_grid_b", b = unique(x$b))[, a := a_at_b(b)],
                  data.table(path = "b_at_grid_a", a = unique(x$a))[, b := b_at_a(a)], use.names = TRUE)
    eq <- tryCatch(uniroot(function(t) cf[1] + cf[2] * t + cf[3] * t + cf[4] * t^2 - y, c(0.5, 5))$root, error = function(e) NA_real_)
    cand <- rbind(cand, data.table(path = "equal_mult", a = eq, b = eq), use.names = TRUE)
    cand[, `:=`(state = st, level = tg, inside = a >= ar[1] - 1e-9 & a <= ar[2] + 1e-9 & b >= br[1] - 1e-9 & b <= br[2] + 1e-9)]
    sol[[paste(st, tg)]] <- cand
  }
}
surf <- rbindlist(surf); sol <- rbindlist(sol)[, `:=`(a = round(a, 3), b = round(b, 3))]
fwrite(surf, file.path(O, "fit_joint_surface_20261007.csv")); fwrite(sol, file.path(O, "fit_joint_solutions_20261007.csv"))
print(surf); print(sol[inside == TRUE][order(state, level, path, b)])
# Step 3
ctl <- res[(state == "MI") | (state %in% c("NH","VT") & a == 2 & b == 2), .(state, run, ratio)]
ctl <- merge(ctl, rep0[run %in% c("smoke_20261007_d10_anchored","smoke_20261007_d10_anch_bmx2.0_anpp2.0") &
                         ((state == "MI") | (state %in% c("NH","VT") & grepl("anpp2.0", run))), .(state, ref_ratio = ratio)], by = "state")
ctl[, diff := round(ratio - ref_ratio, 4)]; fwrite(ctl, file.path(O, "fit_joint_controls_20261007.csv")); print(ctl)
cat("FLAGS:", res[G1 == FALSE | G2_flag == TRUE, paste(state, run)], "\n")
