# Track I early window: replication rule. Effect = ratio(cfg) - ratio(base), mortality.
# Replicated if same sign as gate window effect and |early - gate| <= 0.10, in >= 5 of 6 states.
library(data.table); options(width = 200)
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism"
A <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_ablation"
rd <- function(dir, pat, scorer) {
  fs <- list.files(file.path(T, "scores", dir), pat, full.names = TRUE)
  rbindlist(lapply(fs, function(f) { x <- fread(f); x[, cfg := sub(".*_(e0[0-9][a-z]+)_.*", "\\1", basename(f))]; x[, scorer := scorer]; x }), fill = TRUE)
}
e <- rbind(rd("reg", "^cem_gate_[A-Z]{2}_e0.*_20261016e.csv$", "registered")[, .(state, scorer, quantity, cfg, ratio, tool)],
           rd("net", "^cem_gate_[A-Z]{2}_e0.*_s43netted.csv$", "netted")[, .(state, scorer, quantity, cfg, ratio, tool)])
e[, cfg_g := sub("^e", "c", cfg)]
fwrite(e, file.path(T, "out", "early_ratios_long_s43i.csv"))
g <- fread(file.path(A, "s43c_ablation_long.csv")); setnames(g, 1, "State"); g <- g[cfg %in% c("c00base","c03nodist","c04nosdi","c08alloff"), .(state = State, scorer, quantity, cfg_g = cfg, ratio_gate = ratio, d_gate = d_ratio)]
m <- merge(e, g, by = c("state","scorer","quantity","cfg_g"))
m[, d_early := ratio - ratio[cfg_g == "c00base"], by = .(state, scorer, quantity)]
m <- m[cfg_g != "c00base"]
m[, rep := sign(d_early) == sign(d_gate) & abs(d_early - d_gate) <= 0.10]
fwrite(m, file.path(T, "out", "early_replication_long_s43i.csv"))
v <- m[quantity == "mort", .(n_rep = sum(rep), n = .N, replicated = sum(rep) >= 5), by = .(scorer, cfg_g)]
fwrite(v, file.path(T, "out", "early_replication_verdict_s43i.csv"))
print(dcast(m[quantity == "mort"], scorer + cfg_g ~ state, value.var = "d_early")[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 3) else z)])
print(dcast(m[quantity == "mort"], scorer + cfg_g ~ state, value.var = "d_gate")[, lapply(.SD, function(z) if (is.numeric(z)) round(z, 3) else z)])
print(v)
b <- e[cfg == "e00base", .(state, scorer, quantity, ratio = round(ratio, 3))]
print(dcast(b, scorer + quantity ~ state, value.var = "ratio"))
