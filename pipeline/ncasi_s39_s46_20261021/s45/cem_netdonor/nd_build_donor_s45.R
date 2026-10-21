#!/usr/bin/env Rscript
# s45 Track K (post unblinding follow-on, not gate eligible): build per donor condition
# disturbance agent mortality table and run the snum 335 check (v3 item 1, v4 item 3).
# ADJ factors per plot: the state's 2024 EXPGROW evaluation when the plot is in it, otherwise
# the EXPGROW evaluation with the latest END_INVYR that contains the plot.
# Writes work/donor_mort_<ST>.rds (identity keyed, stays on Cardinal) and, for the six target
# states, out/snum335_check_<ST>_postunblind_followon_not_gate_eligible.csv (state aggregates only).
suppressPackageStartupMessages(library(data.table))
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor"
source(file.path(T, "engine_k", "R", "16_netdonor_fns.R"))
FIA <- path.expand("~/fia_data"); LB_TG <- 4.53592e-10
SC <- c(ME=23,NH=33,VT=50,MI=26,WI=55,MN=27,NY=36,MA=25,CT=9,RI=44,IA=19,IL=17,OH=39,IN=18)
TMORT <- c(NH=2.7822, VT=2.9861, MI=13.0453, WI=10.1263, ME=9.4943, MN=10.6370)  # EVALIDator 2024 snum 335, Tg/yr
st <- commandArgs(trailingOnly = TRUE)[1]
f <- function(tb) file.path(FIA, sprintf("%s_%s.csv", st, tb))
plt <- fread(f("PLOT"), select = c("CN","REMPER"), colClasses = list(character = "CN")); setnames(plt, "CN", "PLT_CN")
cnd <- fread(f("COND"), select = c("PLT_CN","CONDID","CONDPROP_UNADJ"), colClasses = list(character = "PLT_CN"))
tre <- fread(f("TREE"), select = c("CN","CONDID","AGENTCD","PREV_TRE_CN","DAMAGE_AGENT_CD1","DAMAGE_AGENT_CD2","DAMAGE_AGENT_CD3"),
             colClasses = list(character = c("CN","PREV_TRE_CN")))
gc_ <- fread(f("TREE_GRM_COMPONENT"), select = c("TRE_CN","PLT_CN","MICR_COMPONENT_AL_FOREST","MICR_SUBPTYP_GRM_AL_FOREST","MICR_TPAMORT_UNADJ_AL_FOREST"),
             colClasses = list(character = c("TRE_CN","PLT_CN")))
