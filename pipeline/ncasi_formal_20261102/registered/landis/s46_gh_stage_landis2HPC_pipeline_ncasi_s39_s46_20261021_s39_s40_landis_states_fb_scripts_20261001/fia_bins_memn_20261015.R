# Session 40 (15 Oct 2026, autopilot). FIA remeasured plot gross growth by stand biomass class for Maine and Minnesota,
# the two states missing from gates/behav_bins_20261015.csv. Same definitions as behav_bins_20261015.R: remeasured pairs
# with INVYR 2000 to 2024 at both visits, REMPER > 0, fully forested at both visits, live trees DIA >= 1, survivor growth
# plus ingrowth (RECONCILECD 1, 2) over REMPER, lb ac-1 x 0.112085 to g m-2, midpoint biomass class in Mg ha-1.
# Public DataMart only; fuzzed coordinates are used solely for the reproduction step's ecoregion filter and never written.
# Gate R0: with the LANDIS ecoregion filter, NH must reproduce every fia_gg and plot count in behav_bins_20261015.csv
#   (relative difference < 1e-9). Gate R1 (reported): NH without the filter, to show the filter's effect.
# ME and MN have no Cardinal ecoregion raster, so they are computed statewide (no filter), as R1 is for NH.
suppressMessages({library(terra); library(data.table)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"; F <- "/fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006"
O <- file.path(D, "gates"); K <- 0.112085; brk <- c(0, 50, 100, 150, 200, 250, 300, Inf)
bins <- function(ST, eco_filter) {
  pl <- fread(file.path(F, paste0(ST, "_PLOT.csv")), select = c("CN", "PREV_PLT_CN", "INVYR", "REMPER", "LAT", "LON"))[INVYR >= 2000 & INVYR <= 2024 & !is.na(LAT)]
  if (eco_filter) {
    se <- fread(file.path(D, ST, "runs", "smoke_20261007_d10_anchored", "SppEcoregionData_fia.csv"))
    er <- rast(file.path(D, ST, "inputs", "ecoregions_20260929.tif"))
    v <- project(vect(pl, geom = c("LON", "LAT"), crs = "EPSG:4269"), crs(er))
    pl[, eco := as.integer(extract(er, v)[, 2])]; rm(v)
    pl <- pl[eco %in% unique(se$EcoregionName)]
  }
  pl[, `:=`(LAT = NULL, LON = NULL)]
  cd <- fread(file.path(F, paste0(ST, "_COND.csv")), select = c("PLT_CN", "COND_STATUS_CD", "CONDPROP_UNADJ"))
  full <- cd[, .(fp = sum(CONDPROP_UNADJ[COND_STATUS_CD == 1], na.rm = TRUE)), by = PLT_CN][fp >= 0.99, PLT_CN]
  pr <- pl[!is.na(PREV_PLT_CN) & !is.na(REMPER) & REMPER > 0 & CN %in% full & PREV_PLT_CN %in% pl$CN & PREV_PLT_CN %in% full]
  tr <- fread(file.path(F, paste0(ST, "_TREE.csv")), select = c("CN", "PLT_CN", "PREV_TRE_CN", "STATUSCD", "DIA", "TPA_UNADJ", "DRYBIO_AG", "RECONCILECD"))
  tr <- tr[PLT_CN %in% c(pr$CN, pr$PREV_PLT_CN)]
  t1 <- tr[PLT_CN %in% pr$PREV_PLT_CN & STATUSCD == 1 & DIA >= 1 & !is.na(DRYBIO_AG) & !is.na(TPA_UNADJ), .(CN, b1 = DRYBIO_AG, tpa1 = TPA_UNADJ, PLT1 = PLT_CN)]
  B1 <- t1[, .(B1 = sum(b1 * tpa1)), by = PLT1]
  t2 <- merge(tr[PLT_CN %in% pr$CN], t1, by.x = "PREV_TRE_CN", by.y = "CN", all.x = TRUE)
  t2 <- merge(t2, pr[, .(PLT_CN = CN, PREV_PLT_CN, REMPER)], by = "PLT_CN")
  live2 <- t2[STATUSCD == 1 & DIA >= 1 & !is.na(DRYBIO_AG) & !is.na(TPA_UNADJ)]
  g <- live2[, .(surv = sum(((DRYBIO_AG - b1) * TPA_UNADJ)[!is.na(b1)]), ingr = sum((DRYBIO_AG * TPA_UNADJ)[is.na(b1) & RECONCILECD %in% c(1, 2)]),
                 B2 = sum(DRYBIO_AG * TPA_UNADJ), REMPER = REMPER[1], PREV_PLT_CN = PREV_PLT_CN[1]), by = PLT_CN]
  m <- t2[STATUSCD == 2 & !is.na(b1), .(mort = sum(b1 * tpa1)), by = PLT_CN]
  g <- merge(merge(g, m, by = "PLT_CN", all.x = TRUE), B1, by.x = "PREV_PLT_CN", by.y = "PLT1", all.x = TRUE)
  g[is.na(mort), mort := 0][is.na(B1), B1 := 0]
  g[, `:=`(gg = (surv + ingr) / REMPER * K, mo = mort / REMPER * K, Bmid = (B1 + B2) / 2 * K / 100)]
  g[, bin := cut(Bmid, brk, right = FALSE)]
  out <- g[, .(plots = .N, fia_gg = mean(gg), fia_mort_shape_only = mean(mo)), by = bin][, `:=`(plot_share = plots / sum(plots), state = ST, eco_filter = eco_filter)]
  rm(tr, t1, t2, live2, g); gc(); out
}
ref <- unique(fread(file.path(O, "behav_bins_20261015.csv"))[state == "NH", .(bin, plots_ref = plots, gg_ref = fia_gg)])
r0 <- merge(bins("NH", TRUE), ref, by = "bin")
r0[, ok := plots == plots_ref & abs(fia_gg / gg_ref - 1) < 1e-9]; print(r0[, .(bin, plots, plots_ref, fia_gg, gg_ref, ok)])
if (!all(r0$ok) || nrow(r0) != nrow(ref)) { cat("R0 FAILED\n"); quit(status = 2) }
cat("R0 PASS\n")
res <- rbind(bins("NH", FALSE), bins("ME", FALSE), bins("MN", FALSE))
fwrite(res, file.path(O, "fia_bins_memn_20261015.csv"))
print(res[order(state, bin), .(state, bin, plots, fia_gg = round(fia_gg, 1), plot_share = round(plot_share, 3))])
cat("BINS_DONE\n")
