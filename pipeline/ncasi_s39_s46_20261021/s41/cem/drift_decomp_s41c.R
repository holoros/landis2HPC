#!/usr/bin/env Rscript
# s41 CEM gate, step C (16 Oct 2026): drift diagnosis on the 1999 anchored
# archives. Biomass (proj_drybio, DRYBIO_AG). For each state carried in an
# archive (target or donor rows), BAU, cycles 1 to 5 (2004 to 2024):
#   engine stock, engine removals, engine growth net of removals (cycles 2 to
#   5, from the same condition and sim one cycle earlier), split into
#   harvested and unharvested rows; area shares harvested, unmatched,
#   disturbed; mean age saturation factor and share at or past terminal age.
# Observed side on the same subject plots: FIA stock (EXPVOL eval ending in the
# cycle year) and FIA net growth and harvest removals (EXPGROW eval ending in
# the cycle year), from the step A per condition tables.
# Expansion: sum EXPNS x per plot acre value x ADJ_FACTOR_SUBP on both sides
# (no CONDPROP multiplier, EVALIDator convention). Only state x cycle
# aggregates are written.
# Usage: Rscript drift_decomp_s41c.R <archive dir name> <terminal age> <states...>
suppressPackageStartupMessages(library(data.table))
a <- commandArgs(trailingOnly = TRUE)
ARCH <- a[1]; TERM <- as.numeric(a[2]); STS <- a[-(1:2)]
A   <- "/fs/scratch/PUOM0008/crsfaaron/cem_per_plot_archive"
W   <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem"
FIA <- path.expand("~/fia_data")
LB_TG <- 4.53592e-10; GSTART <- 60
SC <- c(ME=23,NH=33,VT=50,MI=26,WI=55,MN=27)
f <- function(st, tb) file.path(FIA, sprintf("%s_%s.csv", st, tb))

t0 <- Sys.time()
d <- as.data.table(readRDS(file.path(A, ARCH, "per_plot_projections.rds")))
cat(sprintf("archive rows %d, read %.0f s\n", nrow(d), as.numeric(Sys.time() - t0, units = "secs")))
keep <- intersect(c("scenario","STATECD","COUNTYCD","PLOT","CONDID","sim","cycle","proj_drybio",
                    "harvest_intensity","was_harvested","was_unmatched","STDAGE",
                    "was_disturbed_sbw","was_disturbed_wind","was_disturbed_fire"), names(d))
d <- d[scenario == "BAU" & STATECD %in% SC[STS] & cycle <= 5, ..keep]
gc()
d[, dist := as.integer(Reduce(`|`, lapply(intersect(c("was_disturbed_sbw","was_disturbed_wind","was_disturbed_fire"), names(d)),
                                        function(v) fcoalesce(as.logical(get(v)), FALSE))))]
setkey(d, STATECD, COUNTYCD, PLOT, CONDID, sim, cycle)
d[, pre := shift(proj_drybio), by = .(STATECD, COUNTYCD, PLOT, CONDID, sim)]
d[, h := fifelse(fcoalesce(as.logical(was_harvested), FALSE) & !is.na(harvest_intensity), harvest_intensity, 0)]
d[, rem := fifelse(h > 0 & h < 1, proj_drybio * h / (1 - h), 0)]
d[, grow := fifelse(cycle >= 2 & !is.na(pre), proj_drybio + rem - pre, NA_real_)]
d[, hv := as.integer(h > 0)]
d[, sat := pmax(0, pmin(1, (TERM - pmin(pmax(fcoalesce(as.numeric(STDAGE), 0), 0), TERM)) / (TERM - GSTART)))]
d[, past := as.integer(fcoalesce(as.numeric(STDAGE), 0) >= TERM)]
cnd <- d[, .(proj = mean(proj_drybio), rem = mean(rem), grow = mean(grow),
             grow_h = mean(fifelse(hv == 1, grow, 0)), grow_u = mean(fifelse(hv == 0, grow, 0)),
             hv = mean(hv), um = mean(as.integer(fcoalesce(as.logical(was_unmatched), FALSE))),
             dist = mean(dist), sat = mean(sat), past = mean(past), age = mean(as.numeric(STDAGE), na.rm = TRUE)),
         by = .(STATECD, COUNTYCD, PLOT, CONDID, cycle)]
rm(d); gc()
cnd[, loc_key := paste(STATECD, COUNTYCD, PLOT, sep = "_")]

