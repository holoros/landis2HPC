#!/usr/bin/env Rscript
# s41 CEM gate, step A (16 Oct 2026). FIA side, biomass (DRYBIO_AG, NSVB).
# 1. Per condition GRM components (gross, mortality, net; lb/ac over REMPER,
#    unadjusted TPA, split by GRM subplot type) for every remeasured T2 plot in
#    the six target states and the engine donor states. Saved as RDS on
#    Cardinal only (identity keyed; never downloaded).
# 2. Per condition live stock split by adjustment class.
# 3. Reproduces EVALIDator 2024 state totals (snum 10, 1311, 335, 311) with the
#    same tables, as an estimator check. Only state aggregates are written to
#    the out folder.
# Component rules (EVALIDator AL_FOREST pattern): SURVIVOR END-BEGIN; INGROWTH
# END; REVERSION1/2 END-MIDPT; MORTALITY1, CUT1, DIVERSION1 MIDPT-BEGIN;
# MORTALITY2, CUT2, DIVERSION2 MIDPT. Gross = sum TPAGROW x term. Mortality =
# sum TPAMORT x MIDPT on MORTALITY1/2. Net = gross - mortality.
suppressPackageStartupMessages(library(data.table))
FIA <- path.expand("~/fia_data")
W   <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem"
dir.create(file.path(W, "work"), showWarnings = FALSE)
dir.create(file.path(W, "out"),  showWarnings = FALSE)
LB_TG <- 4.53592e-10
SC <- c(ME=23,NH=33,VT=50,MI=26,WI=55,MN=27,NY=36,MA=25,CT=9,RI=44,IA=19,IL=17,OH=39,IN=18)
TARGET <- c("ME","NH","VT","MI","WI","MN")
f <- function(st, tb) file.path(FIA, sprintf("%s_%s.csv", st, tb))

