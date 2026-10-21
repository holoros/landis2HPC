# Session 39, 15 Oct 2026. NH and VT diagnosis, second half: are ANPPmax and BiomassMax in the run copy tables
# realistic against what FIA plots actually grow and hold? Extends the logic of ceiling_check_fia_20261007.R
# (session 38, firebreather) in two ways: (1) gross growth from remeasured plots against ANPPmax, and (2) the ceiling
# compared at stand level, because Biomass Succession limits a cohort by BiomassMax of its species minus the biomass of
# the other cohorts on the site, so BiomassMax bounds total site biomass, not one species' share of a mixed plot.
#
# Runs on Cardinal because firebreather refused SSH on 15 Oct. Data are the PUBLIC FIA DataMart CSVs
# (fia_datamart_20261006), which carry only fuzzed public coordinates; these are used solely to look up the EPA L3
# ecoregion on the state's 270 m ecoregion raster and are never written. Only aggregates by state, ecoregion and
# species code are written.
#
# Definitions. Remeasured pairs: plot at t2 whose PREV_PLT_CN is a plot at t1, both INVYR 2000 to 2024, REMPER > 0,
# fully forested at both visits (forested CONDPROP_UNADJ sum >= 0.99). Live trees DIA >= 1 in. Units lb ac-1 to g m-2
# (x 0.112085). Survivor growth: t2 live trees whose PREV_TRE_CN is live at t1, (DRYBIO_AG2 - DRYBIO_AG1) x TPA_UNADJ2.
# Ingrowth: t2 live trees with RECONCILECD 1 or 2, DRYBIO_AG2 x TPA_UNADJ2. Gross growth = (survivor + ingrowth) /
# REMPER; growth on trees that died or were cut between visits is not included, so this is a lower bound on the
# EVALIDator definition. Mortality: t1 live trees with STATUSCD 2 at t2, DRYBIO_AG1 x TPA_UNADJ1 / REMPER.
# Dominant code: the LANDIS code holding >= 50 pct of t2 live AGB on the plot.
#
# Gate F0 (sanity, reported, not blocking): plot mean gross growth and mortality per m2 against EVALIDator snum 1311
# and 335 divided by the LANDIS active area (the area basis the anchoring used).
suppressMessages({library(terra); library(data.table)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"; F <- "/fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006"
O <- file.path(D, "gates"); TAG <- "20261015"; K <- 0.112085
fia <- fread(file.path(O, "grm_realism_fourstate_20261006.csv"))[, .(state, fia_gross_growth, fia_mortality)]
grid <- list(NH = list(a = c(1, 1.5, 2, 2.5, 3), b = c(1, 1.25, 1.5, 2, 2.5, 3)), VT = list(a = c(1, 1.5, 2, 2.5, 3), b = c(1, 1.25, 1.5, 2, 2.5, 3)),
             WI = list(a = c(1, 1.2), b = c(1, 1.75)), MI = list(a = 1, b = 1))
cells <- list(); sanity <- list(); satb <- list(); summ <- list()
for (ST in names(grid)) {
  R <- file.path(D, ST, "runs", "smoke_20261007_d10_anchored"); bs <- fread(file.path(R, "build_summary.csv"))
  se <- fread(file.path(R, "SppEcoregionData_fia.csv"))[Year == 0, .(eco = as.integer(EcoregionName), code = SpeciesCode, ANPPmax, BiomassMax)]
  env <- new.env(); sys.source(file.path(D, ST, "inputs", paste0("species_lookup_", ST, ".R")), env); lk <- env$SPECIES_LOOKUP
  pl <- fread(file.path(F, paste0(ST, "_PLOT.csv")), select = c("CN", "PREV_PLT_CN", "INVYR", "REMPER", "LAT", "LON"))
  pl <- pl[INVYR >= 2000 & INVYR <= 2024 & !is.na(LAT)]
  er <- rast(file.path(D, ST, "inputs", "ecoregions_20260929.tif"))
  v <- project(vect(pl, geom = c("LON", "LAT"), crs = "EPSG:4269"), crs(er))
  pl[, eco := as.integer(extract(er, v)[, 2])]; pl[, `:=`(LAT = NULL, LON = NULL)]; rm(v)
  pl <- pl[eco %in% unique(se$eco)]
  cd <- fread(file.path(F, paste0(ST, "_COND.csv")), select = c("PLT_CN", "COND_STATUS_CD", "CONDPROP_UNADJ"))
  full <- cd[, .(fp = sum(CONDPROP_UNADJ[COND_STATUS_CD == 1], na.rm = TRUE)), by = PLT_CN][fp >= 0.99, PLT_CN]
  pr <- pl[!is.na(PREV_PLT_CN) & !is.na(REMPER) & REMPER > 0 & CN %in% full & PREV_PLT_CN %in% pl$CN & PREV_PLT_CN %in% full]
  tr <- fread(file.path(F, paste0(ST, "_TREE.csv")), select = c("CN", "PLT_CN", "PREV_TRE_CN", "STATUSCD", "SPCD", "DIA", "TPA_UNADJ", "DRYBIO_AG", "RECONCILECD"))
  tr <- tr[PLT_CN %in% c(pr$CN, pr$PREV_PLT_CN)]; gc()
  tr[, code := lk$LANDIS[match(SPCD, lk$SPCD)]]
  t1 <- tr[PLT_CN %in% pr$PREV_PLT_CN & STATUSCD == 1 & DIA >= 1 & !is.na(DRYBIO_AG) & !is.na(TPA_UNADJ), .(CN, b1 = DRYBIO_AG, tpa1 = TPA_UNADJ, PLT1 = PLT_CN)]
  t2 <- tr[PLT_CN %in% pr$CN]
  t2 <- merge(t2, t1, by.x = "PREV_TRE_CN", by.y = "CN", all.x = TRUE)
  t2 <- merge(t2, pr[, .(PLT_CN = CN, REMPER, eco)], by = "PLT_CN")
  live2 <- t2[STATUSCD == 1 & DIA >= 1 & !is.na(DRYBIO_AG) & !is.na(TPA_UNADJ)]
  g <- live2[, .(surv = sum(((DRYBIO_AG - b1) * TPA_UNADJ)[!is.na(b1)]), ingr = sum((DRYBIO_AG * TPA_UNADJ)[is.na(b1) & RECONCILECD %in% c(1, 2)]),
                 B2 = sum(DRYBIO_AG * TPA_UNADJ), REMPER = REMPER[1], eco = eco[1]), by = PLT_CN]
  m <- t2[STATUSCD == 2 & !is.na(b1), .(mort = sum(b1 * tpa1)), by = PLT_CN]
  g <- merge(g, m, by = "PLT_CN", all.x = TRUE)[is.na(mort), mort := 0]
  g[, `:=`(gg = (surv + ingr) / REMPER * K, mo = mort / REMPER * K, B2 = B2 * K)]
  dom <- live2[!is.na(code), .(b = sum(DRYBIO_AG * TPA_UNADJ)), by = .(PLT_CN, code)][, sh := b / sum(b), by = PLT_CN][sh >= 0.5, .(PLT_CN, dom = code)]
  g <- merge(g, dom, by = "PLT_CN", all.x = TRUE)
  # site ceiling on the plot as LANDIS would set it: largest BiomassMax among codes present
  pres <- unique(live2[!is.na(code), .(PLT_CN, eco, code)])
  pres <- merge(pres, se, by = c("eco", "code"))[, .(bmx_site = max(BiomassMax)), by = PLT_CN]
  g <- merge(g, pres, by = "PLT_CN", all.x = TRUE)[, sat := B2 / bmx_site]
  act_m2 <- bs$active_cells * bs$cell_m^2
  f <- fia[state == ST]
  sanity[[ST]] <- data.table(state = ST, pairs = nrow(g), mean_gg = mean(g$gg), evalid_gg_per_m2 = f$fia_gross_growth * 1e12 / act_m2,
                             mean_mort = mean(g$mo), evalid_mort_per_m2 = f$fia_mortality * 1e12 / act_m2, mean_B2 = mean(g$B2))
  a <- g[!is.na(dom), .(n = .N, gg_p50 = quantile(gg, 0.5), gg_p90 = quantile(gg, 0.9), gg_p99 = quantile(gg, 0.99), gg_max = max(gg),
                        B_p50 = quantile(B2, 0.5), B_p99 = quantile(B2, 0.99), B_max = max(B2), wB = sum(B2)), by = .(eco, code = dom)]
  a <- merge(se, a, by = c("eco", "code"), all.x = TRUE)[, state := ST]
  a[, `:=`(anpp_mult_to_gg_p90 = gg_p90 / ANPPmax, anpp_mult_to_gg_p99 = gg_p99 / ANPPmax, bmx_mult_to_B_p99 = B_p99 / BiomassMax, bmx_mult_to_B_max = B_max / BiomassMax)]
  cells[[ST]] <- a
  g[, bin := cut(sat, c(0, 0.5, 0.8, 1, 1.2, Inf), right = FALSE)]
  satb[[ST]] <- g[!is.na(bin), .(plots = .N, B_share = sum(B2), mean_B = mean(B2), mean_gg = mean(gg), mean_mort = mean(mo)), by = bin][order(bin)][, `:=`(B_share = B_share / sum(B_share), state = ST)]
  x <- a[!is.na(n) & n >= 5]
  for (aa in grid[[ST]]$a) for (bb in grid[[ST]]$b) summ[[paste(ST, aa, bb)]] <- data.table(state = ST, a = aa, b = bb, cells = nrow(x), plots = sum(x$n),
      share_anpp_over_gg_p99_w = x[, sum(wB * (ANPPmax * aa > gg_p99)) / sum(wB)], share_anpp_below_gg_p50_w = x[, sum(wB * (ANPPmax * aa < gg_p50)) / sum(wB)],
      share_bmx_over_B_max_w = x[, sum(wB * (BiomassMax * bb > B_max)) / sum(wB)], share_bmx_over_B_p99_w = x[, sum(wB * (BiomassMax * bb > B_p99)) / sum(wB)],
      share_bmx_below_B_p50_w = x[, sum(wB * (BiomassMax * bb < B_p50)) / sum(wB)])
  rm(tr, t1, t2, live2, g); gc()
}
cells <- rbindlist(cells); sanity <- rbindlist(sanity); satb <- rbindlist(satb); summ <- rbindlist(summ)
w_med <- function(x, w) { o <- order(x); x <- x[o]; w <- w[o]; x[which(cumsum(w) / sum(w) >= 0.5)[1]] }
med <- cells[!is.na(n) & n >= 5, .(cells = .N, plots = sum(n), wmed_anpp_to_gg_p90 = w_med(anpp_mult_to_gg_p90, wB), wmed_anpp_to_gg_p99 = w_med(anpp_mult_to_gg_p99, wB),
                                   wmed_bmx_to_B_p99 = w_med(bmx_mult_to_B_p99, wB), wmed_bmx_to_B_max = w_med(bmx_mult_to_B_max, wB)), by = state]
fwrite(cells, file.path(O, paste0("fiagc_by_dom_eco_", TAG, ".csv"))); fwrite(sanity, file.path(O, paste0("fiagc_sanity_", TAG, ".csv")))
fwrite(satb, file.path(O, paste0("fiagc_satbins_", TAG, ".csv"))); fwrite(summ, file.path(O, paste0("fiagc_grid_", TAG, ".csv")))
fwrite(med, file.path(O, paste0("fiagc_medians_", TAG, ".csv")))
print(sanity); print(med); print(satb); print(summ)
print(cells[!is.na(n) & n >= 5][order(state, -wB)][, head(.SD, 6), by = state][, .(state, eco, code, n, ANPPmax, gg_p50 = round(gg_p50), gg_p90 = round(gg_p90), BiomassMax, B_p99 = round(B_p99), B_max = round(B_max))])
cat("FIAGC_DONE\n")
