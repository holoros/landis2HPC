## s43 Track B: pseudo-age inventories from TreeMap 2020 pixel biomass (DRYBIO_L by raster Value, pixel counts by state).
## Pseudo age = inverse of the net-increment driver curve B(t) at pixel biomass, capped at age(0.99 B*) (or at the type cap
## where s42 held the curve at its cap). Reports share of area/stock above B*, capped, stock removed by capping, ages > 200,
## stratum-mean vs class-split growth (stress alt 2, curvature bias), ME stratum-summary (TM.2020.sum) vs pixel, 50 yr paths.
## usage: Rscript 04_pseudoage.R FITDIR PXDIR OUTDIR  (aggregates only written to OUTDIR)
suppressMessages({library(data.table); library(foreign)})
set.seed(20261019)
a <- commandArgs(TRUE); FD <- a[1]; PX <- a[2]; OD <- a[3]; dir.create(OD, showWarnings = FALSE, recursive = TRUE)
VATF <- "/fs/scratch/PUOM0008/crsfaaron/TREEMAP_restore/TM2020/TreeMap2020_CONUS.tif.vat.dbf"
SUMF <- "/users/PUOM0008/crsfaaron/TREEMAP/TM.2020.sum.csv"
for (f in c(VATF, SUMF, file.path(FD, "tb_params_allplots_DATA.csv"), file.path(FD, "tb_curves_0_300_DATA.csv"))) cat("md5", tools::md5sum(f), f, "\n")
TA2MGHA <- 0.90718474 / 0.40468564
VAT <- as.data.table(read.dbf(VATF, as.is = TRUE))[, .(Value = as.integer(Value), FORTYPCD = as.integer(FORTYPCD), B = as.numeric(DRYBIO_L) * TA2MGHA)]
FTM <- list(
  NH = c(`100` = "WRPH", `120` = "SF", `160` = "WRPH", `400` = "OAK", `500` = "OAK", `700` = "MBB", `800` = "MBB", `900` = "AB"),
  VT = c(`100` = "WRPH", `120` = "SF", `380` = "SF", `400` = "OAK", `500` = "OAK", `700` = "MBB", `800` = "MBB", `900` = "AB"),
  MI = c(`100` = "WRPH", `120` = "SF", `200` = "SF", `260` = "SF", `380` = "WRPH", `400` = "OAK", `500` = "OAK", `700` = "EAC", `800` = "MBB", `900` = "AB"),
  WI = c(`100` = "WRPH", `120` = "SF", `260` = "SF", `380` = "WRPH", `400` = "OAK", `500` = "OAK", `700` = "EAC", `800` = "MBB", `900` = "AB"),
  MN = c(`100` = "WRPH", `120` = "SF", `380` = "WRPH", `400` = "OAK", `500` = "OAK", `700` = "EAC", `800` = "MBB", `900` = "AB"),
  ME = c(`100` = "WRPH", `120` = "SF", `160` = "WRPH", `380` = "SF", `400` = "OAK", `500` = "OAK", `700` = "EAC", `800` = "MBB", `900` = "AB"))
P <- fread(file.path(FD, "tb_params_allplots_DATA.csv"))[ok == TRUE, .(st, ftg, unit, a, b, c, Bstar, age99)]
CV <- fread(file.path(FD, "tb_curves_0_300_DATA.csv"))
HOLD <- CV[held_at_cap == TRUE, .(cap = cap_p99[1]), by = .(st, ftg)]
P <- merge(P, HOLD, by = c("st", "ftg"), all.x = TRUE)
Bt <- function(t, a, b, c) (a / c)^(1 / (1 - b)) * (-expm1(-(1 - b) * c * t))^(1 / (1 - b))
Btd <- function(t, a, b, c, cap) pmin(Bt(t, a, b, c), ifelse(is.na(cap), Inf, cap))
Binv <- function(B, Bs, b, c) -log1p(-(B / Bs)^(1 - b)) / ((1 - b) * c)
P[, Bmax_drv := pmin(0.99 * Bstar, ifelse(is.na(cap), Inf, cap))][, age_cap := Binv(Bmax_drv, Bstar, b, c)]
fwrite(P, file.path(OD, "tb_driver_caps_DATA.csv"))

