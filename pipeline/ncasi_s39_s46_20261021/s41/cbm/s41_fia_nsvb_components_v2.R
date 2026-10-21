## s41: FIA NSVB aboveground live tree biomass by CBM-equivalent component,
## design based (EVALID <ST>2401, current), per state and forest type group,
## plus condition-level calibration ratios for a Boudewyn chain built on NSVB.
## Public DataMart on Cardinal. Writes AGGREGATES ONLY (no PLT_CN, no coordinates).
## CBM pool mapping (Boudewyn 2007 / CBM-CFS3 definitions):
##   merch  = DRYBIO_BOLE + DRYBIO_BOLE_BARK of trees DIA >= 5 (stump to 4 in top)
##   other  = stump, top (STEM - BOLE - STUMP) wood and bark and branches of DIA >= 5,
##            plus stem wood, stem bark and branches of saplings 1 <= DIA < 5
##   foliage= DRYBIO_FOLIAGE all live trees (NOT in DRYBIO_AG)
suppressPackageStartupMessages(library(data.table))
DM  <- "/fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006"
REF <- fread("/users/PUOM0008/crsfaaron/fia_cem_projections/config/REF_FOREST_TYPE.csv")
ref <- unique(REF[, .(FORTYPCD = as.integer(VALUE), TYPGRPCD = as.integer(TYPGRPCD))])
SC  <- c(ME = 23, NH = 33, VT = 50, MI = 26, WI = 55, MN = 27)
LB2TG <- 0.45359237e-9; FT3M3 <- 0.0283168466; LBAC2THA <- 0.00112085; FT3AC2M3HA <- 0.0699725
out <- list(); cal <- list(); chk <- list()
for (st in names(SC)) {
  ev <- SC[[st]] * 10000 + 2401
  pe <- fread(file.path(DM, paste0(st, "_POP_EVAL.csv")), select = c("CN", "EVALID", "END_INVYR"))
  pt <- fread(file.path(DM, paste0(st, "_POP_EVAL_TYP.csv")), select = c("EVAL_CN", "EVAL_TYP"))
  typ <- pt[EVAL_CN %in% pe[EVALID == ev, CN], paste(sort(unique(EVAL_TYP)), collapse = ";")]
  stopifnot(nrow(pe[EVALID == ev]) == 1)
  ppsa <- fread(file.path(DM, paste0(st, "_POP_PLOT_STRATUM_ASSGN.csv")), select = c("PLT_CN", "STRATUM_CN", "EVALID"))[EVALID == ev]
  ps <- fread(file.path(DM, paste0(st, "_POP_STRATUM.csv")), select = c("CN", "EXPNS", "ADJ_FACTOR_MICR", "ADJ_FACTOR_SUBP", "ADJ_FACTOR_MACR"))
  ppsa <- merge(ppsa, ps, by.x = "STRATUM_CN", by.y = "CN")
  pl <- fread(file.path(DM, paste0(st, "_PLOT.csv")), select = c("CN", "MACRO_BREAKPOINT_DIA"))
  ppsa <- merge(ppsa, pl, by.x = "PLT_CN", by.y = "CN", all.x = TRUE)
  co <- fread(file.path(DM, paste0(st, "_COND.csv")), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "FORTYPCD", "CONDPROP_UNADJ"))
  co <- co[PLT_CN %in% ppsa$PLT_CN]
  co <- merge(co, ref, by = "FORTYPCD", all.x = TRUE)
  # forest area check (EXPCURR style): sum CONDPROP_UNADJ * adj * EXPNS over forest conditions
  ca <- merge(co[COND_STATUS_CD == 1], ppsa, by = "PLT_CN")
  # area adjustment uses SUBP unless macro plot design (none in these states assumed; checked below)
  area_ha <- ca[, sum(CONDPROP_UNADJ * ADJ_FACTOR_SUBP * EXPNS)] * 0.40468564
  tcols <- c("PLT_CN", "CONDID", "STATUSCD", "SPCD", "DIA", "TPA_UNADJ", "VOLCFNET", "VOLCFGRS",
             "DRYBIO_AG", "DRYBIO_STEM", "DRYBIO_STEM_BARK", "DRYBIO_BOLE", "DRYBIO_BOLE_BARK",
             "DRYBIO_STUMP", "DRYBIO_STUMP_BARK", "DRYBIO_BRANCH", "DRYBIO_FOLIAGE")
  tr <- fread(file.path(DM, paste0(st, "_TREE.csv")), select = tcols)
  tr <- tr[PLT_CN %in% ppsa$PLT_CN & STATUSCD == 1 & !is.na(DIA) & DIA >= 1 & !is.na(TPA_UNADJ)]
  tr <- merge(tr, co[, .(PLT_CN, CONDID, COND_STATUS_CD, TYPGRPCD, CONDPROP_UNADJ)], by = c("PLT_CN", "CONDID"))
  tr <- tr[COND_STATUS_CD == 1]
  tr <- merge(tr, ppsa[, .(PLT_CN, EXPNS, ADJ_FACTOR_MICR, ADJ_FACTOR_SUBP, ADJ_FACTOR_MACR, MACRO_BREAKPOINT_DIA)], by = "PLT_CN")
  tr[, ADJ := fifelse(DIA < 5, ADJ_FACTOR_MICR,
               fifelse(is.na(MACRO_BREAKPOINT_DIA) | DIA < MACRO_BREAKPOINT_DIA, ADJ_FACTOR_SUBP, ADJ_FACTOR_MACR))]
  tr[, EXP := TPA_UNADJ * ADJ * EXPNS]
  for (v in tcols[7:length(tcols)]) set(tr, which(is.na(tr[[v]])), v, 0)
  tr[, big := DIA >= 5]
  tr[, `:=`(
    m_wood  = fifelse(big, DRYBIO_BOLE, 0),
    m_bark  = fifelse(big, DRYBIO_BOLE_BARK, 0),
    o_stump = fifelse(big, DRYBIO_STUMP + DRYBIO_STUMP_BARK, 0),
    o_top   = fifelse(big, (DRYBIO_STEM - DRYBIO_BOLE - DRYBIO_STUMP) + (DRYBIO_STEM_BARK - DRYBIO_BOLE_BARK - DRYBIO_STUMP_BARK), 0),
    o_branch_big = fifelse(big, DRYBIO_BRANCH, 0),
    o_sap   = fifelse(big, 0, DRYBIO_STEM + DRYBIO_STEM_BARK + DRYBIO_BRANCH),
    stemwood_big = fifelse(big, DRYBIO_STEM, 0),
    stemwood_all = DRYBIO_STEM, bark_all = DRYBIO_STEM_BARK,
    branch_all = DRYBIO_BRANCH, fol = DRYBIO_FOLIAGE,
    vnet = fifelse(big, VOLCFNET, 0), vgrs = fifelse(big, VOLCFGRS, 0))]
  chk[[st]] <- data.table(state = st, evalid = ev, eval_types = typ, n_plots = uniqueN(ppsa$PLT_CN),
    forest_area_ha = area_ha, macro_plots = sum(!is.na(ppsa$MACRO_BREAKPOINT_DIA) & ppsa$MACRO_BREAKPOINT_DIA > 0),
    n_neg_top = tr[big & (DRYBIO_STEM - DRYBIO_BOLE - DRYBIO_STUMP) < -1e-6, .N], n_big = tr[big == TRUE, .N],
    n_big_bole0 = tr[big & DRYBIO_BOLE <= 0, .N])
  agg <- function(d) d[, .(
    fia_AG_Tg = sum(DRYBIO_AG * EXP) * LB2TG,
    merch_Tg = sum((m_wood + m_bark) * EXP) * LB2TG,
    merch_wood_Tg = sum(m_wood * EXP) * LB2TG,
    other_Tg = sum((o_stump + o_top + o_branch_big + o_sap) * EXP) * LB2TG,
    other_stump_Tg = sum(o_stump * EXP) * LB2TG, other_top_Tg = sum(o_top * EXP) * LB2TG,
    other_branch_big_Tg = sum(o_branch_big * EXP) * LB2TG, other_sapling_Tg = sum(o_sap * EXP) * LB2TG,
    foliage_Tg = sum(fol * EXP) * LB2TG,
    stemwood_big_Tg = sum(stemwood_big * EXP) * LB2TG, stemwood_all_Tg = sum(stemwood_all * EXP) * LB2TG,
    bark_all_Tg = sum(bark_all * EXP) * LB2TG, branch_all_Tg = sum(branch_all * EXP) * LB2TG,
    volcfnet_Mm3 = sum(vnet * EXP) * FT3M3 / 1e6, volcfgrs_Mm3 = sum(vgrs * EXP) * FT3M3 / 1e6)]
  s <- agg(tr); s[, `:=`(state = st, TYPGRPCD = -1L)]
  g <- tr[, agg(.SD), by = TYPGRPCD]; g[, state := st]
  out[[st]] <- rbind(s, g, fill = TRUE)
  # condition-level ratios for the calibration (per state x group): ratio of totals
  cal[[st]] <- tr[, .(
    n_cond = uniqueN(paste(PLT_CN, CONDID)),
    a_merch_wood_per_m3 = sum(m_wood * EXP) / sum(vnet * EXP) * 0.45359237e-3 / FT3M3,  # Mg wood per m3 net
    a_stemwood_big_per_m3 = sum(stemwood_big * EXP) / sum(vnet * EXP) * 0.45359237e-3 / FT3M3,
    k_nonmerch = sum(stemwood_big * EXP) / sum(m_wood * EXP),
    k_sap = sum(stemwood_all * EXP) / sum(stemwood_big * EXP),
    p_stemwood = sum(stemwood_all * EXP) / sum((stemwood_all + bark_all + branch_all + fol) * EXP),
    p_bark = sum(bark_all * EXP) / sum((stemwood_all + bark_all + branch_all + fol) * EXP),
    p_branch = sum(branch_all * EXP) / sum((stemwood_all + bark_all + branch_all + fol) * EXP),
    p_foliage = sum(fol * EXP) / sum((stemwood_all + bark_all + branch_all + fol) * EXP),
    merchbark_over_merchwood = sum(m_bark * EXP) / sum(m_wood * EXP)), by = TYPGRPCD][, state := st]
  pooled <- tr[, .(TYPGRPCD = -1L, n_cond = uniqueN(paste(PLT_CN, CONDID)),
    a_merch_wood_per_m3 = sum(m_wood * EXP) / sum(vnet * EXP) * 0.45359237e-3 / FT3M3,
    a_stemwood_big_per_m3 = sum(stemwood_big * EXP) / sum(vnet * EXP) * 0.45359237e-3 / FT3M3,
    k_nonmerch = sum(stemwood_big * EXP) / sum(m_wood * EXP), k_sap = sum(stemwood_all * EXP) / sum(stemwood_big * EXP),
    p_stemwood = sum(stemwood_all * EXP) / sum((stemwood_all + bark_all + branch_all + fol) * EXP),
    p_bark = sum(bark_all * EXP) / sum((stemwood_all + bark_all + branch_all + fol) * EXP),
    p_branch = sum(branch_all * EXP) / sum((stemwood_all + bark_all + branch_all + fol) * EXP),
    p_foliage = sum(fol * EXP) / sum((stemwood_all + bark_all + branch_all + fol) * EXP),
    merchbark_over_merchwood = sum(m_bark * EXP) / sum(m_wood * EXP), state = st)]
  cal[[st]] <- rbind(cal[[st]], pooled, fill = TRUE)
  cat(st, "done\n")
}
O <- rbindlist(out, fill = TRUE); C <- rbindlist(cal, fill = TRUE); K <- rbindlist(chk)
O[, check_AG_minus_merch_other := fia_AG_Tg - merch_Tg - other_Tg]
fwrite(O, "s41_fia_nsvb_components_20261015.csv"); fwrite(C, "s41_fia_nsvb_calibration_20261015.csv"); fwrite(K, "s41_fia_checks_20261015.csv")
print(K); print(O[TYPGRPCD == -1], digits = 4); print(C[TYPGRPCD == -1], digits = 4)
