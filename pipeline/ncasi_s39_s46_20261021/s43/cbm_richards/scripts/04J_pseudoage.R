## s43 Track J: pseudo-age inventories from TreeMap 2020 pixel biomass, as 04b_pseudoage.R (md5 5e9cccaa...) did, for the
## Richards driver variants (A = p90, p95, p99) and, for the area weighting only, re-derived for the s43 free-A curves (04b formulas).
## Pseudo age = inverse of the driver curve at pixel biomass, capped at age(0.99 A); ages floored at 0. Also writes age x area by the
## libcbm forest type classifier (FT code = FORTYPCD %/% 10 * 10), which the round trip area weighting needs.
## usage: Rscript 04J_pseudoage.R OUTROOT PXDIR S43FITDIR
suppressMessages({library(data.table); library(foreign)})
set.seed(20261019)
a <- commandArgs(TRUE); OR <- a[1]; PX <- a[2]; S43 <- a[3]
VATF <- "/fs/scratch/PUOM0008/crsfaaron/TREEMAP_restore/TM2020/TreeMap2020_CONUS.tif.vat.dbf"
for (f in c(VATF, file.path(S43, "tb_params_allplots_DATA.csv"), file.path(S43, "tb_curves_0_300_DATA.csv"))) cat("md5", tools::md5sum(f), f, "\n")
TA2MGHA <- 0.90718474 / 0.40468564
VAT <- as.data.table(read.dbf(VATF, as.is = TRUE))[, .(Value = as.integer(Value), FORTYPCD = as.integer(FORTYPCD), B = as.numeric(DRYBIO_L) * TA2MGHA)]
FTM <- list(
  NH = c(`100` = "WRPH", `120` = "SF", `160` = "WRPH", `400` = "OAK", `500` = "OAK", `700` = "MBB", `800` = "MBB", `900` = "AB"),
  VT = c(`100` = "WRPH", `120` = "SF", `380` = "SF", `400` = "OAK", `500` = "OAK", `700` = "MBB", `800` = "MBB", `900` = "AB"),
  MI = c(`100` = "WRPH", `120` = "SF", `200` = "SF", `260` = "SF", `380` = "WRPH", `400` = "OAK", `500` = "OAK", `700` = "EAC", `800` = "MBB", `900` = "AB"),
  WI = c(`100` = "WRPH", `120` = "SF", `260` = "SF", `380` = "WRPH", `400` = "OAK", `500` = "OAK", `700` = "EAC", `800` = "MBB", `900` = "AB"),
  MN = c(`100` = "WRPH", `120` = "SF", `380` = "WRPH", `400` = "OAK", `500` = "OAK", `700` = "EAC", `800` = "MBB", `900` = "AB"),
  ME = c(`100` = "WRPH", `120` = "SF", `160` = "WRPH", `380` = "SF", `400` = "OAK", `500` = "OAK", `700` = "EAC", `800` = "MBB", `900` = "AB"))
ST <- c("ME", "NH", "VT", "MI", "WI", "MN")
PXD <- list(); COV <- list()
for (S in ST) {
  cn <- fread(file.path(PX, paste0("tm2020_counts_", S, ".csv")))
  X <- merge(cn, VAT, by = "Value", all.x = TRUE)
  X[, area := count * 900 / 1e4][, grp := FTM[[S]][as.character(FORTYPCD %/% 10 * 10)]][, ft := paste0("FT", FORTYPCD %/% 10 * 10)]
  COV[[S]] <- X[, .(st = S, area_ha = sum(area), share_mapped_group = sum(area[!is.na(grp) & !is.na(B)]) / sum(area),
    share_FORTYPCD_510_529_unmapped = sum(area[FORTYPCD >= 510 & FORTYPCD < 530], na.rm = TRUE) / sum(area))]
  PXD[[S]] <- X[!is.na(grp) & !is.na(B), .(st = S, grp, ft, B, area)]
}
PXD <- rbindlist(PXD); COV <- rbindlist(COV)
fwrite(COV, file.path(OR, "tbJ_pixel_coverage_DATA.csv")); print(COV[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 4) else x)])

## Richards curve: B(t) = A (1 + K exp(-r th (t-5)))^(-1/th), K = (A/B0)^th - 1 ; inverse for 0<B<A
BtR <- function(t, r, th, A, B0) { K <- (A / B0)^th - 1; ifelse(t <= 0, 0, A * (1 + K * exp(-r * th * (t - 5)))^(-1 / th)) }
BinvR <- function(B, r, th, A, B0) { K <- (A / B0)^th - 1; pmax(5 + log(K / ((A / pmax(B, 1e-9))^th - 1)) / (r * th), 0) }
## s43 free-A curve (04b formulas)
Bt3 <- function(t, a, b, c) (a / c)^(1 / (1 - b)) * (-expm1(-(1 - b) * c * t))^(1 / (1 - b))
Binv3 <- function(B, Bs, b, c) -log1p(-(B / Bs)^(1 - b)) / ((1 - b) * c)

