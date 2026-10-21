#!/usr/bin/env Rscript
# s45 Track K (post unblinding follow-on, not gate eligible): null test (v3 item 2).
# Per subject output of the netted engine with donor mortality forced to zero (k20null) must be
# identical by md5 to the same session baseline rerun (k20ref). Also reports, as information,
# the same comparison of k20ref against the s43 c00base archive. Writes aggregates only.
suppressPackageStartupMessages(library(data.table))
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor"
S43 <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_ablation/engine_c/output"
ST <- commandArgs(trailingOnly = TRUE)[1]
fd <- function(base, tag) { d <- list.files(base, pattern = sprintf("^%s_[0-9]{8}_%s$", ST, tag), full.names = TRUE); stopifnot(length(d) == 1); file.path(d, "per_plot_projections.rds") }
md5obj <- function(x) { tf <- tempfile(); con <- file(tf, "wb"); serialize(as.data.frame(x), con, xdr = TRUE); close(con); unname(tools::md5sum(tf)) }
canon <- function(x) { x <- as.data.table(x); setcolorder(x, sort(names(x))); setorderv(x, names(x)); x }
f_ref <- fd(file.path(T, "engine_kref", "output"), "k20ref_postunblind_followon_not_gate_eligible")
f_nul <- fd(file.path(T, "engine_k", "output"), "k20null_postunblind_followon_not_gate_eligible")
f_s43 <- fd(S43, "c00base")
r <- readRDS(f_ref); n <- readRDS(f_nul); s <- readRDS(f_s43)
res <- data.table(label = "post unblinding follow-on, not gate eligible", state = ST,
  rows_ref = nrow(r), rows_null = nrow(n), cols_same = identical(names(r), names(n)),
  md5_obj_ref = md5obj(r), md5_obj_null = md5obj(n),
  md5_canon_ref = md5obj(canon(r)), md5_canon_null = md5obj(canon(n)),
  md5_file_ref = unname(tools::md5sum(f_ref)), md5_file_null = unname(tools::md5sum(f_nul)),
  identical_obj = identical(r, n))
res[, null_test_pass := md5_obj_ref == md5_obj_null]
res[, `:=`(info_md5_obj_s43c00base = md5obj(s), info_identical_ref_vs_s43 = identical(r[, names(s)], s))]
if (!res$null_test_pass) {
  num <- names(r)[sapply(r, is.numeric)]
  res[, max_abs_diff_proj_drybio := if (nrow(r) == nrow(n)) max(abs(r$proj_drybio - n$proj_drybio), na.rm = TRUE) else NA_real_]
}
fwrite(res, file.path(T, "out", sprintf("null_test_%s_postunblind_followon_not_gate_eligible.csv", ST)))
print(t(res))