out <- list()
for (st in names(SC)) {
  cat("====", st, "====\n")
  plt <- fread(f(st,"PLOT"), select = c("CN","STATECD","COUNTYCD","PLOT","INVYR","REMPER","MACRO_BREAKPOINT_DIA"),
               colClasses = list(character = "CN"))
  setnames(plt, "CN", "PLT_CN")
  cnd <- fread(f(st,"COND"), select = c("PLT_CN","CONDID","COND_STATUS_CD","CONDPROP_UNADJ"),
               colClasses = list(character = "PLT_CN"))
  tre <- fread(f(st,"TREE"), select = c("CN","PLT_CN","CONDID","STATUSCD","DIA","TPA_UNADJ","DRYBIO_AG"),
               colClasses = list(character = c("CN","PLT_CN")))
  # ---- stock per condition by adjustment class
  lv <- tre[STATUSCD == 1 & DIA >= 1 & !is.na(DRYBIO_AG)]
  lv <- plt[, .(PLT_CN, MBD = MACRO_BREAKPOINT_DIA)][lv, on = "PLT_CN"]
  lv[, cls := fifelse(DIA < 5, 2L, fifelse(!is.na(MBD) & DIA >= MBD, 3L, 1L))]
  stk <- dcast(lv[, .(v = sum(TPA_UNADJ * DRYBIO_AG)), by = .(PLT_CN, CONDID, cls)],
               PLT_CN + CONDID ~ cls, value.var = "v", fill = 0)
  for (k in c("1","2","3")) if (!k %in% names(stk)) stk[, (k) := 0]
  setnames(stk, c("1","2","3"), c("s1","s2","s3"))
  # ---- GRM components per T2 condition
  gc_ <- fread(f(st,"TREE_GRM_COMPONENT"),
               select = c("TRE_CN","PLT_CN","SUBP_COMPONENT_AL_FOREST","SUBP_SUBPTYP_GRM_AL_FOREST",
                          "SUBP_TPAGROW_UNADJ_AL_FOREST","SUBP_TPAMORT_UNADJ_AL_FOREST"),
               colClasses = list(character = c("TRE_CN","PLT_CN")))
  setnames(gc_, c("TRE_CN","PLT_CN","comp","typ","tg","tm"))
  gc_ <- gc_[!is.na(typ) & typ > 0 & !is.na(comp) & comp != "NOT USED"]
  be <- fread(f(st,"TREE_GRM_BEGIN"), select = c("TRE_CN","DRYBIO_AG"), colClasses = list(character = "TRE_CN"))
  mi <- fread(f(st,"TREE_GRM_MIDPT"), select = c("TRE_CN","DRYBIO_AG"), colClasses = list(character = "TRE_CN"))
  setnames(be, "DRYBIO_AG", "b"); setnames(mi, "DRYBIO_AG", "m")
  gc_ <- be[gc_, on = "TRE_CN"]; gc_ <- mi[gc_, on = "TRE_CN"]
  gc_ <- tre[, .(TRE_CN = CN, CONDID, e = DRYBIO_AG)][gc_, on = "TRE_CN"]
  for (v in c("b","m","e","tg","tm")) set(gc_, which(is.na(gc_[[v]])), v, 0)
  gc_[, term := fcase(comp == "SURVIVOR", e - b,
                      comp == "INGROWTH", e,
                      comp %chin% c("REVERSION1","REVERSION2"), e - m,
                      comp %chin% c("MORTALITY1","CUT1","DIVERSION1"), m - b,
                      comp %chin% c("MORTALITY2","CUT2","DIVERSION2"), m,
                      default = 0)]
  gc_[, g := tg * term]
  gc_[, mo := fifelse(comp %chin% c("MORTALITY1","MORTALITY2"), tm * m, 0)]
  cc <- gc_[!is.na(CONDID), .(g = sum(g), mo = sum(mo)), by = .(PLT_CN, CONDID, typ)]
  cw <- dcast(cc, PLT_CN + CONDID ~ typ, value.var = c("g","mo"), fill = 0)
  for (k in c("g_1","g_2","g_3","mo_1","mo_2","mo_3")) if (!k %in% names(cw)) cw[, (k) := 0]
  cw <- plt[, .(PLT_CN, REMPER, INVYR)][cw, on = "PLT_CN"]
  cw[, `:=`(gross_tot = g_1 + g_2 + g_3, mort_tot = mo_1 + mo_2 + mo_3)]
  cw[, net_tot := gross_tot - mort_tot]
  cw[, STATE := st]
  saveRDS(cw,  file.path(W, "work", sprintf("grm_cond_%s.rds", st)))
  saveRDS(stk, file.path(W, "work", sprintf("stock_cond_%s.rds", st)))
  cat(sprintf("  GRM conditions %d, stock conditions %d\n", nrow(cw), nrow(stk)))
  if (!st %in% TARGET) next
  # ---- estimator check against EVALIDator 2024
  peg <- fread(f(st,"POP_EVAL_GRP"), colClasses = list(character = "CN"))
  pe  <- fread(f(st,"POP_EVAL"), colClasses = list(character = c("CN","EVAL_GRP_CN")))
  pet <- fread(f(st,"POP_EVAL_TYP"), colClasses = list(character = c("EVAL_CN","EVAL_GRP_CN")))
  grp_cn <- peg[EVAL_GRP == SC[[st]] * 10000 + 2024, CN]
  ev <- merge(pet[, .(EVAL_CN, EVAL_TYP)], pe[EVAL_GRP_CN %in% grp_cn, .(CN, EVALID)], by.x = "EVAL_CN", by.y = "CN")
  ps   <- fread(f(st,"POP_STRATUM"), colClasses = list(character = "CN"))
  ppsa <- fread(f(st,"POP_PLOT_STRATUM_ASSGN"), select = c("PLT_CN","STRATUM_CN","EVALID"),
                colClasses = list(character = c("PLT_CN","STRATUM_CN")))
  wts <- function(typ) {
    id <- ev[EVAL_TYP == typ, EVALID][1]
    w <- ppsa[EVALID == id][ps[, .(STRATUM_CN = CN, EXPNS, ADJ_FACTOR_SUBP, ADJ_FACTOR_MICR, ADJ_FACTOR_MACR)],
                            on = "STRATUM_CN", nomatch = NULL]
    list(id = id, w = unique(w, by = "PLT_CN"))
  }
  wv <- wts("EXPVOL"); wg <- wts("EXPGROW")
  fc <- cnd[COND_STATUS_CD == 1, .(PLT_CN, CONDID)]
  s <- merge(stk, fc, by = c("PLT_CN","CONDID"))[wv$w, on = "PLT_CN", nomatch = NULL]
  stock <- s[, sum(EXPNS * (s1 * ADJ_FACTOR_SUBP + s2 * ADJ_FACTOR_MICR + s3 * ADJ_FACTOR_MACR))] * LB_TG
  gg <- cw[wg$w, on = "PLT_CN", nomatch = NULL][REMPER > 0]
  gross <- gg[, sum(EXPNS * (g_1 * ADJ_FACTOR_SUBP + g_2 * ADJ_FACTOR_MICR + g_3 * ADJ_FACTOR_MACR) / REMPER)] * LB_TG
  mort  <- gg[, sum(EXPNS * (mo_1 * ADJ_FACTOR_SUBP + mo_2 * ADJ_FACTOR_MICR + mo_3 * ADJ_FACTOR_MACR) / REMPER)] * LB_TG
  out[[st]] <- data.table(state = st, evalid_vol = wv$id, evalid_grow = wg$id,
                          n_plots_vol = nrow(wv$w), n_plots_grow = nrow(wg$w),
                          stock_Tg = stock, gross_Tgyr = gross, mort_Tgyr = mort, net_Tgyr = gross - mort)
  print(out[[st]])
}
res <- rbindlist(out)
tg <- data.table(state = c("NH","VT","MI","WI","ME","MN"),
                 t_stock = c(314.2606,294.27,1050.96,814.17,762.4297,633.4494),
                 t_gross = c(8.2526,7.609,31.774,29.041,25.6128,25.1058),
                 t_mort  = c(2.7822,2.986,13.045,10.126,9.4943,10.6370),
                 t_net   = c(5.4704,4.623,18.729,18.914,16.1185,14.4688))
res <- tg[res, on = "state"]
res[, `:=`(r_stock = stock_Tg / t_stock, r_gross = gross_Tgyr / t_gross,
           r_mort = mort_Tgyr / t_mort, r_net = net_Tgyr / t_net)]
fwrite(res, file.path(W, "out", "obs_estimator_check_20261016.csv"))
print(res[, .(state, r_stock, r_gross, r_mort, r_net)])
cat("STEP_A_DONE\n")
