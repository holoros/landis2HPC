#!/usr/bin/env Rscript
# Track I H1 step a: donor condition mortality split by T2 TREE AGENTCD class.
# Same GRM construction as s41 obs_grm_2024_s41a6.R (MICR_*_AL_FOREST, MIDPT
# DRYBIO_AG, mo = TPAMORT x midpoint biomass, annual lb/ac unadjusted, x REMPER).
# Class: floor(AGENTCD/10)*10 in 10,20,30,40,50 = disturbance; else other
# (60 vegetation, 70 unknown, 80 silvicultural, 0/NA). Writes work/agent_cond_<ST>.rds
# (restricted keys stay on Cardinal) and an aggregate check CSV.
suppressPackageStartupMessages(library(data.table))
FIA <- path.expand("~/fia_data"); T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism"
W41 <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem"
st <- commandArgs(trailingOnly = TRUE)[1]
f <- function(tb) file.path(FIA, sprintf("%s_%s.csv", st, tb))
plt <- fread(f("PLOT"), select = c("CN","REMPER"), colClasses = list(character = "CN")); setnames(plt, "CN", "PLT_CN")
tre <- fread(f("TREE"), select = c("CN","CONDID","AGENTCD"), colClasses = list(character = "CN"))
gc_ <- fread(f("TREE_GRM_COMPONENT"), select = c("TRE_CN","PLT_CN","MICR_COMPONENT_AL_FOREST","MICR_SUBPTYP_GRM_AL_FOREST","MICR_TPAMORT_UNADJ_AL_FOREST"),
             colClasses = list(character = c("TRE_CN","PLT_CN")))
setnames(gc_, c("TRE_CN","PLT_CN","comp","typ","tm"))
gc_ <- gc_[!is.na(typ) & typ > 0 & comp %chin% c("MORTALITY1","MORTALITY2")]
mi <- fread(f("TREE_GRM_MIDPT"), select = c("TRE_CN","DRYBIO_AG"), colClasses = list(character = "TRE_CN")); setnames(mi, "DRYBIO_AG", "m")
gc_ <- mi[gc_, on = "TRE_CN"]
gc_ <- tre[, .(TRE_CN = CN, CONDID, AGENTCD)][gc_, on = "TRE_CN"]
for (v in c("m","tm")) set(gc_, which(is.na(gc_[[v]])), v, 0)
gc_ <- plt[gc_, on = "PLT_CN"][!is.na(REMPER) & REMPER > 0 & !is.na(CONDID)]
gc_[, ac := floor(fcoalesce(as.numeric(AGENTCD), 0) / 10) * 10]
gc_[, cls := fifelse(ac %in% c(10,20,30,40,50), sprintf("a%02d", as.integer(ac)), "oth")]
gc_[, mo := tm * m * REMPER]
ac <- dcast(gc_[, .(v = sum(mo)), by = .(PLT_CN, CONDID, cls)], PLT_CN + CONDID ~ cls, value.var = "v", fill = 0)
for (k in c("a10","a20","a30","a40","a50","oth")) if (!k %in% names(ac)) ac[, (k) := 0]
ac[, m_dist := a10 + a20 + a30 + a40 + a50][, m_all := m_dist + oth]
saveRDS(ac, file.path(T, "work", sprintf("agent_cond_%s.rds", st)))
g41 <- readRDS(file.path(W41, "work", sprintf("grm_cond_%s.rds", st)))
chk <- merge(g41[, .(PLT_CN, CONDID = as.integer(CONDID), mort_tot)], ac[, .(PLT_CN, CONDID = as.integer(CONDID), m_all)], by = c("PLT_CN","CONDID"), all = TRUE)
for (v in c("mort_tot","m_all")) set(chk, which(is.na(chk[[v]])), v, 0)
res <- data.table(state = st, n_cond = nrow(ac), s41_mort_sum = sum(chk$mort_tot), agent_mort_sum = sum(chk$m_all),
  max_abs_cond_diff = max(abs(chk$mort_tot - chk$m_all)),
  share_a10 = sum(ac$a10)/sum(ac$m_all), share_a20 = sum(ac$a20)/sum(ac$m_all), share_a30 = sum(ac$a30)/sum(ac$m_all),
  share_a40 = sum(ac$a40)/sum(ac$m_all), share_a50 = sum(ac$a50)/sum(ac$m_all), share_oth = sum(ac$oth)/sum(ac$m_all),
  share_agent_na_or0 = gc_[, sum(mo[is.na(AGENTCD) | AGENTCD == 0]) / sum(mo)])
fwrite(res, file.path(T, "out", sprintf("h1a_agent_check_%s.csv", st)))
print(res)
