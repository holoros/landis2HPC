## s46 Track L: NSVB component shares by state, forest type group (TYPGRPCD = inventory FT code) and 10 yr stand age class
## (COND.STDAGE), design based ratio of totals on the current evaluation (EVALID <ST>2401), as s41_fia_nsvb_components_v2.R.
## merch  = DRYBIO_BOLE + DRYBIO_BOLE_BARK of live trees DIA >= 5 in (12.7 cm), stump to 4 in (10.2 cm) top
## other  = DRYBIO_AG basis remainder: stump, top and branches of DIA >= 5, all stem, bark and branch of 1 <= DIA < 5
## foliage= DRYBIO_FOLIAGE (not in DRYBIO_AG), reported as foliage / (merch + other)
## Writes AGGREGATES ONLY (no PLT_CN, no coordinates). usage: Rscript nsvb_shares.R OUTCSV
suppressPackageStartupMessages(library(data.table))
args <- commandArgs(TRUE)
DM  <- "/fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006"
REF <- fread("/users/PUOM0008/crsfaaron/fia_cem_projections/config/REF_FOREST_TYPE.csv")
ref <- unique(REF[, .(FORTYPCD = as.integer(VALUE), TYPGRPCD = as.integer(TYPGRPCD))])
SC  <- c(ME = 23, NH = 33, VT = 50, MI = 26, WI = 55, MN = 27)
out <- list()
for (st in names(SC)) {
  ev <- SC[[st]] * 10000 + 2401
  ppsa <- fread(file.path(DM, paste0(st, "_POP_PLOT_STRATUM_ASSGN.csv")), select = c("PLT_CN", "STRATUM_CN", "EVALID"))[EVALID == ev]
  ps <- fread(file.path(DM, paste0(st, "_POP_STRATUM.csv")), select = c("CN", "EXPNS", "ADJ_FACTOR_MICR", "ADJ_FACTOR_SUBP", "ADJ_FACTOR_MACR"))
  ppsa <- merge(ppsa, ps, by.x = "STRATUM_CN", by.y = "CN")
  pl <- fread(file.path(DM, paste0(st, "_PLOT.csv")), select = c("CN", "MACRO_BREAKPOINT_DIA"))
  ppsa <- merge(ppsa, pl, by.x = "PLT_CN", by.y = "CN", all.x = TRUE)
  co <- fread(file.path(DM, paste0(st, "_COND.csv")), select = c("PLT_CN", "CONDID", "COND_STATUS_CD", "FORTYPCD", "STDAGE"))
  co <- merge(co[PLT_CN %in% ppsa$PLT_CN & COND_STATUS_CD == 1], ref, by = "FORTYPCD", all.x = TRUE)
  tcols <- c("PLT_CN", "CONDID", "STATUSCD", "DIA", "TPA_UNADJ", "DRYBIO_AG", "DRYBIO_STEM", "DRYBIO_STEM_BARK",
             "DRYBIO_BOLE", "DRYBIO_BOLE_BARK", "DRYBIO_BRANCH", "DRYBIO_FOLIAGE")
  tr <- fread(file.path(DM, paste0(st, "_TREE.csv")), select = tcols)
  tr <- tr[PLT_CN %in% ppsa$PLT_CN & STATUSCD == 1 & !is.na(DIA) & DIA >= 1 & !is.na(TPA_UNADJ)]
  tr <- merge(tr, co[, .(PLT_CN, CONDID, TYPGRPCD, STDAGE)], by = c("PLT_CN", "CONDID"))
  tr <- merge(tr, ppsa[, .(PLT_CN, EXPNS, ADJ_FACTOR_MICR, ADJ_FACTOR_SUBP, ADJ_FACTOR_MACR, MACRO_BREAKPOINT_DIA)], by = "PLT_CN")
  tr[, ADJ := fifelse(DIA < 5, ADJ_FACTOR_MICR, fifelse(is.na(MACRO_BREAKPOINT_DIA) | DIA < MACRO_BREAKPOINT_DIA, ADJ_FACTOR_SUBP, ADJ_FACTOR_MACR))]
  tr[, EXP := TPA_UNADJ * ADJ * EXPNS]
  for (v in tcols[6:length(tcols)]) set(tr, which(is.na(tr[[v]])), v, 0)
  tr[, big := DIA >= 5]
  tr[, merch := fifelse(big, DRYBIO_BOLE + DRYBIO_BOLE_BARK, 0)]
  tr[, mo := DRYBIO_STEM + DRYBIO_STEM_BARK + DRYBIO_BRANCH]
  tr <- tr[!is.na(STDAGE) & STDAGE >= 0 & !is.na(TYPGRPCD)]
  tr[, aclass := pmin(floor(STDAGE / 10), 20L)]
  cd <- tr[, .(merch = sum(EXP * merch), mo = sum(EXP * mo), ag = sum(EXP * DRYBIO_AG), fol = sum(EXP * DRYBIO_FOLIAGE),
               w = sum(EXP * mo), age = STDAGE[1]), by = .(PLT_CN, CONDID, TYPGRPCD, aclass)]
  agg <- cd[, .(n_cond = .N, merch = sum(merch), mo = sum(mo), ag = sum(ag), fol = sum(fol), node_age = sum(w * age) / sum(w)), by = .(TYPGRPCD, aclass)]
  agg[, `:=`(state = st, merch_share = merch / mo, foliage_over_mo = fol / mo, ag_over_mo = ag / mo)]
  out[[st]] <- agg[, .(state, TYPGRPCD, aclass, n_cond, node_age, merch_share, foliage_over_mo, ag_over_mo, mo_total_tons = mo / 2000)]
}
O <- rbindlist(out); setorder(O, state, TYPGRPCD, aclass)
fwrite(O, args[1]); print(O[, .(cells = .N, min_n = min(n_cond), ag_over_mo_min = min(ag_over_mo), ag_over_mo_max = max(ag_over_mo)), by = state])
