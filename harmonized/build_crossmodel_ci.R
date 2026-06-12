#!/usr/bin/env Rscript
# build_crossmodel_ci.R - per-model 2100 reserve carbon WITH a 90% confidence interval
# for the cross-model overlap states, so the model values can be compared directly.
#
# Each model's CI combines the uncertainty sources available for that model:
#   anchor_se   FIA design sampling SE (already carried as agc_TgC_anchored_se = value*cv/100;
#               common to all models since all are anchored to the same FIA total)
#   param_sd    intra-model parameter SD. FVS: the Bayesian posterior band (fvs_posterior_ci_all.csv,
#               relative). CBM/LANDIS/CEM/YC: not yet available (CBM OAT env-blocked; LANDIS replicate
#               and YC rcp spread TBD) -> anchor_se only, flagged.
#   total_se = sqrt(anchor_se^2 + param_sd^2);  CI90 = value +/- 1.645*total_se
#
# Two models are "distinguishable" at a state if their 90% CIs do not overlap.
# module load gcc/12.3.0 R/4.4.0
suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
files <- c(LANDIS="harmonized_landis_reserve_9state.csv", FVS_cal="fvs_reserve_calibrated_anchored.csv",
           FVS_def="fvs_reserve_default_anchored.csv", YieldCurve="yc_reserve_anchored.csv",
           CEM="cem_reserve_anchored.csv", CBM="cbm_reserve_anchored.csv")
fvs_post <- tryCatch(fread(file.path(FIA,"fvs_posterior_ci_all.csv")), error=function(e) NULL)
fvs_relsd <- function(st, yr){
  if (is.null(fvs_post)) return(NA_real_)
  s <- fvs_post[ST==st]; if (nrow(s) < 2) return(NA_real_)
  (approx(s$year, s$rel_hi, yr, rule=2)$y - approx(s$year, s$rel_lo, yr, rule=2)$y)/2/1.96
}
# CBM OAT parameter band (run_oat_sensitivity.py): rel_halfrange is the +/- envelope from
# the 5-parameter +/-25% sweep. Treat half-range as ~90% half-width -> rel SD = halfrange/1.645.
cbm_oat <- tryCatch(fread(file.path(FIA,"cbm_oat_bands.csv")), error=function(e) NULL)
cbm_gap <- tryCatch(fread(file.path(FIA,"cbm_engine_gap.csv")), error=function(e) NULL)
cbm_relsd <- function(st){
  # combine the OAT parameter band with the GCBM-vs-libcbm ENGINE gap (the documented
  # structural difference: GCBM projects +21-26% over the libcbm SIT engine we use; this
  # dwarfs the OAT band and is the dominant intra-CBM uncertainty).
  oat <- if (!is.null(cbm_oat) && nrow(cbm_oat[state==st])) cbm_oat[state==st]$rel_halfrange[1]/1.645 else NA_real_
  eg  <- if (!is.null(cbm_gap) && nrow(cbm_gap[state==st])) abs(cbm_gap[state==st]$gcbm_over_libcbm_pct[1])/100/1.645 else 0
  if (is.na(oat)) return(NA_real_)
  sqrt(oat^2 + eg^2)
}
# YieldCurve band: rcp45-vs-rcp85 climate spread (+) the YC simulation CI (mmt_agc_lo/hi),
# combined in quadrature; the lo/hi is a 95% CI so /1.96 -> SD.
yc_b <- tryCatch(fread(file.path(FIA,"yc_bands.csv")), error=function(e) NULL)
yc_relsd <- function(st){
  if (is.null(yc_b)) return(NA_real_)
  x <- yc_b[state==st]; if (!nrow(x)) return(NA_real_)
  sqrt((x$rel_climate_band[1]/1.645)^2 + (x$rel_sim_band[1]/1.96)^2)
}
FIPS <- c(IN=18, OH=39, NH=33)
rows <- rbindlist(lapply(names(files), function(m){
  d <- fread(file.path(FIA,files[m]))[scenario=="reserve"]; d[, dom:=sprintf("%02d",as.integer(dom))]
  rbindlist(lapply(names(FIPS), function(st){
    s <- d[dom==sprintf("%02d",FIPS[st])][order(year)]; if(!nrow(s)) return(NULL)
    i <- which.max(s$year); val <- s$agc_TgC_anchored[i]; ase <- s$agc_TgC_anchored_se[i]
    psd <- 0; src <- "anchor-only"
    if (grepl("FVS", m)) { r <- fvs_relsd(st, s$year[i]); if (is.finite(r)) { psd <- val*r; src <- "anchor+posterior" } }
    if (m=="CBM") { r <- cbm_relsd(st); if (is.finite(r)) { psd <- val*r; src <- "anchor+OAT" } }
    if (m=="YieldCurve") { r <- yc_relsd(st); if (is.finite(r)) { psd <- val*r; src <- "anchor+rcp+sim" } }
    tse <- sqrt(ase^2 + psd^2)
    data.table(state=st, model=m, year=s$year[i], value=round(val,1),
               anchor_se=round(ase,1), param_sd=round(psd,1), total_se=round(tse,1),
               lo90=round(val-1.645*tse,1), hi90=round(val+1.645*tse,1), ci_source=src)
  }))
}))
fwrite(rows, file.path(FIA,"harmonized_crossmodel_ci.csv"))
for (stt in names(FIPS)){
  cat(sprintf("\n=== %s 2100 reserve (Tg C), 90%% CI ===\n", stt))
  x <- rows[state==stt][order(-value)]
  for (i in 1:nrow(x)) cat(sprintf("  %-10s %7.1f  [%6.1f, %6.1f]  (%s)\n", x$model[i], x$value[i], x$lo90[i], x$hi90[i], x$ci_source[i]))
  # distinguishability: count non-overlapping model pairs
  np <- 0; tot <- 0
  for (a in 1:(nrow(x)-1)) for (b in (a+1):nrow(x)){ tot<-tot+1; if (x$lo90[a]>x$hi90[b] || x$lo90[b]>x$hi90[a]) np<-np+1 }
  cat(sprintf("  -> %d of %d model pairs are distinguishable (non-overlapping 90%% CIs)\n", np, tot))
}
