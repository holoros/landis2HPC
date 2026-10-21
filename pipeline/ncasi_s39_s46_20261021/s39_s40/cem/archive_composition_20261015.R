#!/usr/bin/env Rscript
# Aggregate composition and anchoring of one CEM per plot archive, BAU rows, first cycle.
# Writes state level counts only: no plot identifiers or coordinates leave this script.
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE); arch_dir <- a[1]; out_csv <- a[2]
d <- readRDS(file.path(arch_dir, "per_plot_projections.rds")); setDT(d)
cat("Columns:", paste(intersect(names(d), c("STATECD","COUNTYCD","PLOT","CONDID","cycle","INVYR","scenario","sim","proj_carbon")), collapse=" "), "\n")
d <- d[scenario == "BAU"]
c1 <- min(d$cycle)
x <- d[cycle == c1, .(n_rows = .N,
         n_cond = uniqueN(paste(COUNTYCD, PLOT, CONDID)),
         n_plot = uniqueN(paste(COUNTYCD, PLOT)),
         invyr_min = if ("INVYR" %in% names(d)) min(INVYR) else NA_integer_,
         invyr_max = if ("INVYR" %in% names(d)) max(INVYR) else NA_integer_), by = STATECD]
x[, share_rows := round(n_rows / sum(n_rows), 4)]
x[, `:=`(archive = basename(arch_dir), first_cycle = c1, last_cycle = max(d$cycle))]
setorder(x, -n_rows); print(x); fwrite(x, out_csv)
