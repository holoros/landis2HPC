#!/usr/bin/env Rscript
# s45 Track K (post unblinding follow-on, not gate eligible): mechanism check (fraction of module
# loss removed by the netting, by state and agent class, with and without per subject floors),
# Maine class 10 budworm share, valuation mismatch (time of kill vs cycle midpoint), ADJ mismatch,
# and coverage counts. Usage: Rscript nd_summary_s45.R <ST> <CFG> <EVAL_YEAR>
# Expansion as the registered scorer version A: EXPNS x condition adj of the EXPVOL evaluation of
# EVAL_YEAR, own state rows, mean over sims. Writes state aggregates only.
suppressPackageStartupMessages(library(data.table))
A <- commandArgs(trailingOnly = TRUE); ST <- A[1]; CFG <- A[2]; EY <- as.integer(A[3])
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor"
W41 <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem"
FIA <- path.expand("~/fia_data"); LB_TG <- 4.53592e-10
ND <- 4.5359237e-4 / 0.40468564; CYC <- 5
SC <- c(ME=23,NH=33,VT=50,MI=26,WI=55,MN=27); sc <- SC[[ST]]
f <- function(tb) file.path(FIA, sprintf("%s_%s.csv", ST, tb))
fl <- list.files(file.path(T, "work", "diag", sprintf("%s_%s", CFG, ST)), full.names = TRUE)
d <- rbindlist(lapply(fl, readRDS))
cat(sprintf("diag files %d rows %d\n", length(fl), nrow(d)))
d <- d[STATECD == sc]
nS <- uniqueN(d$sim)
# weights
plt <- fread(f("PLOT"), select = c("CN","STATECD","COUNTYCD","PLOT"), colClasses = list(character = "CN"))
plt[, loc_key := paste(STATECD, COUNTYCD, PLOT, sep = "_")]
cnd <- fread(f("COND"), select = c("PLT_CN","CONDID","COND_STATUS_CD"), colClasses = list(character = "PLT_CN"))
peg <- fread(f("POP_EVAL_GRP"), colClasses = list(character = "CN"))
pe  <- fread(f("POP_EVAL"), colClasses = list(character = c("CN","EVAL_GRP_CN")))
pet <- fread(f("POP_EVAL_TYP"), colClasses = list(character = c("EVAL_CN","EVAL_GRP_CN")))
ev  <- merge(pet[, .(EVAL_CN, EVAL_TYP)], pe[EVAL_GRP_CN %in% peg[EVAL_GRP == sc * 10000 + EY, CN], .(CN, EVALID)], by.x = "EVAL_CN", by.y = "CN")
ps   <- fread(f("POP_STRATUM"), colClasses = list(character = "CN"))
ppsa <- fread(f("POP_PLOT_STRATUM_ASSGN"), select = c("PLT_CN","STRATUM_CN","EVALID"), colClasses = list(character = c("PLT_CN","STRATUM_CN")))
id <- ev[EVAL_TYP == "EXPVOL", EVALID][1]
wv <- unique(ppsa[EVALID == id][ps[, .(STRATUM_CN = CN, EXPNS, A1 = ADJ_FACTOR_SUBP, A2 = ADJ_FACTOR_MICR, A3 = ADJ_FACTOR_MACR)], on = "STRATUM_CN", nomatch = NULL], by = "PLT_CN")
stk <- readRDS(file.path(W41, "work", sprintf("stock_cond_%s.rds", ST)))
ec <- merge(cnd[COND_STATUS_CD == 1, .(PLT_CN, CONDID = as.integer(CONDID))], wv, by = "PLT_CN")
ec <- plt[, .(PLT_CN = CN, loc_key)][ec, on = "PLT_CN"]
ec <- merge(ec, stk[, .(PLT_CN, CONDID = as.integer(CONDID), s1, s2, s3)], by = c("PLT_CN","CONDID"), all.x = TRUE)
for (v in c("s1","s2","s3")) set(ec, which(is.na(ec[[v]])), v, 0)
ec[, adj := fifelse(s1 + s2 + s3 > 0, (s1 * A1 + s2 * A2 + s3 * A3) / (s1 + s2 + s3), A1)]
ec <- unique(ec[, .(loc_key, CONDID, EXPNS, adj)], by = c("loc_key","CONDID"))
d[, loc_key := paste(as.integer(STATECD), as.integer(COUNTYCD), as.integer(PLOT), sep = "_")]
d[, CONDID := as.integer(CONDID)]
d <- ec[d, on = c("loc_key","CONDID"), nomatch = NULL]
d[, w := EXPNS * adj / nS]
um <- fcoalesce(as.logical(d$was_unmatched), FALSE)
out <- list()
for (k in c("10","50","30")) {
  Lpa <- d$B * d[[paste0("a", k)]]
  rem <- Lpa * (1 - d[[paste0("s", k)]])
  Dpa <- fifelse(d$cp_ok, d[[paste0("D", k)]] / ND * d$cp * CYC, 0)
  sL <- sum(d$w * Lpa); sR <- sum(d$w * rem); sD <- sum(d$w * Dpa)
  out[[k]] <- data.table(class = k, module_loss_Tgyr = sL * LB_TG / 10, removed_floor_Tgyr = sR * LB_TG / 10,
                         donor_mort_all_subjects_Tgyr = sD * LB_TG / 10,
                         frac_removed_floor = if (sL > 0) sR / sL else NA_real_,
                         frac_removed_aggregate = if (sL > 0) min(sL, sD) / sL else NA_real_)
}
o <- rbindlist(out)
tot <- o[, .(class = "all", module_loss_Tgyr = sum(module_loss_Tgyr), removed_floor_Tgyr = sum(removed_floor_Tgyr),
             donor_mort_all_subjects_Tgyr = sum(donor_mort_all_subjects_Tgyr))]
