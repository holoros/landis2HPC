suppressPackageStartupMessages(library(data.table))
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_ablation"
a <- fread(file.path(T, "s43c_ablation_long.csv"))
a[, quantity := factor(quantity, c("stock0","gross","mort","net"))]
L <- c("# s43 Track C CEM ablation (diagnostic only; no verdict changes)", "",
 "Ratios = tool / EVALIDator 2024 (version A, gate number). d = change from c00base. Registered = s41d8 sign split (I/O path copy); netted = state level residual sign (frozen md5 ed9aa46c4a290a0ffaadb6ed00e98739).", "")
for (sc in c("registered","netted")) for (q in levels(a$quantity)) {
  x <- a[scorer == sc & quantity == q]
  w <- dcast(x, cfg ~ state, value.var = "ratio"); wd <- dcast(x, cfg ~ state, value.var = "d_ratio")
  st <- c("ME","NH","VT","MI","WI","MN")
  L <- c(L, sprintf("## %s, %s: ratio (d from baseline)", sc, q), "", paste("| cfg |", paste(st, collapse = " | "), "|"), paste0("|", strrep("---|", 7)))
  for (k in seq_len(nrow(w))) L <- c(L, paste("|", w$cfg[k], "|", paste(sprintf("%.3f (%+.3f)", unlist(w[k, ..st]), unlist(wd[k, ..st])), collapse = " | "), "|"))
  L <- c(L, "")
}
writeLines(L, file.path(T, "s43c_ablation_SUMMARY.md"))
cat(length(L), "lines\n")
