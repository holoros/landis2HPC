#!/usr/bin/env Rscript
# s41 diagnostic d5: ME s41 archive, rows per sim and cycle by STATECD, and
# whether the condition key set is stable across sims within each state.
suppressPackageStartupMessages(library(data.table))
W <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem"
d <- as.data.table(readRDS(file.path(W, "engine/output/ME_20261016_s41gate/per_plot_projections.rds")))
print(dcast(d[cycle == 1 & sim <= 3, .N, by = .(sim, STATECD)], STATECD ~ sim, value.var = "N"))
print(d[cycle == 1, .N, by = sim][, .(min = min(N), max = max(N))])
d[, key := paste(STATECD, COUNTYCD, PLOT, CONDID)]
k <- d[cycle == 1, .(ns = uniqueN(sim)), by = .(key, STATECD)]
print(k[, .(keys = .N, all20 = sum(ns == 20), one_sim = sum(ns == 1), median_ns = median(ns)), by = STATECD])
# do keys that appear in few sims share COUNTYCD/PLOT with a key present in all?
k[, plotkey := sub(" [0-9]+$", "", key)]
pk <- k[, .(n_condids = .N, any_all20 = any(ns == 20)), by = .(plotkey, STATECD)]
print(pk[, .(plots = .N, plots_multi_condid = sum(n_condids > 1)), by = STATECD])
print(d[cycle == 1, .(rows = .N), by = .(was_harvested, was_unmatched)])