ST <- c("ME", "NH", "VT", "MI", "WI", "MN"); RES <- list(); AGE <- list(); TRJ <- list(); COV <- list()
for (S in ST) {
  cn <- fread(file.path(PX, paste0("tm2020_counts_", S, ".csv")))
  X <- merge(cn, VAT, by = "Value", all.x = TRUE)
  X[, area := count * 900 / 1e4][, grp := FTM[[S]][as.character(FORTYPCD %/% 10 * 10)]]
  COV[[S]] <- X[, .(st = S, area_ha = sum(area), share_mapped_group = sum(area[!is.na(grp)]) / sum(area),
                    share_no_vat = sum(area[is.na(B)]) / sum(area), share_nonstocked_999 = sum(area[FORTYPCD == 999], na.rm = TRUE) / sum(area))]
  X <- X[!is.na(grp) & !is.na(B)]
  X <- merge(X, P[st == S], by.x = "grp", by.y = "ftg")
  X[, capped := B >= Bmax_drv][, above_Bstar := B > Bstar]
  X[, age := ifelse(capped, age_cap, Binv(pmax(B, 0), Bstar, b, c))]
  X[, B0 := ifelse(capped, Bmax_drv, B)]
  X[, g10 := Btd(age + 10, a, b, c, cap) - Btd(age, a, b, c, cap)]
  RES[[S]] <- X[, { am <- Binv(min(weighted.mean(B, area), Bmax_drv[1] * 0.999999), Bstar[1], b[1], c[1])
    .(area_ha = sum(area), area_share_of_state = sum(area) / COV[[S]]$area_ha, stock_px_Tg = sum(B * area) / 1e6, meanB = weighted.mean(B, area),
      Bstar = Bstar[1], Bmax_drv = Bmax_drv[1], age_cap = age_cap[1],
      share_area_above_Bstar = sum(area[above_Bstar]) / sum(area), share_area_capped = sum(area[capped]) / sum(area),
      share_stock_above_Bstar = sum((B * area)[above_Bstar]) / sum(B * area),
      stock_removed_Tg = sum(((B - B0) * area)[capped]) / 1e6, stock_removed_pct = 100 * sum(((B - B0) * area)[capped]) / sum(B * area),
      share_area_age_gt200 = sum(area[age > 200]) / sum(area), age_mean = weighted.mean(age, area),
      g10_class_split = weighted.mean(g10, area), g10_stratum_mean = Btd(am + 10, a[1], b[1], c[1], cap[1]) - Btd(am, a[1], b[1], c[1], cap[1]))
  }, by = grp][, st := S]
  AGE[[S]] <- X[, .(area_ha = sum(area), meanB = weighted.mean(B, area)), by = .(grp, age_int = pmin(pmax(round(age), 1), 999))][, st := S]
  TRJ[[S]] <- X[, .(t = 0:50, B = sapply(0:50, function(t) weighted.mean(Btd(age + t, a, b, c, cap), area))), by = grp][, st := S]
}
R <- rbindlist(RES); R[, curvature_ratio_mean_over_split := g10_stratum_mean / g10_class_split]
setorder(R, st, grp); fwrite(R, file.path(OD, "tb_pseudoage_strata_DATA.csv"))
ST_T <- R[, .(area_ha = sum(area_ha), stock_px_Tg = sum(stock_px_Tg), share_area_above_Bstar = sum(share_area_above_Bstar * area_ha) / sum(area_ha),
  share_area_capped = sum(share_area_capped * area_ha) / sum(area_ha), stock_removed_Tg = sum(stock_removed_Tg),
  share_area_age_gt200 = sum(share_area_age_gt200 * area_ha) / sum(area_ha),
  g10_split = sum(g10_class_split * area_ha) / sum(area_ha), g10_mean = sum(g10_stratum_mean * area_ha) / sum(area_ha)), by = st]
ST_T[, stock_removed_pct := 100 * stock_removed_Tg / stock_px_Tg][, curvature_ratio := g10_mean / g10_split]
ST_T <- merge(ST_T, rbindlist(COV), by = "st", suffixes = c("_mapped", "_state"))
fwrite(ST_T, file.path(OD, "tb_pseudoage_state_DATA.csv"))
A <- rbindlist(AGE); fwrite(A, file.path(OD, "tb_pseudoage_age_area_DATA.csv"))
TR <- rbindlist(TRJ)
MON <- TR[, .(monotone_50yr = all(diff(B) >= -1e-9), B_t0 = B[1], B_t50 = B[51]), by = .(st, grp)]
fwrite(TR, file.path(OD, "tb_trajectory_50yr_DATA.csv")); fwrite(MON, file.path(OD, "tb_trajectory_50yr_monotone_DATA.csv"))

## ME: TM.2020.sum stratum summary (ECOL3 x FORTYPCD x StdAge.5 mean AGB) vs pixel class split, by group
SM <- fread(SUMF); setnames(SM, c("ECOL3", "FORTYPCD", "StdAge5", "N", "AGB", "HA"))
SM[, grp := FTM$ME[as.character(FORTYPCD %/% 10 * 10)]]; SM <- merge(SM[!is.na(grp) & HA > 0], P[st == "ME"], by.x = "grp", by.y = "ftg")
SM[, capped := AGB >= Bmax_drv][, age := ifelse(capped, age_cap, Binv(pmax(AGB, 0), Bstar, b, c))][, g10 := Btd(age + 10, a, b, c, cap) - Btd(age, a, b, c, cap)]
MEc <- SM[, .(sum_area_ha = sum(HA), sum_meanAGB = weighted.mean(AGB, HA), sum_share_capped = sum(HA[capped]) / sum(HA), g10_summary_rows = weighted.mean(g10, HA)), by = grp]
MEc <- merge(MEc, R[st == "ME", .(grp, px_meanB = meanB, px_share_capped = share_area_capped, g10_pixel_split = g10_class_split, g10_stratum_mean)], by = "grp")
MEc[, curvature_ratio_summary_over_pixel := g10_summary_rows / g10_pixel_split]
fwrite(MEc, file.path(OD, "tb_ME_summary_vs_pixel_DATA.csv"))
print(ST_T[, .(st, share_mapped_group, area_ha_mapped = round(area_ha_mapped), stock_px_Tg = round(stock_px_Tg, 1), cap = round(share_area_capped, 3), above = round(share_area_above_Bstar, 3), rem = round(stock_removed_pct, 2), gt200 = round(share_area_age_gt200, 3), curv = round(curvature_ratio, 3))])
print(MON[monotone_50yr == FALSE]); print(MEc[, .(grp, g10_summary_rows, g10_pixel_split, curvature_ratio_summary_over_pixel)])
cat("done 04\n")
