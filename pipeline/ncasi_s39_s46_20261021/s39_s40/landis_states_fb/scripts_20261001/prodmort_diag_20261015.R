# Session 39, 15 Oct 2026. NH and VT path, option 1 (Aaron, 15 Oct): diagnose before refitting.
# Splits the 10 yr anchored smokes into gross production and mortality and sets them beside FIA gross growth
# (EVALIDator snum 1311) and mortality (snum 335) from gates/grm_realism_fourstate_20261006.csv, with MI as reference.
# Reads existing runs only; writes nothing into any run folder.
#
# Why no rerun: Biomass Succession already writes landscape ANPP in every run (Biomass-succession-log.csv,
# AvgAG_NPP per ecoregion, and the map "biomass-succession\biomass-anpp-<t>.tif", the backslash being part of the
# Linux file name). Biomass Succession has no landscape mortality output short of CalibrateMode (per cohort, per
# year, unusable at state scale), so mortality is taken from the mass balance M = ANPP - dB/dt over years 5 to 10,
# with ANPP the mean of the t5 and t10 annual values. That is a closure, not an independent measurement; it is
# reported as such.
#
# Step 0, REPRODUCTION GATE: t0 and t10 landscape totals from TotalBiomass maps (same function as
#   fit_joint_score_20261007.R) must equal gates/formal_anchored_smoke_20261007.csv to 1e-6 Tg for all four states,
#   and NH, VT smoke_20261007_d10_anch_bmx2.0_anpp2.0 must reproduce gates/anpp_probe_20261007.csv annual change.
#   Any failure: nothing new is written, exit 2.
# Step 1, gates per run: P1 map ANPP equals log ANPP (ActiveCount x AvgAG_NPP) within 1 pct (log is rounded to
#   whole g m-2); P2 log live biomass at t5 and t10 equals the map total within 0.1 pct.
# Step 2, production and mortality per run, Tg yr-1, and ratios to FIA gross growth and mortality.
# Step 3, formal anchored runs only, per cell at t0: the site ceiling as LANDIS applies it (largest BiomassMax among
#   species present in that cell's ecoregion), site saturation B/Bmax_site, biomass weighted ANPPmax, and realised
#   ANPP at t5 over that. Ecoregion per cell comes from the input ecoregions.tif; output maps are vertically flipped,
#   so gate F1 requires that, after flipping, every cell with biomass at t0 falls on an active ecoregion (>= 0.999)
#   and reports the unflipped share for contrast.
suppressMessages({library(terra); library(data.table)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"; O <- file.path(D, "gates"); TAG <- "20261015"
fia <- fread(file.path(O, "grm_realism_fourstate_20261006.csv"))[, .(state, stock_Tg, fia_gross_growth, fia_mortality, fia_net_growth)]
tg_map <- function(R, t, cell) sum(values(rast(file.path(R, sprintf("output/biomass/biomass-TotalBiomass-%d.tif", t))))[, 1], na.rm = TRUE) * cell^2 / 1e12
anpp_map <- function(R, t, cell) sum(values(rast(file.path(R, sprintf("biomass-succession\\biomass-anpp-%d.tif", t))))[, 1], na.rm = TRUE) * cell^2 / 1e12
spec_val <- function(R, key) {
  f <- file.path(R, "RUN_SPEC.txt"); if (!file.exists(f)) return(NA_character_)
  s <- readLines(f, warn = FALSE)[1]; m <- regmatches(s, regexpr(paste0(key, "=[^ ]+"), s))
  if (length(m)) sub(".*=", "", m) else NA_character_
}
score <- function(st, rn) {
  R <- file.path(D, st, "runs", rn); cell <- fread(file.path(R, "build_summary.csv"))$cell_m
  lg <- readLines(file.path(R, "Landis-log.txt"), warn = FALSE)
  if (!any(grepl("Model run is complete", lg))) return(data.table(state = st, run = rn, complete = FALSE))
  bl <- fread(file.path(R, "Biomass-succession-log.csv"), strip.white = TRUE)
  bl <- bl[!is.na(suppressWarnings(as.integer(EcoName)))]
  lgT <- function(col, t) bl[Time == t, sum(as.numeric(ActiveCount) * get(col))] * cell^2 / 1e12
  t0 <- tg_map(R, 0, cell); t5 <- tg_map(R, 5, cell); t10 <- tg_map(R, 10, cell)
  a5 <- anpp_map(R, 5, cell); a10 <- anpp_map(R, 10, cell); gc()
  a <- spec_val(R, "anpp"); b <- spec_val(R, "bmx"); if (is.na(b)) b <- spec_val(R, "bmx_mult")
  data.table(state = st, run = rn, complete = TRUE, anpp_mult = a, bmx_mult = b, t0_Tg = t0, t5_Tg = t5, t10_Tg = t10,
             anpp5_Tg = a5, anpp10_Tg = a10, anpp5_log = lgT("AvgAG_NPP", 5), anpp10_log = lgT("AvgAG_NPP", 10),
             live5_log = lgT("AvgLiveB", 5), live10_log = lgT("AvgLiveB", 10))
}
# Step 0
kf <- fread(file.path(O, "formal_anchored_smoke_20261007.csv"))[, .(state, run, k_t0 = t0_Tg, k_t10 = t10_Tg, k_annual = annual_Tg)]
kp <- fread(file.path(O, "anpp_probe_20261007.csv"))[run == "smoke_20261007_d10_anch_bmx2.0_anpp2.0", .(state, run, k_annual = annual_Tg)]
rep0 <- rbindlist(Map(score, c(kf$state, kp$state), c(kf$run, kp$run)), fill = TRUE)
rep0[, annual_Tg := (t10_Tg - t0_Tg) / 10]
rep0 <- merge(rep0, rbind(kf, kp, fill = TRUE), by = c("state", "run"))
rep0[, reproduced := abs(annual_Tg - k_annual) < 1e-6 & (is.na(k_t0) | (abs(t0_Tg - k_t0) < 1e-6 & abs(t10_Tg - k_t10) < 1e-6))]
print(rep0[, .(state, run, t0_Tg, k_t0, t10_Tg, k_t10, annual_Tg, k_annual, reproduced)])
if (!all(rep0$reproduced)) { cat("REPRODUCTION GATE FAILED; nothing new written\n"); quit(status = 2) }
cat("REPRODUCTION GATE PASS\n")
fwrite(rep0, file.path(O, paste0("prodmort_reproduce_", TAG, ".csv")))
# Steps 1 and 2: every anchored 10 yr run on initial_communities_20261006 (formal, probes, grid, WI confirmation)
runs <- rbindlist(lapply(c("NH","VT","WI","MI"), function(st) {
  r <- list.files(file.path(D, st, "runs"), pattern = "^(smoke_20261007_d10_anch|fit_20261007_d10_)")
  data.table(state = st, run = r)
}))
res <- rbindlist(Map(score, runs$state, runs$run), fill = TRUE)[complete == TRUE]
res[, `:=`(P1 = abs(anpp5_Tg / anpp5_log - 1) < 0.01 & abs(anpp10_Tg / anpp10_log - 1) < 0.01,
           P2 = abs(live5_log / t5_Tg - 1) < 0.001 & abs(live10_log / t10_Tg - 1) < 0.001)]
res[, `:=`(net_0_10 = (t10_Tg - t0_Tg) / 10, net_5_10 = (t10_Tg - t5_Tg) / 5, anpp_mean = (anpp5_Tg + anpp10_Tg) / 2)]
res[, mort_5_10 := anpp_mean - net_5_10]
res <- merge(res, fia, by = "state")
res[, `:=`(r_prod = anpp_mean / fia_gross_growth, r_mort = mort_5_10 / fia_mortality, r_net = net_0_10 / fia_net_growth,
           mort_pct_stock = 100 * mort_5_10 / t5_Tg, fia_mort_pct_stock = 100 * fia_mortality / stock_Tg,
           prod_pct_stock = 100 * anpp_mean / t5_Tg, fia_gg_pct_stock = 100 * fia_gross_growth / stock_Tg)]
fwrite(res, file.path(O, paste0("prodmort_runs_", TAG, ".csv")))
cat("P1 fails:", res[P1 == FALSE, .N], " P2 fails:", res[P2 == FALSE, .N], "\n")
print(res[order(state, run), .(state, run, a = anpp_mult, b = bmx_mult, anpp = round(anpp_mean, 2), fia_gg = fia_gross_growth,
          r_prod = round(r_prod, 3), mort = round(mort_5_10, 2), fia_m = fia_mortality, r_mort = round(r_mort, 3), r_net = round(r_net, 3), P1, P2)])
# Step 3: per cell saturation, formal anchored runs
sat <- list(); f1 <- list()
for (st in c("NH","VT","WI","MI")) {
  R <- file.path(D, st, "runs", "smoke_20261007_d10_anchored"); cell <- fread(file.path(R, "build_summary.csv"))$cell_m
  se <- fread(file.path(R, "SppEcoregionData_fia.csv"))[Year == 0, .(eco = as.integer(EcoregionName), sp = SpeciesCode, BMX = BiomassMax, AMX = ANPPmax)]
  ecor <- rast(file.path(R, "ecoregions.tif")); ev_raw <- values(ecor)[, 1]; ev_flip <- values(flip(ecor, "vertical"))[, 1]
  tr0 <- rast(file.path(R, "output/biomass/biomass-TotalBiomass-0.tif"))
  if (nrow(tr0) != nrow(ecor) || ncol(tr0) != ncol(ecor)) { cat("F1 FAIL dims", st, "\n"); next }
  tot0 <- values(tr0)[, 1]
  tot10 <- values(rast(file.path(R, "output/biomass/biomass-TotalBiomass-10.tif")))[, 1]
  an5 <- values(rast(file.path(R, "biomass-succession\\biomass-anpp-5.tif")))[, 1]
  ae <- unique(se$eco); has <- !is.na(tot0) & tot0 > 0
  f1[[st]] <- data.table(state = st, cells_with_B = sum(has), share_active_flipped = mean(ev_flip[has] %in% ae),
                         share_active_unflipped = mean(ev_raw[has] %in% ae))
  if (f1[[st]]$share_active_flipped < 0.999) { cat("F1 FAIL", st, "\n"); next }
  sps <- unique(se$sp); bmx_site <- rep(0, length(tot0)); wA <- rep(0, length(tot0)); bsum <- rep(0, length(tot0))
  for (s in sps) {
    f <- file.path(R, sprintf("output/biomass/biomass-%s-0.tif", s)); if (!file.exists(f)) next
    bs <- values(rast(f))[, 1]; bs[is.na(bs)] <- 0
    lk <- se[sp == s]; bm <- lk$BMX[match(ev_flip, lk$eco)]; am <- lk$AMX[match(ev_flip, lk$eco)]
    pres <- bs > 0 & !is.na(bm)
    bmx_site[pres] <- pmax(bmx_site[pres], bm[pres]); wA[pres] <- wA[pres] + bs[pres] * am[pres]; bsum[pres] <- bsum[pres] + bs[pres]
  }
  ok <- has & bmx_site > 0
  x <- data.table(eco = ev_flip[ok], B0 = tot0[ok], B10 = tot10[ok], anpp5 = an5[ok], bmx = bmx_site[ok], wA = wA[ok] / bsum[ok])
  x[, `:=`(sat = B0 / bmx, real = anpp5 / wA, dB = (B10 - B0) / 10)]
  x[, bin := cut(sat, c(0, 0.5, 0.8, 1, 1.2, Inf), right = FALSE)]
  s1 <- x[, .(cells = .N, B_share = sum(B0), mean_B0 = mean(B0), mean_anpp5 = mean(anpp5), mean_dB = mean(dB),
              mean_real = mean(real, na.rm = TRUE)), by = bin][order(bin)]
  s1[, B_share := B_share / sum(B_share)][, state := st]
  s2 <- x[, .(state = st, cells = .N, wmean_sat = weighted.mean(sat, B0), med_sat = median(sat), share_B_sat_ge1 = sum(B0[sat >= 1]) / sum(B0),
              mean_wANPPmax = mean(wA), mean_anpp5 = mean(anpp5), realisation = mean(anpp5) / mean(wA))]
  sat[[st]] <- list(s1, s2); rm(x, bs, bmx_site, wA, bsum); gc()
}
f1 <- rbindlist(f1); print(f1); fwrite(f1, file.path(O, paste0("prodmort_flipgate_", TAG, ".csv")))
bins <- rbindlist(lapply(sat, `[[`, 1)); summ <- rbindlist(lapply(sat, `[[`, 2))
fwrite(bins, file.path(O, paste0("prodmort_satbins_", TAG, ".csv"))); fwrite(summ, file.path(O, paste0("prodmort_satsummary_", TAG, ".csv")))
print(summ); print(bins)
cat("PRODMORT_DONE\n")
