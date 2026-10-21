# s43 Track C summary: ratio (version A, gate number) by state x config x scorer, delta from baseline.
suppressPackageStartupMessages(library(data.table))
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_ablation"
S41 <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem/out"
rd <- function(dir, pat) { fs <- list.files(file.path(T, "scores", dir), pattern = pat, full.names = TRUE)
  rbindlist(lapply(fs, function(f) { x <- fread(f); x[, cfg := sub(".*cem_gate_[A-Z]{2}_(c[0-9a-z]+)_.*", "\\1", basename(f))]; x }), fill = TRUE) }
reg <- rd("reg", "^cem_gate_[A-Z]{2}_c.*_20261016e.csv$"); reg[, scorer := "registered"]
net <- rd("net", "^cem_gate_[A-Z]{2}_c.*_s43netted.csv$"); net[, scorer := "netted"]
a <- rbind(reg, net, fill = TRUE)[, .(state, cfg, scorer, quantity, ratio, ratio_lo95, ratio_hi95, ratioB, pass, tool)]
# productivity arm: non ME states equal baseline by construction (not rerun)
b <- a[cfg == "c00base" & state != "ME"]; b[, cfg := "c07noprod"]; a <- rbind(a, b)
base <- a[cfg == "c00base", .(state, scorer, quantity, ratio_base = ratio, tool_base = tool)]
a <- base[a, on = c("state","scorer","quantity")]
a[, d_ratio := ratio - ratio_base][, d_tool := tool - tool_base]
setorder(a, scorer, cfg, quantity, state)
fwrite(a, file.path(T, "s43c_ablation_long.csv"))
w <- dcast(a, scorer + cfg + state ~ quantity, value.var = "ratio")
fwrite(w, file.path(T, "s43c_ablation_ratio_wide.csv"))
wd <- dcast(a, scorer + cfg + state ~ quantity, value.var = "d_ratio")
fwrite(wd, file.path(T, "s43c_ablation_delta_wide.csv"))
# reproduction check against recorded f2gate
rec <- rbindlist(lapply(c("ME","NH","VT","MI","WI","MN"), function(s) fread(file.path(S41, sprintf("cem_gate_%s_f2gate_20261016e.csv", s)))))
rp <- merge(rec[, .(state, quantity, ratio_rec = ratio)], a[cfg == "c00base" & scorer == "registered", .(state, quantity, ratio_s43 = ratio)], by = c("state","quantity"))
rp[, diff := ratio_s43 - ratio_rec]
fwrite(rp, file.path(T, "s43c_baseline_repro.csv"))
cat("rows", nrow(a), "\n")
