#!/usr/bin/env Rscript
# s41 diagnostic d3: NH, tool year 0 condition biomass (cycle 1 pre_drybio_ag,
# sim 1) against the same condition's FIA biomass in the 2024 EXPVOL
# evaluation (unadjusted lb/ac). Aggregates only.
suppressPackageStartupMessages(library(data.table))
W <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem"; FIA <- path.expand("~/fia_data")
ST <- "NH"; sc <- 33
d <- as.data.table(readRDS(file.path(W, "engine/output/NH_20261016_s41gate/per_plot_projections.rds")))[STATECD == sc & cycle == 1]
cat("sims:", paste(range(d$sim), collapse = "-"), "\n")
d1 <- d[sim == min(sim)]
d1[, loc_key := paste(as.integer(STATECD), as.integer(COUNTYCD), as.integer(PLOT), sep = "_")]
print(d1[, .(n = .N, harvested = sum(fcoalesce(as.logical(was_harvested), FALSE)), pre_na = sum(is.na(pre_drybio_ag)))])
plt <- fread(file.path(FIA, "NH_PLOT.csv"), select = c("CN","STATECD","COUNTYCD","PLOT","INVYR"), colClasses = list(character = "CN"))
plt[, loc_key := paste(STATECD, COUNTYCD, PLOT, sep = "_")]
stk <- readRDS(file.path(W, "work", "stock_cond_NH.rds"))
stk <- plt[, .(PLT_CN = CN, loc_key, INVYR)][stk, on = "PLT_CN"]
stk <- stk[INVYR >= 2018]
stk[, CONDID := as.integer(CONDID)]
m <- merge(d1[, .(loc_key, CONDID = as.integer(CONDID), INVYR_t = INVYR, pre = fcoalesce(pre_drybio_ag, 0), hv = fcoalesce(as.logical(was_harvested), FALSE))],
           stk[, .(loc_key, CONDID, INVYR, obs = s1 + s2 + s3)], by = c("loc_key","CONDID"))
m <- m[INVYR == INVYR_t]
m[, rr := pre / obs]
print(m[, .(n = .N, sum_tool = sum(pre), sum_obs = sum(obs), equal_share = mean(abs(pre - obs) < 0.01 * pmax(obs, 1)),
            q10 = quantile(rr, .1, na.rm = TRUE), q50 = quantile(rr, .5, na.rm = TRUE), q90 = quantile(rr, .9, na.rm = TRUE)), by = hv])