tot[, `:=`(frac_removed_floor = removed_floor_Tgyr / module_loss_Tgyr,
           frac_removed_aggregate = min(module_loss_Tgyr, donor_mort_all_subjects_Tgyr) / module_loss_Tgyr)]
o <- rbind(o, tot)
o[, share_of_module_loss := module_loss_Tgyr / tot$module_loss_Tgyr]
o[, `:=`(label = "post unblinding follow-on, not gate eligible", state = ST, config = CFG)]
setcolorder(o, c("label","state","config"))
# valuation mismatch: non harvested matched disturbed rows; midpoint value (pre + kill value) / 2
hv <- fcoalesce(as.logical(d$was_harvested), FALSE)
dl <- d$B * (1 - d$red_old)
sel <- !hv & !um & dl > 0
Bmid <- (d$pre_drybio_ag + d$B) / 2
vm <- data.table(label = "post unblinding follow-on, not gate eligible", state = ST, config = CFG,
  loss_at_kill_Tgyr = sum((d$w * dl)[sel]) * LB_TG / 10,
  loss_at_midpoint_Tgyr = sum((d$w * Bmid * (1 - d$red_old))[sel]) * LB_TG / 10,
  share_module_loss_on_harvested_or_unmatched = sum((d$w * dl)[!sel & dl > 0]) / sum((d$w * dl)[dl > 0]))
vm[, kill_over_midpoint := loss_at_kill_Tgyr / loss_at_midpoint_Tgyr]
cov <- data.table(label = "post unblinding follow-on, not gate eligible", state = ST, config = CFG, rows = nrow(d),
  share_rows_disturbed = mean(d$red_old < 1), share_matched_rows_with_donor_record = mean(d$has_donor[!um]),
  share_disturbed_matched_rows_with_donor_record = mean(d$has_donor[!um & d$red_old < 1]),
  share_rows_condprop_invalid = mean(!d$cp_ok),
  share_rows_any_scale_below1 = mean(d$s10 < 1 | d$s50 < 1 | d$s30 < 1),
  subject_adj_lossweighted = sum((d$w * dl * d$adj)[dl > 0]) / sum((d$w * dl)[dl > 0]),
  me_class10_budworm_share_of_module_class10 = if (ST == "ME") 1 else NA_real_)
fwrite(o,   file.path(T, "out", sprintf("netfrac_%s_%s_postunblind_followon_not_gate_eligible.csv", ST, CFG)))
fwrite(vm,  file.path(T, "out", sprintf("valuation_%s_%s_postunblind_followon_not_gate_eligible.csv", ST, CFG)))
fwrite(cov, file.path(T, "out", sprintf("coverage_%s_%s_postunblind_followon_not_gate_eligible.csv", ST, CFG)))
print(o); print(t(vm)); print(t(cov))
