#!/usr/bin/env Rscript
# s46 Track K amended (post unblinding follow-on, not gate eligible): md5 identity of two per subject archives.
# Usage: Rscript nd_md5cmp_s46.R <ST> <TEST> <engine dir A> <tag A> <engine dir B> <tag B>
# Primary criterion: md5 of the serialized archive object (as in s45 nd_null_md5_s45.R); file md5 and
# canonical (sorted) md5 are reported beside it. Aggregates only.
suppressPackageStartupMessages(library(data.table))
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cem_netdonor"
a <- commandArgs(trailingOnly = TRUE); ST <- a[1]; TEST <- a[2]
fd <- function(base, tag) { d <- list.files(file.path(base, "output"), pattern = sprintf("^%s_[0-9]{8}_%s$", ST, tag), full.names = TRUE); stopifnot(length(d) == 1); file.path(d, "per_plot_projections.rds") }
md5obj <- function(x) { tf <- tempfile(); con <- file(tf, "wb"); serialize(as.data.frame(x), con, xdr = TRUE); close(con); unname(tools::md5sum(tf)) }
canon <- function(x) { x <- as.data.table(x); setcolorder(x, sort(names(x))); setorderv(x, names(x)); x }
fa <- fd(a[3], a[4]); fb <- fd(a[5], a[6])
A <- readRDS(fa); B <- readRDS(fb)
res <- data.table(label = "post unblinding follow-on, not gate eligible", state = ST, test = TEST, tag_a = a[4], tag_b = a[6],
  rows_a = nrow(A), rows_b = nrow(B), cols_same = identical(names(A), names(B)),
  md5_obj_a = md5obj(A), md5_obj_b = md5obj(B), md5_canon_a = md5obj(canon(A)), md5_canon_b = md5obj(canon(B)),
  md5_file_a = unname(tools::md5sum(fa)), md5_file_b = unname(tools::md5sum(fb)), identical_obj = identical(A, B))
res[, md5_identical := md5_obj_a == md5_obj_b]
if (!res$md5_identical && nrow(A) == nrow(B) && "proj_drybio" %in% names(A))
  res[, max_abs_diff_proj_drybio := max(abs(A$proj_drybio - B$proj_drybio), na.rm = TRUE)]
if (all(c("cycle","sim","donor_idx") %in% names(A)) && nrow(A) == nrow(B)) {
  k <- A$cycle == 1
  res[, `:=`(share_same_donor_c1_sim1 = mean((A$donor_idx == B$donor_idx)[k & A$sim == 1], na.rm = TRUE),
             share_same_donor_c1_all = mean((A$donor_idx == B$donor_idx)[k], na.rm = TRUE))]
}
fwrite(res, file.path(T, "out", sprintf("md5cmp_%s_%s_postunblind_followon_not_gate_eligible.csv", TEST, ST)))
print(t(res))
