# Session 39, 15 Oct 2026. Behavioural check for the NH and VT diagnosis: does LANDIS reproduce how FIA gross growth
# varies with stand biomass? Absolute biomass classes (Mg ha-1) so the comparison does not depend on any multiplier.
# LANDIS: per cell, live biomass at t5 (TotalBiomass-5) and ANPP at t5 (biomass-succession\biomass-anpp-5.tif), both
# output maps in the same frame, so no flip is needed. Mortality net of recruitment per cell over years 5 to 10:
# mean(ANPP5, ANPP10) - (B10 - B5) / 5. FIA (public DataMart, same pairs and definitions as fia_growth_ceiling_20261015.R):
# gross growth against midpoint plot biomass (B1 + B2) / 2. Plot mortality failed its sanity gate in that script
# (about 1.5 times EVALIDator per area), so FIA mortality is reported for shape only.
# Gate V0: for every scored run, the sum of cell ANPP equals anpp5_Tg in gates/prodmort_runs_20261015.csv within 1e-6 Tg.
suppressMessages({library(terra); library(data.table)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"; F <- "/fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006"
O <- file.path(D, "gates"); TAG <- "20261015"; K <- 0.112085
brk <- c(0, 50, 100, 150, 200, 250, 300, Inf)
pm <- fread(file.path(O, "prodmort_runs_20261015.csv"))
sel <- rbind(pm[state %in% c("NH", "VT") & (run == "smoke_20261007_d10_anchored" | grepl("^fit_", run))],
             pm[state == "WI" & run %in% c("smoke_20261007_d10_anchored", "fit_20261007_d10_confirm_a1.20_b1.75")],
             pm[state == "MI" & run == "smoke_20261007_d10_anchored"])
rv <- function(R, f) values(rast(file.path(R, f)))[, 1]
lb <- list(); v0 <- list()
for (i in seq_len(nrow(sel))) {
  st <- sel$state[i]; rn <- sel$run[i]; R <- file.path(D, st, "runs", rn); cell <- fread(file.path(R, "build_summary.csv"))$cell_m
  b5 <- rv(R, "output/biomass/biomass-TotalBiomass-5.tif"); b10 <- rv(R, "output/biomass/biomass-TotalBiomass-10.tif")
  a5 <- rv(R, "biomass-succession\\biomass-anpp-5.tif"); a10 <- rv(R, "biomass-succession\\biomass-anpp-10.tif")
  v0[[i]] <- data.table(state = st, run = rn, sum_anpp5 = sum(a5, na.rm = TRUE) * cell^2 / 1e12, ref = sel$anpp5_Tg[i])
  ok <- !is.na(b5) & b5 > 0 & !is.na(a5)
  x <- data.table(B = b5[ok] / 100, anpp = a5[ok], m = (a5[ok] + a10[ok]) / 2 - (b10[ok] - b5[ok]) / 5)
  x[, bin := cut(B, brk, right = FALSE)]
  lb[[i]] <- x[, .(cells = .N, mean_anpp = mean(anpp), mean_mort_net = mean(m)), by = bin][, `:=`(area_share = cells / sum(cells), state = st, run = rn)]
  rm(x, b5, b10, a5, a10); gc()
}
v0 <- rbindlist(v0)[, pass := abs(sum_anpp5 - ref) < 1e-6]; print(v0)
if (!all(v0$pass)) { cat("V0 FAILED\n"); quit(status = 2) }
lb <- rbindlist(lb)
fb <- list()
for (ST in c("NH", "VT", "WI", "MI")) {
  R <- file.path(D, ST, "runs", "smoke_20261007_d10_anchored"); se <- fread(file.path(R, "SppEcoregionData_fia.csv"))
  pl <- fread(file.path(F, paste0(ST, "_PLOT.csv")), select = c("CN", "PREV_PLT_CN", "INVYR", "REMPER", "LAT", "LON"))[INVYR >= 2000 & INVYR <= 2024 & !is.na(LAT)]
  er <- rast(file.path(D, ST, "inputs", "ecoregions_20260929.tif"))
  v <- project(vect(pl, geom = c("LON", "LAT"), crs = "EPSG:4269"), crs(er))
  pl[, eco := as.integer(extract(er, v)[, 2])]; pl[, `:=`(LAT = NULL, LON = NULL)]; rm(v)
  pl <- pl[eco %in% unique(se$EcoregionName)]
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
  fb[[ST]] <- g[, .(plots = .N, fia_gg = mean(gg), fia_mort_shape_only = mean(mo)), by = bin][, `:=`(plot_share = plots / sum(plots), state = ST)]
  rm(tr, t1, t2, live2, g); gc()
}
fb <- rbindlist(fb)
cmp <- merge(lb, fb, by = c("state", "bin"), all.x = TRUE)[, ratio := mean_anpp / fia_gg]
sc <- cmp[!is.na(fia_gg) & plots >= 20, .(bins = .N, wmean_ratio = weighted.mean(ratio, plot_share),
          ratio_low = ratio[bin == "[50,100)"], ratio_high = mean(ratio[bin %in% c("[200,250)", "[250,300)", "[300,Inf)")]),
          rmse_gpm2 = sqrt(weighted.mean((mean_anpp - fia_gg)^2, plot_share))), by = .(state, run)]
sc <- merge(sc, pm[, .(state, run, anpp_mult, bmx_mult, r_prod, r_mort, r_net)], by = c("state", "run"))
fwrite(cmp, file.path(O, paste0("behav_bins_", TAG, ".csv"))); fwrite(sc, file.path(O, paste0("behav_score_", TAG, ".csv")))
print(fb); print(cmp[run == "smoke_20261007_d10_anchored", .(state, bin, area_share = round(area_share, 3), plot_share = round(plot_share, 3),
      mean_anpp = round(mean_anpp), fia_gg = round(fia_gg), mort_net = round(mean_mort_net), fia_mort = round(fia_mort_shape_only))])
print(sc[order(state, rmse_gpm2)])
cat("BEHAV_DONE\n")
