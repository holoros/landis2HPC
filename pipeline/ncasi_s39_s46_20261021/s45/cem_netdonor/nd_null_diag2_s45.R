#!/usr/bin/env Rscript
# s45 Track K (post unblinding follow-on, not gate eligible): null test diagnosis part 2.
# Cycle 1 donor assignment agreement (before any module or netting code runs in a sim) and NA
# handling. Aggregates only.
suppressPackageStartupMessages(library(data.table))
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor"
S43 <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_ablation/engine_c/output"
ST <- commandArgs(trailingOnly = TRUE)[1]
fd <- function(base, tag) { d <- list.files(base, pattern = sprintf("^%s_[0-9]{8}_%s$", ST, tag), full.names = TRUE); file.path(d, "per_plot_projections.rds") }
r <- as.data.table(readRDS(fd(file.path(T, "engine_kref", "output"), "k20ref_postunblind_followon_not_gate_eligible")))
n <- as.data.table(readRDS(fd(file.path(T, "engine_k", "output"), "k20null_postunblind_followon_not_gate_eligible")))
s <- as.data.table(readRDS(fd(S43, "c00base")))
k <- c("sim","cycle","STATECD","COUNTYCD","PLOT","CONDID")
ag <- function(a, b, nm) {
  a1 <- a[cycle == 1, c(k, "T2_PLT_CN", "d_drybio_ag", "was_harvested"), with = FALSE]
  b1 <- b[cycle == 1, c(k, "T2_PLT_CN", "d_drybio_ag", "was_harvested"), with = FALSE]
  same_order <- identical(a1[, ..k], b1[, ..k])
  m <- merge(a1[, .(sim, STATECD, COUNTYCD, PLOT, CONDID, ta = as.character(T2_PLT_CN), ha = was_harvested)],
             b1[, .(sim, STATECD, COUNTYCD, PLOT, CONDID, tb = as.character(T2_PLT_CN), hb = was_harvested)],
             by = c("sim","STATECD","COUNTYCD","PLOT","CONDID"), allow.cartesian = TRUE)
  data.table(label = "post unblinding follow-on, not gate eligible", state = ST, pair = nm, cycle1_rows_a = nrow(a1), cycle1_rows_b = nrow(b1),
             cycle1_key_order_identical = same_order,
             cycle1_share_same_donor_sim1 = m[sim == 1, mean(ta == tb, na.rm = TRUE)],
             cycle1_share_same_donor_all = m[, mean(ta == tb, na.rm = TRUE)],
             cycle1_share_same_harvest_draw = m[, mean(ha == hb, na.rm = TRUE)])
}
res <- rbind(ag(r, n, "ref_vs_null"), ag(r, s, "ref_vs_s43"))
na <- data.table(label = "post unblinding follow-on, not gate eligible", state = ST,
  ref_rows_proj_drybio_NA = sum(is.na(r$proj_drybio)), null_rows_proj_drybio_NA = sum(is.na(n$proj_drybio)),
  ref_rows_proj_BA_NA = sum(is.na(r$proj_BA)), null_rows_proj_BA_NA = sum(is.na(n$proj_BA)),
  ref_rows_CONDPROP_NA = sum(is.na(r$CONDPROP_UNADJ)))
fwrite(res, file.path(T, "out", sprintf("null_diag2_donor_%s_postunblind_followon_not_gate_eligible.csv", ST)))
fwrite(na,  file.path(T, "out", sprintf("null_diag2_na_%s_postunblind_followon_not_gate_eligible.csv", ST)))
print(t(res)); print(t(na))
