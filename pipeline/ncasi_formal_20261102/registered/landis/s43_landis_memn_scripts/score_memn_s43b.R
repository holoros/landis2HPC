# s43b: per-ecoregion join flips the input ecoregion map, because LANDIS output rasters read upside down relative to inputs (align job 15674398).
# s43 Track A step 8: registered realism gate + behavioural gate for ME and MN LANDIS smokes (scoring method of
# behav_gate_score_20261015.R, sessions 39/40): production = mean of year 5 and 10 landscape ANPP; mortality = production
# minus (t10 - t5)/5 (mortality net of recruitment); net = (t10 - t0)/10; high = mean over FIA bins >= 200 Mg/ha (>= 20 plots)
# of LANDIS year 5 mean ANPP / FIA plot gross growth. Gate: stock within 10 pct (wider than EVALIDator CI), production,
# mortality, net within 15 pct, high within 0.8 to 1.25. Targets: EVALIDator 2024 (2026-10-15_evalidator-grm-me-mn_DATA.csv).
# Step 0 reproduction gate: rescore VT fit_20261015_d10_confirm_a2.30_b2.90_r2 against gates/behav_gate_confirm_20261015c.csv (1e-6).
# Diagnostics: per-ecoregion production and mortality per ha vs FIA remeasured-plot means (same pair definitions as
# fia_bins_memn_20261015.R; plots located by public fuzzed LAT/LON on the s43 ecoregion layer, server side only), and
# BiomassMax (max over species, Mg/ha) vs FIA plot 99th percentile of live AGB by ecoregion for ME, MN and the NH VT MI WI fitted tables.
# Usage: Rscript score_memn_s43.R TAG
suppressMessages({library(terra); library(data.table)}); set.seed(20261019)
TAG <- commandArgs(TRUE)[1]
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn"; O <- file.path(T, "out")
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"; F <- "/fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006"
tg <- data.table(state = c("ME", "MN"), stock = c(762.4297, 633.4494), gross = c(25.6128, 25.1058), mort = c(9.4943, 10.6370), net = c(16.1185, 14.4688))
brk <- c(0, 50, 100, 150, 200, 250, 300, Inf); hi <- c("[200,250)", "[250,300)", "[300,Inf)")
rv <- function(R, f) values(rast(file.path(R, f)))[, 1]
score <- function(R, st, fb) {
  lg <- file.path(R, "Landis-log.txt")
  if (!file.exists(lg) || !any(grepl("Model run is complete", readLines(lg, warn = FALSE)))) return(data.table(state = st, run = basename(R), complete = FALSE))
  cell <- fread(file.path(R, "build_summary.csv"))$cell_m; k <- cell^2 / 1e12
  b0 <- rv(R, "output/biomass/biomass-TotalBiomass-0.tif"); b5 <- rv(R, "output/biomass/biomass-TotalBiomass-5.tif"); b10 <- rv(R, "output/biomass/biomass-TotalBiomass-10.tif")
  a5 <- rv(R, "biomass-succession\\biomass-anpp-5.tif"); a10 <- rv(R, "biomass-succession\\biomass-anpp-10.tif")
  t0 <- sum(b0, na.rm = TRUE) * k; t5 <- sum(b5, na.rm = TRUE) * k; t10 <- sum(b10, na.rm = TRUE) * k
  an5 <- sum(a5, na.rm = TRUE) * k; an10 <- sum(a10, na.rm = TRUE) * k
  ok <- !is.na(b5) & b5 > 0 & !is.na(a5)
  x <- data.table(bin = cut(b5[ok] / 100, brk, right = FALSE), anpp = a5[ok])[, .(mean_anpp = mean(anpp)), by = bin]
  x <- merge(x, fb[state == st], by = "bin")[plots >= 20]
  out <- data.table(state = st, run = basename(R), complete = TRUE, t0_Tg = t0, t10_Tg = t10, anpp5_Tg = an5, anpp_mean = (an5 + an10) / 2,
             net_0_10 = (t10 - t0) / 10, mort_5_10 = (an5 + an10) / 2 - (t10 - t5) / 5,
             ratio_high = x[bin %in% hi, mean(mean_anpp / fia_gg)], rmse_gpm2 = x[, sqrt(weighted.mean((mean_anpp - fia_gg)^2, plot_share))])
  e <- file.path(R, "ecoregions.tif")
  if (file.exists(e)) { ev <- values(flip(rast(file.path(R, "ecoregions.tif"))))[, 1]; m <- !is.na(ev) & ev > 0
    pe <- data.table(eco = ev[m], prod = (a5[m] + a10[m]) / 2, b5 = b5[m], b10 = b10[m])[, mort := prod - (b10 - b5) / 5][, .(cells = .N, landis_prod_gm2 = mean(prod), landis_mort_gm2 = mean(mort)), by = eco]
    attr(out, "eco") <- pe[, `:=`(state = st, run = basename(R))] }
  out
}
# Step 0
fb4 <- unique(fread(file.path(D, "gates/behav_bins_20261015.csv"))[, .(state, bin, plots, fia_gg, plot_share)])
ref <- fread(file.path(D, "gates/behav_gate_confirm_20261015c.csv"))[state == "VT"]
r0 <- score(file.path(D, "VT/runs", ref$run), "VT", fb4)
d0 <- c(t10 = r0$t10_Tg - ref$t10_Tg, prod = r0$anpp_mean - ref$anpp_mean, mort = r0$mort_5_10 - ref$mort_5_10, net = r0$net_0_10 - ref$net_0_10, high = r0$ratio_high - ref$ratio_high)
print(d0); if (any(abs(d0) > 1e-6)) { cat("REPRODUCTION GATE FAILED\n"); quit(status = 2) }; cat("REPRODUCTION GATE PASS\n")
# Score ME and MN runs
fbm <- fread("/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/gates/fia_bins_memn_20261015.csv")[, .(state, bin, plots, fia_gg, plot_share)]
res <- list(); eco <- list()
for (st in c("ME", "MN")) for (R in list.dirs(file.path(T, "runs", st), recursive = FALSE)) { if (basename(R) == "base270") next
  s <- score(R, st, fbm); eco[[length(eco) + 1]] <- attr(s, "eco"); res[[length(res) + 1]] <- s }
