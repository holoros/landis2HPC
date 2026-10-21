# NCASI Phase 1 FVS realism gate, step 1 of 3: FIA remeasured pairs, observed components, FVS inputs, biomass emulator.
# 15 Oct 2026. Public FIA DataMart on Cardinal (fia_datamart_20261006). No coordinates are written anywhere; the NH
# reproduction check reads the public (fuzzed) LAT/LON in memory only, exactly as behav_bins_20261015.R does, to apply
# its ecoregion filter, and writes only bin aggregates.
#
# Pair definition (identical to fia_growth_ceiling_20261015.R and behav_bins_20261015.R): t2 plot with PREV_PLT_CN a
# plot at t1, both INVYR 2000 to 2024, REMPER > 0, forested CONDPROP_UNADJ sum >= 0.99 at both visits. Live trees
# DIA >= 1 in with DRYBIO_AG and TPA_UNADJ present. lb ac-1 x 0.112085 = g m-2. Survivor growth (DRYBIO_AG2 - b1) x
# TPA2 for t2 live trees whose PREV_TRE_CN is a t1 live tree; ingrowth DRYBIO_AG2 x TPA2 for other t2 live trees with
# RECONCILECD 1 or 2; mortality b1 x TPA1 for t1 live trees with STATUSCD 2 at t2. All over REMPER.
# Gate pairs add: no treatment and no disturbance on any t2 condition (TRTCD1-3 and DSTRBCD1-3 all 0 or NA), and no
# t2 tree with STATUSCD 3 (cut). No ecoregion filter (that filter only served the LANDIS raster frame).
suppressMessages({library(data.table)})
F <- "/fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006"
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"
O <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs/work"; dir.create(O, showWarnings = FALSE, recursive = TRUE)
K <- 0.112085; brk <- c(0, 50, 100, 150, 200, 250, 300, Inf)
ch <- function(x) format(x, scientific = FALSE, trim = TRUE)

pairs_for <- function(ST, eco_filter = FALSE, gate = TRUE) {
  pl <- fread(file.path(F, paste0(ST, "_PLOT.csv")), select = c("CN", "PREV_PLT_CN", "INVYR", "REMPER", "ELEV", if (eco_filter) c("LAT", "LON")))
  pl <- pl[INVYR >= 2000 & INVYR <= 2024]
  if (eco_filter) {
    suppressMessages(library(terra))
    se <- fread(file.path(D, ST, "runs", "smoke_20261007_d10_anchored", "SppEcoregionData_fia.csv"))
    pl <- pl[!is.na(LAT)]
    er <- rast(file.path(D, ST, "inputs", "ecoregions_20260929.tif"))
    v <- project(vect(pl, geom = c("LON", "LAT"), crs = "EPSG:4269"), crs(er))
    pl[, eco := as.integer(extract(er, v)[, 2])]; pl[, `:=`(LAT = NULL, LON = NULL)]; rm(v)
    pl <- pl[eco %in% unique(se$EcoregionName)]
  }
  cd <- fread(file.path(F, paste0(ST, "_COND.csv")), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "CONDPROP_UNADJ", "STDAGE", "SICOND_FVS",
              "SIBASE_FVS", "SISP_FVS", "SLOPE", "ASPECT", "FORTYPCD", "DSTRBCD1", "DSTRBCD2", "DSTRBCD3", "TRTCD1", "TRTCD2", "TRTCD3"))
  full <- cd[, .(fp = sum(CONDPROP_UNADJ[COND_STATUS_CD == 1], na.rm = TRUE)), by = PLT_CN][fp >= 0.99, PLT_CN]
  pr <- pl[!is.na(PREV_PLT_CN) & !is.na(REMPER) & REMPER > 0 & CN %in% full & PREV_PLT_CN %in% pl$CN & PREV_PLT_CN %in% full]
  n_all <- nrow(pr)
  if (gate) {
    z <- function(x) is.na(x) | x == 0
    dist <- cd[PLT_CN %in% pr$CN, .(undist = all(z(DSTRBCD1) & z(DSTRBCD2) & z(DSTRBCD3) & z(TRTCD1) & z(TRTCD2) & z(TRTCD3))), by = PLT_CN]
    pr <- pr[CN %in% dist[undist == TRUE, PLT_CN]]
  }
  n_undist <- nrow(pr)
  tr <- fread(file.path(F, paste0(ST, "_TREE.csv")), select = c("CN", "PLT_CN", "PREV_TRE_CN", "STATUSCD", "SPCD", "DIA", "HT", "CR", "TPA_UNADJ", "DRYBIO_AG", "RECONCILECD"))
  tr <- tr[PLT_CN %in% c(pr$CN, pr$PREV_PLT_CN)]; gc()
  if (gate) { cut <- tr[PLT_CN %in% pr$CN & STATUSCD == 3, unique(PLT_CN)]; pr <- pr[!CN %in% cut]; tr <- tr[PLT_CN %in% c(pr$CN, pr$PREV_PLT_CN)] }
  t1 <- tr[PLT_CN %in% pr$PREV_PLT_CN & STATUSCD == 1 & DIA >= 1 & !is.na(DRYBIO_AG) & !is.na(TPA_UNADJ),
           .(CN, b1 = DRYBIO_AG, tpa1 = TPA_UNADJ, PLT1 = PLT_CN, SPCD, DIA, HT, CR)]
  B1 <- t1[, .(B1 = sum(b1 * tpa1), n1 = .N), by = PLT1]
  t2 <- merge(tr[PLT_CN %in% pr$CN], t1[, .(CN, b1, tpa1, D1 = DIA, H1 = HT)], by.x = "PREV_TRE_CN", by.y = "CN", all.x = TRUE)
  t2 <- merge(t2, pr[, .(PLT_CN = CN, PREV_PLT_CN, REMPER, INVYR)], by = "PLT_CN")
  live2 <- t2[STATUSCD == 1 & DIA >= 1 & !is.na(DRYBIO_AG) & !is.na(TPA_UNADJ)]
  g <- live2[, .(surv = sum(((DRYBIO_AG - b1) * TPA_UNADJ)[!is.na(b1)]), ingr = sum((DRYBIO_AG * TPA_UNADJ)[is.na(b1) & RECONCILECD %in% c(1, 2)]),
                 B2 = sum(DRYBIO_AG * TPA_UNADJ), REMPER = REMPER[1], PREV_PLT_CN = PREV_PLT_CN[1], INVYR2 = INVYR[1]), by = PLT_CN]
  # plots with no t2 live tree still belong to the pair set (behav code drops them; kept identical for the reproduction)
  m <- t2[STATUSCD == 2 & !is.na(b1), .(mort = sum(b1 * tpa1)), by = PLT_CN]
  g <- merge(merge(g, m, by = "PLT_CN", all.x = TRUE), B1, by.x = "PREV_PLT_CN", by.y = "PLT1", all.x = TRUE)
  g[is.na(mort), mort := 0][is.na(B1), `:=`(B1 = 0, n1 = 0L)]
  g[, `:=`(gg = (surv + ingr) / REMPER * K, mo = mort / REMPER * K, Bmid = (B1 + B2) / 2 * K / 100)]
  list(g = g, t1 = t1, live2 = live2, pl = pl, cd = cd, n_all = n_all, n_undist = n_undist)
}

