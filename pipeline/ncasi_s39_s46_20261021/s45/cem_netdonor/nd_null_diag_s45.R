#!/usr/bin/env Rscript
# s45 Track K (post unblinding follow-on, not gate eligible): diagnosis of the null test result.
# Where do k20null and k20ref differ, and does k20ref differ from s43 c00base in the same way?
# Aggregates only.
suppressPackageStartupMessages(library(data.table))
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor"
S43 <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_ablation/engine_c/output"
ST <- commandArgs(trailingOnly = TRUE)[1]
fd <- function(base, tag) { d <- list.files(base, pattern = sprintf("^%s_[0-9]{8}_%s$", ST, tag), full.names = TRUE); file.path(d, "per_plot_projections.rds") }
r <- as.data.table(readRDS(fd(file.path(T, "engine_kref", "output"), "k20ref_postunblind_followon_not_gate_eligible")))
n <- as.data.table(readRDS(fd(file.path(T, "engine_k", "output"), "k20null_postunblind_followon_not_gate_eligible")))
s <- as.data.table(readRDS(fd(S43, "c00base")))
cmp <- function(a, b, nm) {
  out <- list()
  for (v in names(a)) {
    x <- a[[v]]; y <- b[[v]]
    neq <- if (is.numeric(x)) !((is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & x == y)) else !((is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & as.character(x) == as.character(y)))
    out[[v]] <- data.table(pair = nm, column = v, n_diff = sum(neq),
      max_abs = if (is.numeric(x) && any(neq)) max(abs(x - y)[neq], na.rm = TRUE) else NA_real_,
      first_sim = if (any(neq)) a$sim[which(neq)[1]] else NA, first_cycle = if (any(neq)) a$cycle[which(neq)[1]] else NA)
  }
  rbindlist(out)[n_diff > 0]
}
res <- rbind(cmp(r, n, "ref_vs_null"), cmp(r, s[, names(r), with = FALSE], "ref_vs_s43"))
# by sim and cycle share of rows differing in proj_drybio
bys <- function(a, b, nm) { a <- copy(a); a[, dif := !(proj_drybio == b$proj_drybio | (is.na(proj_drybio) & is.na(b$proj_drybio)))]; a[, .(pair = nm, share_diff = mean(dif, na.rm = TRUE)), by = .(sim, cycle)][order(sim, cycle)] }
b1 <- bys(r, n, "ref_vs_null"); b2 <- bys(r, s, "ref_vs_s43")
# key order check
ko <- data.table(pair = c("ref_vs_null","ref_vs_s43"),
  same_keys_order = c(identical(r[, .(sim, cycle, STATECD, COUNTYCD, PLOT, CONDID)], n[, .(sim, cycle, STATECD, COUNTYCD, PLOT, CONDID)]),
                      identical(r[, .(sim, cycle, STATECD, COUNTYCD, PLOT, CONDID)], s[, .(sim, cycle, STATECD, COUNTYCD, PLOT, CONDID)])))
res[, label := "post unblinding follow-on, not gate eligible"]
fwrite(res, file.path(T, "out", sprintf("null_diag_columns_%s_postunblind_followon_not_gate_eligible.csv", ST)))
fwrite(rbind(b1, b2), file.path(T, "out", sprintf("null_diag_bysim_%s_postunblind_followon_not_gate_eligible.csv", ST)))
print(ko); print(res); print(rbind(b1, b2)[sim <= 3])
