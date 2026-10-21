# Session 40, 15 Oct 2026. Scores the WI second pass grid (lakestates_pesc2_20261015.sh); otherwise identical to pesc_score_20261015.R, with the
# behavioural gate scorer below (its header follows; the D1 and surface steps are removed, pe added).
# Scores the behavioural gate grid (fit_behav_20261015.sh, grid pesc2_grid_20261015.csv).
# Behavioural gate (Aaron, 15 Oct, option 1): production, mortality net of recruitment and net growth each within 15 pct
# of FIA (snum 1311, 335, 311), and LANDIS year 5 ANPP in stands above 200 Mg ha-1 between 0.8 and 1.25 of FIA plot gross
# growth in the same biomass classes (FIA bins from gates/behav_bins_20261015.csv).
# Step 0, REPRODUCTION GATE: recompute anpp5_Tg and t10_Tg for four known runs and match
#   gates/prodmort_runs_20261015.csv to 1e-6 Tg (NH and VT fit_20261007_d10_a2.5_b3, WI confirm, MI anchored); and
#   recompute ratio_high for NH fit_20261007_d10_a2.5_b3 against gates/behav_score_20261015.csv to 1e-9. Else exit 2.
# Step 1, D1: NH and VT fit_20261015_d10_a2.5_b3 must equal fit_20261007_d10_a2.5_b3 (same inputs, deterministic).
# Step 2, score every new run, rank old and new together by loss = sum of squared log ratios of the four quantities.
# Step 3, per state, surfaces (quantity ~ a * b) on the new grid only; the best point on a 0.05 mesh INSIDE the new grid
#   rectangle is reported as an interpolation that needs a confirmation run. Never extrapolated.
suppressMessages({library(terra); library(data.table)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"; O <- file.path(D, "gates"); TAG <- "20261015f"
fia <- fread(file.path(O, "grm_realism_fourstate_20261006.csv"))[, .(state, fia_gross_growth, fia_mortality, fia_net_growth, fia_ng_lo, fia_ng_hi)]
fb <- unique(fread(file.path(O, "behav_bins_20261015.csv"))[, .(state, bin, plots, fia_gg, plot_share)])
pm <- fread(file.path(O, "prodmort_runs_20261015.csv")); bsc <- fread(file.path(O, "behav_score_20261015.csv"))
grid <- fread(file.path(D, "scripts_20261001/pesc2_grid_20261015.csv"), colClasses = "character")
brk <- c(0, 50, 100, 150, 200, 250, 300, Inf); hi <- c("[200,250)", "[250,300)", "[300,Inf)")
rv <- function(R, f) values(rast(file.path(R, f)))[, 1]
score <- function(st, rn) {
  R <- file.path(D, st, "runs", rn)
  if (!file.exists(file.path(R, "Landis-log.txt")) || !any(grepl("Model run is complete", readLines(file.path(R, "Landis-log.txt"), warn = FALSE))))
    return(data.table(state = st, run = rn, complete = FALSE))
  cell <- fread(file.path(R, "build_summary.csv"))$cell_m; k <- cell^2 / 1e12
  b0 <- rv(R, "output/biomass/biomass-TotalBiomass-0.tif"); b5 <- rv(R, "output/biomass/biomass-TotalBiomass-5.tif")
  b10 <- rv(R, "output/biomass/biomass-TotalBiomass-10.tif")
  a5 <- rv(R, "biomass-succession\\biomass-anpp-5.tif"); a10 <- rv(R, "biomass-succession\\biomass-anpp-10.tif")
  t0 <- sum(b0, na.rm = TRUE) * k; t5 <- sum(b5, na.rm = TRUE) * k; t10 <- sum(b10, na.rm = TRUE) * k
  an5 <- sum(a5, na.rm = TRUE) * k; an10 <- sum(a10, na.rm = TRUE) * k
  ok <- !is.na(b5) & b5 > 0 & !is.na(a5)
  x <- data.table(bin = cut(b5[ok] / 100, brk, right = FALSE), anpp = a5[ok])[, .(mean_anpp = mean(anpp)), by = bin]
  x <- merge(x, fb[state == st], by = "bin")[plots >= 20]
  rm(b0, b5, b10, a5, a10); gc()
  data.table(state = st, run = rn, complete = TRUE, t0_Tg = t0, t10_Tg = t10, anpp5_Tg = an5, anpp_mean = (an5 + an10) / 2,
             net_0_10 = (t10 - t0) / 10, mort_5_10 = (an5 + an10) / 2 - (t10 - t5) / 5,
             ratio_high = x[bin %in% hi, mean(mean_anpp / fia_gg)], rmse_gpm2 = x[, sqrt(weighted.mean((mean_anpp - fia_gg)^2, plot_share))])
}
# Step 0
kr <- data.table(state = c("NH", "VT", "WI", "MI"), run = c("fit_20261007_d10_a2.5_b3", "fit_20261007_d10_a2.5_b3", "fit_20261007_d10_confirm_a1.20_b1.75", "smoke_20261007_d10_anchored"))
r0 <- rbindlist(Map(score, kr$state, kr$run))
r0 <- merge(r0, pm[, .(state, run, k_anpp5 = anpp5_Tg, k_t10 = t10_Tg)], by = c("state", "run"))
r0 <- merge(r0, bsc[, .(state, run, k_high = ratio_high)], by = c("state", "run"), all.x = TRUE)
r0[, ok := abs(anpp5_Tg - k_anpp5) < 1e-6 & abs(t10_Tg - k_t10) < 1e-6 & (is.na(k_high) | abs(ratio_high - k_high) < 1e-9)]
print(r0[, .(state, run, anpp5_Tg, k_anpp5, t10_Tg, k_t10, ratio_high, k_high, ok)])
if (!all(r0$ok)) { cat("REPRODUCTION GATE FAILED\n"); quit(status = 2) }
cat("REPRODUCTION GATE PASS\n")
# Steps 1 and 2
new <- rbindlist(Map(score, grid$state, grid$run), fill = TRUE)
new <- merge(new, grid[, .(state, run, a = as.numeric(anpp), b = as.numeric(bmx), pe = as.numeric(pe))], by = c("state", "run"))
cat("complete:", new[complete == TRUE, .N], "of", nrow(grid), "\n")
old <- merge(pm[state %in% c("MI","WI") & (grepl("^fit_20261007_d10_a", run) | run == "fit_20261007_d10_confirm_a1.20_b1.75" | run == "smoke_20261007_d10_anchored"),
                .(state, run, a = as.numeric(anpp_mult), b = as.numeric(bmx_mult), anpp_mean, mort_5_10, net_0_10)],
             bsc[, .(state, run, ratio_high, rmse_gpm2)], by = c("state", "run"))
old[run == "smoke_20261007_d10_anchored", `:=`(a = 1, b = 1)][run == "fit_20261007_d10_confirm_a1.20_b1.75", `:=`(a = 1.2, b = 1.75)]
all <- rbind(old[, `:=`(src = "s38", pe = 1)], new[complete == TRUE, .(state, run, a, b, pe, anpp_mean, mort_5_10, net_0_10, ratio_high, rmse_gpm2)][, src := "s40"], use.names = TRUE)
all <- merge(all, fia, by = "state")
all[, `:=`(r_prod = anpp_mean / fia_gross_growth, r_mort = mort_5_10 / fia_mortality, r_net = net_0_10 / fia_net_growth)]
all[, `:=`(g_prod = abs(r_prod - 1) <= 0.15, g_mort = abs(r_mort - 1) <= 0.15, g_net = abs(r_net - 1) <= 0.15,
           g_high = ratio_high >= 0.8 & ratio_high <= 1.25)]
all[, pass := g_prod & g_mort & g_net & g_high]
all[, loss := log(pmax(r_prod, 1e-3))^2 + log(pmax(r_mort, 1e-3))^2 + log(pmax(r_net, 1e-3))^2 + log(pmax(ratio_high, 1e-3))^2]
fwrite(all, file.path(O, paste0("behav_gate_runs_", TAG, ".csv")))
print(all[order(state, loss), .(state, src, a, b, pe, r_prod = round(r_prod, 3), r_mort = round(r_mort, 3), r_net = round(r_net, 3),
        high = round(ratio_high, 3), rmse = round(rmse_gpm2), pass, loss = round(loss, 4))])
cat("PESC_DONE\n")
