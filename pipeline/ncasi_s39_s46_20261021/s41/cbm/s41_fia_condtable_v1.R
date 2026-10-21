## s41: condition-level FIA table for the conversion test (applying each state's
## CBM Boudewyn chain to the volumes FIA actually measured). Same estimator and
## filters as s41_fia_nsvb_components_v2.R. Output has NO PLT_CN, NO coordinates,
## and stays on Cardinal (it is unit level, not an aggregate).
suppressPackageStartupMessages(library(data.table))
DM  <- "/fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006"
REF <- fread("/users/PUOM0008/crsfaaron/fia_cem_projections/config/REF_FOREST_TYPE.csv")
ref <- unique(REF[, .(FORTYPCD = as.integer(VALUE), TYPGRPCD = as.integer(TYPGRPCD))])
SC  <- c(ME = 23, NH = 33, VT = 50, MI = 26, WI = 55, MN = 27)
LB2T <- 0.45359237e-3; FT3M3 <- 0.0283168466; AC2HA <- 0.40468564
res <- list()
for (st in names(SC)) {
  ev <- SC[[st]] * 10000 + 2401
  ppsa <- fread(file.path(DM, paste0(st, "_POP_PLOT_STRATUM_ASSGN.csv")), select = c("PLT_CN", "STRATUM_CN", "EVALID"))[EVALID == ev]
  ps <- fread(file.path(DM, paste0(st, "_POP_STRATUM.csv")), select = c("CN", "EXPNS", "ADJ_FACTOR_MICR", "ADJ_FACTOR_SUBP", "ADJ_FACTOR_MACR"))
  ppsa <- merge(ppsa, ps, by.x = "STRATUM_CN", by.y = "CN")
  co <- fread(file.path(DM, paste0(st, "_COND.csv")), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "FORTYPCD", "CONDPROP_UNADJ"))
  co <- merge(co[PLT_CN %in% ppsa$PLT_CN & COND_STATUS_CD == 1], ref, by = "FORTYPCD", all.x = TRUE)
  co <- merge(co, ppsa[, .(PLT_CN, EXPNS, ADJ_FACTOR_SUBP)], by = "PLT_CN")
  co[, area_ha := CONDPROP_UNADJ * ADJ_FACTOR_SUBP * EXPNS * AC2HA]
  tr <- fread(file.path(DM, paste0(st, "_TREE.csv")), select = c("PLT_CN", "CONDID", "STATUSCD", "DIA", "TPA_UNADJ", "VOLCFNET", "DRYBIO_AG", "DRYBIO_FOLIAGE"))
  tr <- tr[PLT_CN %in% co$PLT_CN & STATUSCD == 1 & !is.na(DIA) & DIA >= 1 & !is.na(TPA_UNADJ)]
  tr <- merge(tr, ppsa[, .(PLT_CN, EXPNS, ADJ_FACTOR_MICR, ADJ_FACTOR_SUBP)], by = "PLT_CN")
  tr[, EXP := TPA_UNADJ * fifelse(DIA < 5, ADJ_FACTOR_MICR, ADJ_FACTOR_SUBP) * EXPNS]
  for (v in c("VOLCFNET", "DRYBIO_AG", "DRYBIO_FOLIAGE")) set(tr, which(is.na(tr[[v]])), v, 0)
  t2 <- tr[, .(vnet_m3 = sum(fifelse(DIA >= 5, VOLCFNET, 0) * EXP) * FT3M3, ag_t = sum(DRYBIO_AG * EXP) * LB2T, fol_t = sum(DRYBIO_FOLIAGE * EXP) * LB2T), by = .(PLT_CN, CONDID)]
  co <- merge(co, t2, by = c("PLT_CN", "CONDID"), all.x = TRUE)
  for (v in c("vnet_m3", "ag_t", "fol_t")) set(co, which(is.na(co[[v]])), v, 0)
  co <- co[area_ha > 0]
  res[[st]] <- co[, .(state = st, TYPGRPCD, area_ha, vnet_m3ha = vnet_m3 / area_ha, ag_tha = ag_t / area_ha, fol_tha = fol_t / area_ha)]
}
R <- rbindlist(res)
fwrite(R, "s41_fia_condtable_20261015_CARDINAL_ONLY.csv")
print(R[, .(n = .N, area_Mha = sum(area_ha) / 1e6, ag_Tg = sum(ag_tha * area_ha) / 1e6, vnet_Mm3 = sum(vnet_m3ha * area_ha) / 1e6), by = state])