run_variant <- function(V) {
  if (V == "s43free") {
    P <- fread(file.path(S43, "tb_params_allplots_DATA.csv"))[ok == TRUE, .(st, ftg, a, b, c, Bstar)]
    HOLD <- fread(file.path(S43, "tb_curves_0_300_DATA.csv"))[held_at_cap == TRUE, .(cap = cap_p99[1]), by = .(st, ftg)]
    P <- merge(P, HOLD, by = c("st", "ftg"), all.x = TRUE)
    P[, Bmax_drv := pmin(0.99 * Bstar, ifelse(is.na(cap), Inf, cap))][, age_cap := Binv3(Bmax_drv, Bstar, b, c)][, Aref := Bstar]
    inv <- function(B, p) Binv3(pmax(B, 0), p$Bstar, p$b, p$c)
    bt <- function(t, p) pmin(Bt3(t, p$a, p$b, p$c), ifelse(is.na(p$cap), Inf, p$cap))
  } else {
    P <- fread(file.path(OR, paste0("fit_", V), "tb_params_allplots_DATA.csv"))[ok == TRUE, .(st, ftg, r, theta, A, B0)]
    P[, Bmax_drv := 0.99 * A][, age_cap := BinvR(Bmax_drv, r, theta, A, B0)][, Aref := A]
    inv <- function(B, p) BinvR(B, p$r, p$theta, p$A, p$B0)
    bt <- function(t, p) BtR(t, p$r, p$theta, p$A, p$B0)
  }
  OD <- file.path(OR, paste0("pseudo_", V)); dir.create(OD, showWarnings = FALSE)
  fwrite(P, file.path(OD, "tb_driver_caps_DATA.csv"))
  X <- merge(PXD, P, by.x = c("st", "grp"), by.y = c("st", "ftg"))
  X[, capped := B >= Bmax_drv][, above_A := B > Aref]
  X[, age := 0]
  for (k in seq_len(nrow(P))) { p <- P[k]; i <- X[, which(st == p$st & grp == p$ftg)]; X[i, age := ifelse(capped, p$age_cap, inv(B, p))] }
  X[, B0px := ifelse(capped, Bmax_drv, B)]
  RES <- X[, .(area_ha = sum(area), stock_px_Tg = sum(B * area) / 1e6, meanB = weighted.mean(B, area), Aref = Aref[1], age_cap = age_cap[1],
    share_area_above_A = sum(area[above_A]) / sum(area), share_area_capped = sum(area[capped]) / sum(area),
    stock_removed_pct = 100 * sum(((B - B0px) * area)[capped]) / sum(B * area), share_area_age_le20 = sum(area[age <= 20.5]) / sum(area),
    share_area_age_gt200 = sum(area[age > 200]) / sum(area), age_mean = weighted.mean(age, area)), by = .(st, grp)]
  RES[, variant := V]; setorder(RES, st, grp); fwrite(RES, file.path(OD, "tb_pseudoage_strata_DATA.csv"))
  AG <- X[, .(area_ha = sum(area), meanB = weighted.mean(B, area)), by = .(st, grp, age_int = pmin(pmax(round(age), 1), 999))]
  fwrite(AG, file.path(OD, "tb_pseudoage_age_area_DATA.csv"))
  AF <- X[, .(area_ha = sum(area)), by = .(st, ft, grp, age_int = pmin(pmax(round(age), 1), 999))]
  fwrite(AF, file.path(OD, "tb_pseudoage_age_area_by_ft_DATA.csv"))
  TR <- list()
  for (k in seq_len(nrow(P))) { p <- P[k]; x <- X[st == p$st & grp == p$ftg]; if (!nrow(x)) next
    TR[[k]] <- data.table(st = p$st, grp = p$ftg, t = 0:50, B = sapply(0:50, function(t) weighted.mean(bt(x$age + t, p), x$area))) }
  TR <- rbindlist(TR); MON <- TR[, .(monotone_50yr = all(diff(B) >= -1e-9), B_t0 = B[1], B_t50 = B[51]), by = .(st, grp)]
  fwrite(MON, file.path(OD, "tb_trajectory_50yr_monotone_DATA.csv"))
  ST_T <- RES[, .(area_ha = sum(area_ha), share_capped = sum(share_area_capped * area_ha) / sum(area_ha), share_above_A = sum(share_area_above_A * area_ha) / sum(area_ha),
    stock_removed_pct = sum(stock_removed_pct * stock_px_Tg) / sum(stock_px_Tg), share_age_le20 = sum(share_area_age_le20 * area_ha) / sum(area_ha),
    share_age_gt200 = sum(share_area_age_gt200 * area_ha) / sum(area_ha)), by = st][, variant := V]
  fwrite(ST_T, file.path(OD, "tb_pseudoage_state_DATA.csv"))
  cat(V, ": 50yr monotone", sum(MON$monotone_50yr), "/", nrow(MON), "\n"); print(ST_T[, lapply(.SD, function(x) if (is.numeric(x)) round(x, 3) else x)])
}
for (V in c("p90", "p95", "p99", "s43free")) run_variant(V)
cat("done 04J\n")
