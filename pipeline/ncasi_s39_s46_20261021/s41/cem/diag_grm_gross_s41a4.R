#!/usr/bin/env Rscript
# s41 step A4 diagnostic: NH 2024 GRM estimator, per component state totals
# (Tg/yr) under alternative terms, with join losses. Aggregates only.
suppressPackageStartupMessages(library(data.table))
FIA <- path.expand("~/fia_data"); st <- "NH"; LB_TG <- 4.53592e-10
f <- function(tb) file.path(FIA, sprintf("%s_%s.csv", st, tb))
plt <- fread(f("PLOT"), select = c("CN","REMPER"), colClasses = list(character = "CN")); setnames(plt, "CN", "PLT_CN")
tre <- fread(f("TREE"), select = c("CN","CONDID","DRYBIO_AG","PREV_TRE_CN"), colClasses = list(character = c("CN","PREV_TRE_CN")))
gc_ <- fread(f("TREE_GRM_COMPONENT"), select = c("TRE_CN","PLT_CN","SUBP_COMPONENT_AL_FOREST","SUBP_SUBPTYP_GRM_AL_FOREST","SUBP_TPAGROW_UNADJ_AL_FOREST","SUBP_TPAMORT_UNADJ_AL_FOREST","SUBP_TPAREMV_UNADJ_AL_FOREST"), colClasses = list(character = c("TRE_CN","PLT_CN")))
setnames(gc_, c("TRE_CN","PLT_CN","comp","typ","tg","tm","tr"))
be <- fread(f("TREE_GRM_BEGIN"), select = c("TRE_CN","DRYBIO_AG"), colClasses = list(character = "TRE_CN")); setnames(be, 2, "b")
mi <- fread(f("TREE_GRM_MIDPT"), select = c("TRE_CN","DRYBIO_AG"), colClasses = list(character = "TRE_CN")); setnames(mi, 2, "m")
x <- mi[be[gc_, on = "TRE_CN"], on = "TRE_CN"]
x <- tre[, .(TRE_CN = CN, CONDID, e = DRYBIO_AG)][x, on = "TRE_CN"]
x <- plt[x, on = "PLT_CN"]
peg <- fread(f("POP_EVAL_GRP"), colClasses = list(character = "CN"))
pe  <- fread(f("POP_EVAL"), colClasses = list(character = c("CN","EVAL_GRP_CN")))
pet <- fread(f("POP_EVAL_TYP"), colClasses = list(character = c("EVAL_CN","EVAL_GRP_CN")))
ev <- merge(pet[, .(EVAL_CN, EVAL_TYP)], pe[EVAL_GRP_CN %in% peg[EVAL_GRP == 332024, CN], .(CN, EVALID)], by.x = "EVAL_CN", by.y = "CN")
id <- ev[EVAL_TYP == "EXPGROW", EVALID][1]
ps <- fread(f("POP_STRATUM"), colClasses = list(character = "CN"))
ppsa <- fread(f("POP_PLOT_STRATUM_ASSGN"), select = c("PLT_CN","STRATUM_CN","EVALID"), colClasses = list(character = c("PLT_CN","STRATUM_CN")))
w <- unique(ppsa[EVALID == id][ps[, .(STRATUM_CN = CN, EXPNS, A1 = ADJ_FACTOR_SUBP, A2 = ADJ_FACTOR_MICR, A3 = ADJ_FACTOR_MACR)], on = "STRATUM_CN", nomatch = NULL], by = "PLT_CN")
y <- w[x, on = "PLT_CN", nomatch = NULL][typ %in% 1:3]
y[, adj := fifelse(typ == 1, A1, fifelse(typ == 2, A2, A3))]
for (v in c("b","m","e","tg","tm","tr")) set(y, which(is.na(y[[v]])), v, 0)
cat(sprintf("EVALID %s; rows %d; CONDID NA %d; REMPER NA or 0 %d\n", id, nrow(y), sum(is.na(y$CONDID)), sum(is.na(y$REMPER) | y$REMPER == 0)))
y[, R := fifelse(is.na(REMPER) | REMPER == 0, NA_real_, REMPER)]
s <- y[, .(n = .N,
           g_e_b = sum(EXPNS * adj * tg * (e - b) / R, na.rm = TRUE) * LB_TG,
           g_e   = sum(EXPNS * adj * tg * e / R, na.rm = TRUE) * LB_TG,
           g_m_b = sum(EXPNS * adj * tg * (m - b) / R, na.rm = TRUE) * LB_TG,
           g_m   = sum(EXPNS * adj * tg * m / R, na.rm = TRUE) * LB_TG,
           g_e_m = sum(EXPNS * adj * tg * (e - m) / R, na.rm = TRUE) * LB_TG,
           mort_ann = sum(EXPNS * adj * tm * m, na.rm = TRUE) * LB_TG,
           remv_ann = sum(EXPNS * adj * tr * m, na.rm = TRUE) * LB_TG,
           tg_b_R = sum(EXPNS * adj * tg * b / R, na.rm = TRUE) * LB_TG), by = comp]
print(s)
cat("targets NH gross 8.2526 mort 2.7822 net 5.4704\n")
