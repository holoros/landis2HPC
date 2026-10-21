#!/usr/bin/env Rscript
# s41 diagnostic d4: presence of own state conditions across sims and cycles
# in the s41 archives (counts only).
suppressPackageStartupMessages(library(data.table))
W <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem"
SC <- c(ME=23,NH=33,VT=50,MI=26,WI=55,MN=27)
for (st in names(SC)) {
  rd <- list.files(file.path(W, "engine", "output"), pattern = sprintf("^%s_[0-9]{8}_s41gate$", st), full.names = TRUE)
  d <- as.data.table(readRDS(file.path(rd, "per_plot_projections.rds")))[STATECD == SC[[st]]]
  d[, key := paste(COUNTYCD, PLOT, CONDID)]
  nall <- uniqueN(d$key)
  ps <- d[, .(n_cond = uniqueN(key), rows = .N), by = .(sim, cycle)]
  pres <- d[cycle == 1, .(ns = uniqueN(sim)), by = key]
  cat(sprintf("%s: distinct conditions %d; cycle1 conditions present in all %d sims: %.3f; rows per (cond,sim,cycle) max %d\n",
              st, nall, uniqueN(d$sim), mean(pres$ns == uniqueN(d$sim)),
              max(d[, .N, by = .(key, sim, cycle)]$N)))
  print(ps[, .(min_n = min(n_cond), max_n = max(n_cond), mean_rows = mean(rows)), by = cycle])
  print(d[cycle == 1, .N, by = .(unm = was_unmatched, hv = was_harvested, cem_iteration)][order(-N)][1:8])
}
