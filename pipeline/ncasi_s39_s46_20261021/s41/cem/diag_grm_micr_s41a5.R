#!/usr/bin/env Rscript
# s41 step A5 diagnostic: NH 2024 GRM, subplot type tables and the MICR_
# component columns' contribution (Tg/yr). Aggregates only.
suppressPackageStartupMessages(library(data.table))
FIA <- path.expand("~/fia_data"); st <- "NH"; LB_TG <- 4.53592e-10
f <- function(tb) file.path(FIA, sprintf("%s_%s.csv", st, tb))
plt <- fread(f("PLOT"), select = c("CN","REMPER"), colClasses = list(character = "CN")); setnames(plt, "CN", "PLT_CN")
tre <- fread(f("TREE"), select = c("CN","DRYBIO_AG","DIA"), colClasses = list(character = "CN"))
gc_ <- fread(f("TREE_GRM_COMPONENT"), select = c("TRE_CN","PLT_CN","SUBP_COMPONENT_AL_FOREST","SUBP_SUBPTYP_GRM_AL_FOREST","SUBP_TPAGROW_UNADJ_AL_FOREST","SUBP_TPAMORT_UNADJ_AL_FOREST","MICR_COMPONENT_AL_FOREST","MICR_SUBPTYP_GRM_AL_FOREST","MICR_TPAGROW_UNADJ_AL_FOREST","MICR_TPAMORT_UNADJ_AL_FOREST","DIA_BEGIN","DIA_END"), colClasses = list(character = c("TRE_CN","PLT_CN")))
print(gc_[, .N, by = .(SUBP_SUBPTYP_GRM_AL_FOREST)])
print(gc_[, .N, by = .(MICR_SUBPTYP_GRM_AL_FOREST)])
print(gc_[, .N, by = .(SUBP_COMPONENT_AL_FOREST, MICR_COMPONENT_AL_FOREST)][order(-N)][1:15])
be <- fread(f("TREE_GRM_BEGIN"), select = c("TRE_CN","DRYBIO_AG"), colClasses = list(character = "TRE_CN")); setnames(be, 2, "b")
mi <- fread(f("TREE_GRM_MIDPT"), select = c("TRE_CN","DRYBIO_AG"), colClasses = list(character = "TRE_CN")); setnames(mi, 2, "m")
x <- mi[be[gc_, on = "TRE_CN"], on = "TRE_CN"]
x <- tre[, .(TRE_CN = CN, e = DRYBIO_AG)][x, on = "TRE_CN"]
x <- plt[x, on = "PLT_CN"]
peg <- fread(f("POP_EVAL_GRP"), colClasses = list(character = "CN"))
pe  <- fread(f("POP_EVAL"), colClasses = list(character = c("CN","EVAL_GRP_CN")))
pet <- fread(f("POP_EVAL_TYP"), colClasses = list(character = c("EVAL_CN","EVAL_GRP_CN")))
ev <- merge(pet[, .(EVAL_CN, EVAL_TYP)], pe[EVAL_GRP_CN %in% peg[EVAL_GRP == 332024, CN], .(CN, EVALID)], by.x = "EVAL_CN", by.y = "CN")
id <- ev[EVAL_TYP == "EXPGROW", EVALID][1]
ps <- fread(f("POP_STRATUM"), colClasses = list(character = "CN"))
ppsa <- fread(f("POP_PLOT_STRATUM_ASSGN"), select = c("PLT_CN","STRATUM_CN","EVALID"), colClasses = list(character = c("PLT_CN","STRATUM_CN")))
w <- unique(ppsa[EVALID == id][ps[, .(STRATUM_CN = CN, EXPNS, A1 = ADJ_FACTOR_SUBP, A2 = ADJ_FACTOR_MICR, A3 = ADJ_FACTOR_MACR)], on = "STRATUM_CN", nomatch = NULL], by = "PLT_CN")
y <- w[x, on = "PLT_CN", nomatch = NULL]
for (v in c("b","m","e")) set(y, which(is.na(y[[v]])), v, 0)
adjf <- function(t, A1, A2, A3) fifelse(t == 1, A1, fifelse(t == 2, A2, fifelse(t == 3, A3, 0)))
term <- function(comp, e, b, m) fcase(comp == "SURVIVOR", e - b, comp == "INGROWTH", e,
  comp %chin% c("REVERSION1","REVERSION2"), e - m, comp %chin% c("MORTALITY1","CUT1","DIVERSION1"), m - b,
  comp %chin% c("MORTALITY2","CUT2","DIVERSION2"), m, default = 0)
y[, `:=`(aS = adjf(SUBP_SUBPTYP_GRM_AL_FOREST, A1, A2, A3), aM = adjf(MICR_SUBPTYP_GRM_AL_FOREST, A1, A2, A3))]
y[, `:=`(tS = term(SUBP_COMPONENT_AL_FOREST, e, b, m), tM = term(MICR_COMPONENT_AL_FOREST, e, b, m))]
r <- y[, .(gross_SUBP = sum(EXPNS * aS * fcoalesce(SUBP_TPAGROW_UNADJ_AL_FOREST, 0) * tS / REMPER, na.rm = TRUE) * LB_TG,
           gross_MICR = sum(EXPNS * aM * fcoalesce(MICR_TPAGROW_UNADJ_AL_FOREST, 0) * tM / REMPER, na.rm = TRUE) * LB_TG,
           mort_SUBP = sum(EXPNS * aS * fcoalesce(SUBP_TPAMORT_UNADJ_AL_FOREST, 0) * fifelse(SUBP_COMPONENT_AL_FOREST %like% "MORTALITY", m, 0), na.rm = TRUE) * LB_TG,
           mort_MICR = sum(EXPNS * aM * fcoalesce(MICR_TPAMORT_UNADJ_AL_FOREST, 0) * fifelse(MICR_COMPONENT_AL_FOREST %like% "MORTALITY", m, 0), na.rm = TRUE) * LB_TG)]
print(r)
cat("targets NH gross 8.2526 mort 2.7822 net 5.4704\n")