res <- merge(rbindlist(res, fill = TRUE), tg, by = "state")
res[, `:=`(r_stock = t0_Tg / stock, r_prod = anpp_mean / gross, r_mort = mort_5_10 / mort, r_net = net_0_10 / net)]
res[, `:=`(g_stock = abs(r_stock - 1) <= 0.10, g_prod = abs(r_prod - 1) <= 0.15, g_mort = abs(r_mort - 1) <= 0.15, g_net = abs(r_net - 1) <= 0.15, g_high = ratio_high >= 0.8 & ratio_high <= 1.25)]
res[, pass := g_stock & g_prod & g_mort & g_net & g_high]
res[, loss := log(pmax(r_prod, 1e-3))^2 + log(pmax(r_mort, 1e-3))^2 + log(pmax(r_net, 1e-3))^2 + log(pmax(ratio_high, 1e-3))^2]
spec <- rbindlist(lapply(res$run, function(rn) { st <- res[run == rn, state]; data.table(run = rn, spec = readLines(file.path(T, "runs", st, rn, "RUN_SPEC.txt"))[1]) }))
res <- merge(res, spec, by = "run")
fwrite(res, file.path(O, paste0("behav_gate_memn_", TAG, ".csv")))
print(res[order(state, loss), .(state, run, r_stock = round(r_stock, 4), r_prod = round(r_prod, 3), r_mort = round(r_mort, 3), r_net = round(r_net, 3), high = round(ratio_high, 3), pass)])
# Per-ecoregion FIA plot means (remeasured pairs; fia_bins_memn_20261015.R definitions) and p99 AGB
K <- 0.112085
fia_eco <- function(ST, er) {
  pl <- fread(file.path(F, paste0(ST, "_PLOT.csv")), select = c("CN", "PREV_PLT_CN", "INVYR", "REMPER", "LAT", "LON"))[INVYR >= 2000 & INVYR <= 2024 & !is.na(LAT)]
  pl[, eco := as.integer(extract(er, project(vect(pl, geom = c("LON", "LAT"), crs = "EPSG:4269"), crs(er)))[, 2])]; pl[, `:=`(LAT = NULL, LON = NULL)]
  cd <- fread(file.path(F, paste0(ST, "_COND.csv")), select = c("PLT_CN", "COND_STATUS_CD", "CONDPROP_UNADJ"))
  full <- cd[, .(fp = sum(CONDPROP_UNADJ[COND_STATUS_CD == 1], na.rm = TRUE)), by = PLT_CN][fp >= 0.99, PLT_CN]
  tr <- fread(file.path(F, paste0(ST, "_TREE.csv")), select = c("CN", "PLT_CN", "PREV_TRE_CN", "STATUSCD", "DIA", "TPA_UNADJ", "DRYBIO_AG", "RECONCILECD"))
  # p99 of plot live AGB, fully forested plots INVYR 2015-2024
  p99 <- tr[PLT_CN %in% pl[INVYR >= 2015 & CN %in% full, CN] & STATUSCD == 1 & DIA >= 1 & !is.na(DRYBIO_AG) & !is.na(TPA_UNADJ), .(agb = sum(DRYBIO_AG * TPA_UNADJ) * K / 100), by = PLT_CN]
  p99 <- merge(p99, pl[, .(PLT_CN = CN, eco)], by = "PLT_CN")[!is.na(eco) & eco > 0, .(plots_p99 = .N, fia_p99_Mgha = quantile(agb, 0.99)), by = eco]
  pr <- pl[!is.na(PREV_PLT_CN) & !is.na(REMPER) & REMPER > 0 & CN %in% full & PREV_PLT_CN %in% pl$CN & PREV_PLT_CN %in% full]
  tr <- tr[PLT_CN %in% c(pr$CN, pr$PREV_PLT_CN)]
  t1 <- tr[PLT_CN %in% pr$PREV_PLT_CN & STATUSCD == 1 & DIA >= 1 & !is.na(DRYBIO_AG) & !is.na(TPA_UNADJ), .(CN, b1 = DRYBIO_AG, tpa1 = TPA_UNADJ)]
  t2 <- merge(tr[PLT_CN %in% pr$CN], t1, by.x = "PREV_TRE_CN", by.y = "CN", all.x = TRUE)
  t2 <- merge(t2, pr[, .(PLT_CN = CN, REMPER, eco)], by = "PLT_CN")
  live2 <- t2[STATUSCD == 1 & DIA >= 1 & !is.na(DRYBIO_AG) & !is.na(TPA_UNADJ)]
  g <- live2[, .(surv = sum(((DRYBIO_AG - b1) * TPA_UNADJ)[!is.na(b1)]), ingr = sum((DRYBIO_AG * TPA_UNADJ)[is.na(b1) & RECONCILECD %in% c(1, 2)]), REMPER = REMPER[1], eco = eco[1]), by = PLT_CN]
  m <- t2[STATUSCD == 2 & !is.na(b1), .(mort = sum(b1 * tpa1)), by = PLT_CN]
  g <- merge(g, m, by = "PLT_CN", all.x = TRUE); g[is.na(mort), mort := 0]
  g <- g[!is.na(eco) & eco > 0, .(pairs = .N, fia_gg_gm2 = mean((surv + ingr) / REMPER * K), fia_mo_gm2 = mean(mort / REMPER * K)), by = eco]
  merge(g, p99, by = "eco", all = TRUE)[, state := ST][]
}
eco_layers <- list(ME = file.path(O, "ecoregions_s43_ME_from270.tif"), MN = file.path(O, "ecoregions_s43_MN_from30.tif"),
  NH = file.path(D, "NH/inputs/ecoregions_20260929.tif"), VT = file.path(D, "VT/inputs/ecoregions_20260929.tif"),
  MI = file.path(D, "MI/inputs/ecoregions_20260929.tif"), WI = file.path(D, "WI/inputs/ecoregions_20260929.tif"))
