#!/usr/bin/env Rscript
# fia_design_estimate.R
#
# Design-based FIA estimator that MIRRORS EVALIDator, WITH standard errors.
# Live aboveground carbon total per state (extensible to county/ecoregion).
#
# Point estimate (stratified expansion):
#   y_i  = sum over live trees on plot i of CARBON_AG * TPA_UNADJ * ADJ_FACTOR
#          (ADJ = ADJ_FACTOR_MICR for DIA < 5 in, else ADJ_FACTOR_SUBP)
#   Yhat = sum_h EXPNS_h * sum_{i in h} y_i           (h = stratum)
#
# Variance (Bechtold & Patterson 2005, stratified, fpc ignored), using the FULL
# plot set per stratum (nonforest / no-live-tree plots enter as y_i = 0):
#   A_h    = EXPNS_h * n_h                              (stratum area, acres)
#   V(Yhat)= sum_h A_h^2 * s2_yh / n_h ,  s2_yh = sample var of y_i in stratum h
#   SE     = sqrt(V) ;  CV% = 100 * SE / Yhat
#
# EVALID = most recent EXPVOL evaluation present in BOTH the assignment table
#          and POP_STRATUM (vintage-matched).
#
# Inputs: {ST}_POP_PLOT_STRATUM_ASSGN.csv, ENTIRE_POP_STRATUM.csv, {ST}_TREE.csv
# Output: fia_design_validate.csv (state, evalid, n_plots, agc_TgC_design, se_TgC, cv_pct)
#
# module load gcc/12.3.0; module load R/4.4.0 ; Rscript fia_design_estimate.R ME,WA,RI

suppressPackageStartupMessages(library(data.table))
args   <- commandArgs(trailingOnly = TRUE)
states <- strsplit(if (length(args) >= 1) args[1] else "ME,WA,RI", ",")[[1]]
fia    <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
LB2TG  <- 0.45359237 / 1000 / 1e6           # pounds -> teragrams

strat_all <- fread(file.path(fia, "ENTIRE_POP_STRATUM.csv"),
  select = c("CN","EVALID","EXPNS","ADJ_FACTOR_SUBP","ADJ_FACTOR_MICR"))
strat_all[, CN := as.character(CN)]

est_state <- function(st) {
  af <- file.path(fia, paste0(st, "_POP_PLOT_STRATUM_ASSGN.csv"))
  tf <- file.path(fia, paste0(st, "_TREE.csv"))
  if (!all(file.exists(af, tf))) return(NULL)

  assg <- fread(af, select = c("PLT_CN","STRATUM_CN","EVALID"), integer64 = "character")
  evs  <- unique(assg$EVALID); evs <- evs[evs %% 100 == 1]
  evs  <- evs[evs %in% strat_all$EVALID]
  if (!length(evs)) { message("  no shared EXPVOL EVALID for ", st); return(NULL) }
  yy   <- (evs %/% 100) %% 100
  ev   <- evs[which.max(ifelse(yy <= 30, 2000 + yy, 1900 + yy))]
  assg <- assg[EVALID == ev]
  assg[, `:=`(PLT_CN = as.character(PLT_CN), STRATUM_CN = as.character(STRATUM_CN))]
  assg <- unique(assg, by = "PLT_CN")

  str <- strat_all[EVALID == ev]
  ps  <- merge(assg, str, by.x = "STRATUM_CN", by.y = "CN")   # plot -> stratum EXPNS, ADJ

  tr <- fread(tf, select = c("PLT_CN","STATUSCD","TPA_UNADJ","DIA","CARBON_AG"))
  tr <- tr[STATUSCD == 1 & !is.na(CARBON_AG) & !is.na(TPA_UNADJ)]
  tr[, PLT_CN := as.character(PLT_CN)]
  tr <- merge(tr, ps[, .(PLT_CN, ADJ_FACTOR_SUBP, ADJ_FACTOR_MICR)], by = "PLT_CN")
  tr[, ADJ := fifelse(!is.na(DIA) & DIA < 5, ADJ_FACTOR_MICR, ADJ_FACTOR_SUBP)]
  yplot <- tr[, .(y = sum(CARBON_AG * TPA_UNADJ * ADJ)), by = PLT_CN]   # lbs C / acre

  # full plot set (nonforest / no-tree plots -> y = 0), keyed to stratum
  d <- merge(ps[, .(PLT_CN, STRATUM_CN, EXPNS)], yplot, by = "PLT_CN", all.x = TRUE)
  d[is.na(y), y := 0]

  # stratum-level point and variance pieces
  sh <- d[, .(n_h = .N, EXPNS = EXPNS[1], sum_y = sum(y),
              s2 = if (.N > 1) var(y) else 0), by = STRATUM_CN]
  sh[, A_h := EXPNS * n_h]
  Yhat <- sh[, sum(EXPNS * sum_y)]                 # lbs C
  Vhat <- sh[, sum(A_h^2 * s2 / n_h)]              # (lbs C)^2
  tot  <- Yhat * LB2TG
  se   <- sqrt(Vhat) * LB2TG

  data.table(state = st, evalid = ev, n_plots = nrow(d),
             agc_TgC_design = round(tot, 2),
             se_TgC = round(se, 2),
             cv_pct = round(100 * se / tot, 2))
}

res <- rbindlist(lapply(states, est_state))
fwrite(res, file.path(fia, "fia_design_validate.csv"))
print(res)