# ---- (3) reproduction check: NH observed bins of behav_bins_20261015.csv, same selection, same binning ----
ref <- unique(fread(file.path(D, "gates", "behav_bins_20261015.csv"))[, .(state, bin, plots, fia_gg)])
rep <- list()
for (ST in c("NH", "VT")) {
  x <- pairs_for(ST, eco_filter = TRUE, gate = FALSE)$g
  x[, bin := cut(Bmid, brk, right = FALSE)]
  b <- x[, .(plots_mine = .N, gg_mine = mean(gg)), by = bin][, `:=`(state = ST, bin = as.character(bin))]
  rep[[ST]] <- merge(b, ref[state == ST], by = c("state", "bin"))
  rm(x); gc()
}
rep <- rbindlist(rep)[, `:=`(rel_diff = gg_mine / fia_gg - 1)][, pass := plots_mine == plots & abs(rel_diff) < 0.01]
print(rep); fwrite(rep, file.path(O, "repro_behav_bins_20261015.csv"))
if (!all(rep$pass)) { cat("REPRODUCTION FAILED\n"); quit(status = 2) }
cat("REPRODUCTION PASSED\n")

# ---- gate pairs, FVS inputs, emulator fit data ----
summ <- list(); coefs <- list(); valid <- list()
for (ST in c("ME", "NH", "VT", "MI", "WI", "MN")) {
  P <- pairs_for(ST, eco_filter = FALSE, gate = TRUE)
  g <- P$g; t1 <- P$t1; live2 <- P$live2
  # stand attributes from the t1 plot: largest forested condition
  c1 <- P$cd[PLT_CN %in% g$PREV_PLT_CN & COND_STATUS_CD == 1][order(PLT_CN, -CONDPROP_UNADJ)][, .SD[1], by = PLT_CN]
  pl1 <- P$pl[CN %in% g$PREV_PLT_CN, .(PLT_CN = CN, INVYR1 = INVYR, ELEV)]
  st <- merge(g, c1[, .(PLT_CN, STDAGE, SICOND_FVS, SIBASE_FVS, SISP_FVS, SLOPE, ASPECT, FORTYPCD)], by.x = "PREV_PLT_CN", by.y = "PLT_CN", all.x = TRUE)
  st <- merge(st, pl1, by.x = "PREV_PLT_CN", by.y = "PLT_CN", all.x = TRUE)
  st[, `:=`(pair_id = ch(PLT_CN), t1_id = ch(PREV_PLT_CN), state = ST, obs_surv = surv / REMPER * K / 100, obs_ingr = ingr / REMPER * K / 100,
            obs_mort = mort / REMPER * K / 100, B1_Mgha = B1 * K / 100, B2_Mgha = B2 * K / 100)]
  st[, `:=`(obs_gg = obs_surv + obs_ingr, obs_net = obs_surv + obs_ingr - obs_mort)]
  fwrite(st[, .(state, pair_id, t1_id, INVYR1, INVYR2, REMPER, n1, B1_Mgha, B2_Mgha, obs_surv, obs_ingr, obs_mort, obs_gg, obs_net,
               STDAGE, SICOND_FVS, SIBASE_FVS, SISP_FVS, SLOPE, ASPECT, FORTYPCD, ELEV)], file.path(O, paste0("pairs_", ST, ".csv")))
  tt <- merge(t1, st[, .(PREV_PLT_CN, pair_id)], by.x = "PLT1", by.y = "PREV_PLT_CN", allow.cartesian = TRUE)
  fwrite(tt[, .(pair_id, tree_cn = ch(CN), SPCD, DIA, HT, CR, TPA_UNADJ = tpa1, DRYBIO_AG = b1)], file.path(O, paste0("trees_", ST, ".csv")))
  # emulator: ln(DRYBIO_AG) = a + b ln(DIA) + c ln(HT) by SPCD (n >= 50) else softwood (SPCD < 300) or hardwood, fit on
  # live t1 and t2 trees of the gate pairs. Used ONLY as a ratio f(D2,H2)/f(D1,H1) applied to each tree's own NSVB b1.
  fd <- rbind(t1[, .(SPCD, DIA, HT, B = b1)], live2[, .(SPCD, DIA, HT, B = DRYBIO_AG)])[HT > 0 & B > 0]
  fd[, grp := ifelse(SPCD < 300, -1L, -2L)]
  fit1 <- function(d) { m <- lm(log(B) ~ log(DIA) + log(HT), d); data.table(a = coef(m)[1], b = coef(m)[2], c = coef(m)[3], n = nrow(d), r2 = summary(m)$r.squared) }
  cs <- fd[, fit1(.SD), by = SPCD][n >= 50]; cg <- fd[, fit1(.SD), by = .(SPCD = grp)]
  co <- rbind(cs, cg)[, state := ST]; coefs[[ST]] <- co
  # validation on observed survivors: emulated b2 = b1 * f(D2,H2)/f(D1,H1) against the NSVB DRYBIO_AG2 actually reported
  sv <- live2[!is.na(b1) & HT > 0 & H1 > 0]
  sv[, key := ifelse(SPCD %in% cs$SPCD, SPCD, ifelse(SPCD < 300, -1L, -2L))]
  sv <- merge(sv, co[, .(key = SPCD, b, c)], by = "key")
  sv[, b2e := b1 * exp(b * (log(DIA) - log(D1)) + c * (log(HT) - log(H1)))]
  valid[[ST]] <- sv[, .(state = ST, trees = .N, surv_growth_nsvb = sum((DRYBIO_AG - b1) * TPA_UNADJ), surv_growth_emul = sum((b2e - b1) * TPA_UNADJ))][, ratio := surv_growth_emul / surv_growth_nsvb]
  summ[[ST]] <- data.table(state = ST, pairs_all = P$n_all, pairs_undisturbed = P$n_undist, pairs_gate = nrow(st), pairs_no_t1_trees = sum(st$n1 == 0),
                           t1_trees = nrow(tt), share_sicond_fvs = mean(!is.na(st$SICOND_FVS) & st$SICOND_FVS > 0),
                           obs_gg = mean(st$obs_gg), obs_mort = mean(st$obs_mort), obs_net = mean(st$obs_net), obs_B1 = mean(st$B1_Mgha))
  print(summ[[ST]]); print(valid[[ST]])
  rm(P, g, t1, live2, st, tt, fd, sv); gc()
}
fwrite(rbindlist(summ), file.path(O, "pairs_summary_20261015.csv")); fwrite(rbindlist(coefs), file.path(O, "emul_coef_20261015.csv"))
fwrite(rbindlist(valid), file.path(O, "emul_valid_20261015.csv"))
print(rbindlist(valid))
cat("PAIRS_DONE\n")