fe <- rbindlist(lapply(names(eco_layers), function(s) fia_eco(s, rast(eco_layers[[s]]))))
E <- merge(rbindlist(eco, fill = TRUE), fe[state %in% c("ME", "MN")], by = c("state", "eco"), all.x = TRUE)
E[, `:=`(r_prod_eco = landis_prod_gm2 / fia_gg_gm2, r_mort_eco = landis_mort_gm2 / fia_mo_gm2)]
fwrite(E, file.path(O, paste0("behav_by_ecoregion_memn_", TAG, ".csv")))
print(E[, .(state, run, eco, cells, pairs, r_prod_eco = round(r_prod_eco, 3), r_mort_eco = round(r_mort_eco, 3))])
# BiomassMax vs FIA p99
tabs <- list(NH = file.path(D, "NH/inputs/SppEcoregionData_fia_20261015.csv"), VT = file.path(D, "VT/inputs/SppEcoregionData_fia_20261015.csv"),
  MI = file.path(D, "MI/inputs/SppEcoregionData_fia_20261015.csv"), WI = file.path(D, "WI/inputs/SppEcoregionData_fia_20261015.csv"))
for (rn in res$run) tabs[[paste(res[run == rn, state], rn, sep = ":")]] <- file.path(T, "runs", res[run == rn, state], rn, "SppEcoregionData_fia.csv")
bm <- rbindlist(lapply(names(tabs), function(n) { s <- sub(":.*", "", n); x <- fread(tabs[[n]])
  x[, .(bmax_max_Mgha = max(BiomassMax) / 100, bmax_median_Mgha = median(BiomassMax) / 100), by = .(eco = EcoregionName)][, `:=`(state = s, table = n)] }))
bm <- merge(bm, fe[, .(state, eco, plots_p99, fia_p99_Mgha)], by = c("state", "eco"))
bm[, `:=`(ratio_max_to_p99 = bmax_max_Mgha / fia_p99_Mgha, ratio_median_to_p99 = bmax_median_Mgha / fia_p99_Mgha)]
fwrite(bm, file.path(O, paste0("bmax_vs_fia_p99_", TAG, ".csv")))
print(bm[, .(table, eco, plots_p99, p99 = round(fia_p99_Mgha), bmax_max = round(bmax_max_Mgha), r_max = round(ratio_max_to_p99, 2), r_med = round(ratio_median_to_p99, 2))])
cat("SCORE_DONE\n")