setnames(gc_, c("TRE_CN","PLT_CN","comp","typ","tm"))
mi <- fread(f("TREE_GRM_MIDPT"), select = c("TRE_CN","DRYBIO_AG"), colClasses = list(character = "TRE_CN")); setnames(mi, "DRYBIO_AG", "m")
# ---- ADJ map
peg <- fread(f("POP_EVAL_GRP"), colClasses = list(character = "CN"))
pe  <- fread(f("POP_EVAL"), select = c("CN","EVAL_GRP_CN","EVALID","END_INVYR"), colClasses = list(character = c("CN","EVAL_GRP_CN")))
pet <- fread(f("POP_EVAL_TYP"), select = c("EVAL_CN","EVAL_TYP"), colClasses = list(character = "EVAL_CN"))
ps   <- fread(f("POP_STRATUM"), select = c("CN","EXPNS","ADJ_FACTOR_SUBP","ADJ_FACTOR_MICR","ADJ_FACTOR_MACR"), colClasses = list(character = "CN"))
ppsa <- fread(f("POP_PLOT_STRATUM_ASSGN"), select = c("PLT_CN","STRATUM_CN","EVALID"), colClasses = list(character = c("PLT_CN","STRATUM_CN")))
eg <- merge(pet[EVAL_TYP == "EXPGROW"], pe, by.x = "EVAL_CN", by.y = "CN")
id24 <- eg[EVAL_GRP_CN %in% peg[EVAL_GRP == SC[[st]] * 10000 + 2024, CN], EVALID][1]
pa <- merge(ppsa[EVALID %in% eg$EVALID], eg[, .(EVALID, END_INVYR)], by = "EVALID")
pa <- merge(pa, ps[, .(STRATUM_CN = CN, EXPNS, A1 = ADJ_FACTOR_SUBP, A2 = ADJ_FACTOR_MICR, A3 = ADJ_FACTOR_MACR)], by = "STRATUM_CN")
pa[, pri := fifelse(!is.na(id24) & EVALID == id24, 1e6, END_INVYR)]
setorder(pa, PLT_CN, -pri)
adj <- unique(pa, by = "PLT_CN")[, .(PLT_CN, A1, A2, A3, adj_evalid = EVALID)]
cat(sprintf("%s: EXPGROW evaluations %d; 2024 EXPGROW EVALID %s; plots with ADJ %d\n", st, uniqueN(eg$EVALID), id24, nrow(adj)))
w <- nd_build_donor(gc_, mi, tre[, .(TRE_CN = CN, CONDID, AGENTCD)], plt, adj[, .(PLT_CN, A1, A2, A3)], cnd)
w[, STATE := st]
saveRDS(w, file.path(T, "work", sprintf("donor_mort_%s.rds", st)))
cat(sprintf("%s: donor conditions %d; with CONDPROP ok %.4f; rows with missing ADJ %d\n", st, nrow(w), mean(w$cp_ok), sum(w$n_adj_missing)))
# ---- budworm diagnostic: share of class 10 donor mortality on trees with DAMAGE_AGENT_CD 12040
# (eastern spruce budworm) at T2 or on the T1 tree record (PREV_TRE_CN).
x <- gc_[!is.na(typ) & typ > 0 & comp %chin% c("MORTALITY1","MORTALITY2")]
x <- mi[x, on = "TRE_CN"]; x <- tre[, .(TRE_CN = CN, CONDID, AGENTCD, PREV_TRE_CN, d1 = DAMAGE_AGENT_CD1, d2 = DAMAGE_AGENT_CD2, d3 = DAMAGE_AGENT_CD3)][x, on = "TRE_CN"]
x <- plt[x, on = "PLT_CN"][!is.na(REMPER) & REMPER > 0 & !is.na(CONDID)]
x <- adj[x, on = "PLT_CN"]
for (v in c("m","tm")) set(x, which(is.na(x[[v]])), v, 0)
x[, A := fcase(typ == 1L, A1, typ == 2L, A2, typ == 3L, A3, default = 0)]
x[, v := tm * m * A]
p1 <- tre[, .(PREV_TRE_CN = CN, p1 = DAMAGE_AGENT_CD1, p2 = DAMAGE_AGENT_CD2, p3 = DAMAGE_AGENT_CD3)]
x <- p1[x, on = "PREV_TRE_CN"]
x[, sbw_t2 := (fcoalesce(as.integer(d1), 0L) == 12040L) | (fcoalesce(as.integer(d2), 0L) == 12040L) | (fcoalesce(as.integer(d3), 0L) == 12040L)]
x[, sbw_t1 := (fcoalesce(as.integer(p1), 0L) == 12040L) | (fcoalesce(as.integer(p2), 0L) == 12040L) | (fcoalesce(as.integer(p3), 0L) == 12040L)]
x[, c10 := floor(fcoalesce(as.numeric(AGENTCD), 0) / 10) == 1]
bw <- x[c10 == TRUE, .(state = st, donor_c10_mort_lbacyr_pa = sum(v), share_c10_sbw_t2 = sum(v[sbw_t2]) / sum(v),
                       share_c10_sbw_t1_or_t2 = sum(v[sbw_t2 | sbw_t1]) / sum(v),
                       share_c10_any_damage_code_t2 = sum(v[fcoalesce(as.integer(d1), 0L) > 0]) / sum(v))]
fwrite(bw, file.path(T, "out", sprintf("donor_c10_budworm_%s_postunblind_followon_not_gate_eligible.csv", st)))
# ---- snum 335 check (target states)
if (st %in% names(TMORT)) {
  e24 <- unique(merge(ppsa[EVALID == id24], ps[, .(STRATUM_CN = CN, EXPNS)], by = "STRATUM_CN"), by = "PLT_CN")
  g <- merge(w, e24[, .(PLT_CN, EXPNS)], by = "PLT_CN")
  # identical per donor per condition values: condition area value x CONDPROP x EXPNS (ADJ inside)
  s_ca <- g[, sum((D10_ca + D20_ca + D30_ca + D40_ca + D50_ca + Dexcl_ca) * CONDPROP_UNADJ * EXPNS, na.rm = TRUE)] * LB_TG
  s_pa <- g[, sum(Dall_pa * EXPNS)] * LB_TG
  s_dist <- g[, sum((D10_ca + D20_ca + D30_ca + D40_ca + D50_ca) * CONDPROP_UNADJ * EXPNS, na.rm = TRUE)] * LB_TG
  res <- data.table(label = "post unblinding follow-on, not gate eligible", state = st, evalid_grow_2024 = id24,
                    donor_sum_condarea_Tgyr = s_ca, donor_sum_plotacre_Tgyr = s_pa, evalidator_snum335_Tgyr = TMORT[[st]],
                    ratio = s_ca / TMORT[[st]], pass_1pct = abs(s_ca / TMORT[[st]] - 1) <= 0.01,
                    share_lost_to_condprop = 1 - s_ca / s_pa, donor_dist_10to50_Tgyr = s_dist, dist_share = s_dist / s_ca)
  fwrite(res, file.path(T, "out", sprintf("snum335_check_%s_postunblind_followon_not_gate_eligible.csv", st)))
  print(res)
}
cat("BUILD_DONE\n")
