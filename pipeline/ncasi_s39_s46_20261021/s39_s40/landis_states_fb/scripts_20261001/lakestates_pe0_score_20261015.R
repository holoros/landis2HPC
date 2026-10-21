# Session 40 (15 Oct 2026, autopilot). Scores the Lake States ProbEstablish = 0 diagnosis (lakestates_pe0_20261015.sh)
# with the score function and reproduction gate of behav_gate_score_20261015.R. With ProbEstablish 0 no cohorts are added,
# so production minus biomass change is true mortality M0. With ProbEstablish > 0 the same balance is M - R (mortality net
# of recruitment R). R is estimated as M0 - (M - R) from the paired runs, which assumes mortality is similar in the two
# runs over 10 years; the pairs share inputs except ProbEstablish.
suppressMessages({library(terra); library(data.table)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"; O <- file.path(D, "gates"); TAG <- "20261015d"
fia <- fread(file.path(O, "grm_realism_fourstate_20261006.csv"))[, .(state, fia_gross_growth, fia_mortality, fia_net_growth, fia_ng_lo, fia_ng_hi)]
fb <- unique(fread(file.path(O, "behav_bins_20261015.csv"))[, .(state, bin, plots, fia_gg, plot_share)])
pm <- fread(file.path(O, "prodmort_runs_20261015.csv")); bsc <- fread(file.path(O, "behav_score_20261015.csv"))
grid <- fread(file.path(D, "scripts_20261001/fit_grid_20261015.csv"), colClasses = "character")
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
# Pairs
pr <- data.table(state = c("MI","MI","WI","WI","NH"), a = c(1,1,1,1,1), b = c(1,2,1,2,1),
  run_pe = c("smoke_20261007_d10_anchored","fit_20261015_d10_a1_b2","smoke_20261007_d10_anchored","fit_20261007_d10_a1_b2","smoke_20261007_d10_anchored"),
  run_pe0 = c("pe0_20261015_d10_a1_b1","pe0_20261015_d10_a1_b2","pe0_20261015_d10_a1_b1","pe0_20261015_d10_a1_b2","pe0_20261015_d10_a1_b1"))
res <- rbindlist(lapply(seq_len(nrow(pr)), function(k) {
  p <- score(pr$state[k], pr$run_pe[k]); q <- score(pr$state[k], pr$run_pe0[k])
  data.table(state = pr$state[k], a = pr$a[k], b = pr$b[k], prod_pe = p$anpp_mean, prod_pe0 = q$anpp_mean,
             net_pe = p$net_0_10, net_pe0 = q$net_0_10, balmort_pe = p$mort_5_10, mort_pe0 = q$mort_5_10,
             high_pe = p$ratio_high, high_pe0 = q$ratio_high)
}))
res <- merge(res, fia, by = "state")
res[, `:=`(recruit_est = mort_pe0 - balmort_pe, r_prod_pe0 = prod_pe0 / fia_gross_growth, r_mort_pe0 = mort_pe0 / fia_mortality,
           r_net_pe0 = net_pe0 / fia_net_growth, r_net_pe = net_pe / fia_net_growth)]
fwrite(res, file.path(O, paste0("lakestates_pe0_", TAG, ".csv")))
print(res[, .(state, a, b, prod_pe = round(prod_pe, 2), prod_pe0 = round(prod_pe0, 2), fia_gg = fia_gross_growth, net_pe = round(net_pe, 2), net_pe0 = round(net_pe0, 2),
              fia_net = fia_net_growth, balmort_pe = round(balmort_pe, 2), mort_pe0 = round(mort_pe0, 2), fia_m = fia_mortality, recruit_est = round(recruit_est, 2),
              high_pe = round(high_pe, 2), high_pe0 = round(high_pe0, 2))])
cat("PE0_DONE\n")