out <- list()
for (st in STS) {
  sc <- SC[[st]]
  plt <- fread(f(st,"PLOT"), select = c("CN","STATECD","COUNTYCD","PLOT"), colClasses = list(character = "CN"))
  plt[, loc_key := paste(STATECD, COUNTYCD, PLOT, sep = "_")]
  cfor <- fread(f(st,"COND"), select = c("PLT_CN","CONDID","COND_STATUS_CD"), colClasses = list(character = "PLT_CN"))[COND_STATUS_CD == 1]
  pe  <- fread(f(st,"POP_EVAL"), colClasses = list(character = "CN"))
  pet <- fread(f(st,"POP_EVAL_TYP"), colClasses = list(character = "EVAL_CN"))
  ps  <- fread(f(st,"POP_STRATUM"), colClasses = list(character = "CN"))
  ppsa <- fread(f(st,"POP_PLOT_STRATUM_ASSGN"), select = c("PLT_CN","STRATUM_CN","EVALID"),
                colClasses = list(character = c("PLT_CN","STRATUM_CN")))
  ev <- merge(pet[, .(EVAL_CN, EVAL_TYP)], pe[, .(CN, EVALID, END_INVYR)], by.x = "EVAL_CN", by.y = "CN")
  stk <- readRDS(file.path(W, "work", sprintf("stock_cond_%s.rds", st)))
  grm <- readRDS(file.path(W, "work", sprintf("grm_cond_%s.rds", st)))
  rmv <- readRDS(file.path(W, "work", sprintf("remv_cond_%s.rds", st)))
  cs <- cnd[STATECD == sc]
  subj <- unique(cs[cycle == 1, loc_key])
  wts <- function(typ, yr) {
    id <- ev[EVAL_TYP == typ & END_INVYR == yr, EVALID][1]
    if (is.na(id)) return(NULL)
    w <- ppsa[EVALID == id][ps[, .(STRATUM_CN = CN, EXPNS, ADJ = ADJ_FACTOR_SUBP)], on = "STRATUM_CN", nomatch = NULL]
    w <- unique(w, by = "PLT_CN")
    plt[, .(PLT_CN = CN, loc_key)][w, on = "PLT_CN", nomatch = NULL][loc_key %in% subj]
  }
  for (cy in 1:5) {
    yr <- 1999 + 5 * cy
    wv <- wts("EXPVOL", yr); wg <- wts("EXPGROW", yr)
    r <- data.table(state = st, archive = ARCH, cycle = cy, year = yr)
    if (!is.null(wv)) {
      ec <- merge(cfor[, .(PLT_CN, CONDID)], wv, by = "PLT_CN")
      pj <- merge(cs[cycle == cy], ec[, .(loc_key, CONDID, EXPNS, ADJ)], by = c("loc_key","CONDID"))
      wsum <- function(x) sum(pj$EXPNS * pj$ADJ * x, na.rm = TRUE)
      wa   <- function(x) sum(pj$EXPNS * x, na.rm = TRUE) / sum(pj$EXPNS)
      ob <- merge(stk, ec[, .(PLT_CN, CONDID, EXPNS, ADJ)], by = c("PLT_CN","CONDID"))
      r[, `:=`(n_cond = nrow(pj),
               eng_stock_Tg = wsum(pj$proj) * LB_TG,
               obs_stock_Tg = ob[, sum(EXPNS * ADJ * (s1 + s2 + s3))] * LB_TG,
               eng_remv_Tgyr = wsum(pj$rem) * LB_TG / 5,
               eng_grow_Tgyr = if (cy >= 2) wsum(pj$grow) * LB_TG / 5 else NA_real_,
               eng_grow_harv_Tgyr = if (cy >= 2) wsum(pj$grow_h) * LB_TG / 5 else NA_real_,
               eng_grow_unharv_Tgyr = if (cy >= 2) wsum(pj$grow_u) * LB_TG / 5 else NA_real_,
               share_harv = wa(pj$hv), share_unmatched = wa(pj$um), share_disturbed = wa(pj$dist),
               mean_sat = wa(pj$sat), share_past_term = wa(pj$past), mean_age = wa(pj$age))]
    }
    if (!is.null(wg)) {
      og <- grm[wg[, .(PLT_CN, EXPNS, ADJ)], on = "PLT_CN", nomatch = NULL][REMPER > 0]
      orm <- rmv[wg[, .(PLT_CN, EXPNS, ADJ)], on = "PLT_CN", nomatch = NULL][REMPER > 0]
      r[, `:=`(obs_net_Tgyr = og[, sum(EXPNS * ADJ * net_tot / REMPER)] * LB_TG,
               obs_gross_Tgyr = og[, sum(EXPNS * ADJ * gross_tot / REMPER)] * LB_TG,
               obs_mort_Tgyr = og[, sum(EXPNS * ADJ * mort_tot / REMPER)] * LB_TG,
               obs_remv_Tgyr = orm[, sum(EXPNS * ADJ * remv_tot / REMPER)] * LB_TG)]
    }
    out[[paste(st, cy)]] <- r
  }
}
res <- rbindlist(out, fill = TRUE)
fn <- file.path(W, "out", sprintf("drift_decomp_%s_20261016.csv", ARCH))
fwrite(res, fn)
print(res)
cat("STEP_C_DONE\n")
