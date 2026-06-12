#!/usr/bin/env Rscript
# uncertainty_ensemble.R
#
# Quantifies and expresses uncertainty in the harmonized reserve carbon projections,
# separating the three sources that matter here:
#
#   1. INTER-MODEL (structural) - spread across the independent models (FVS, LANDIS,
#      CEM, yield curves, CBM) at each state and year. This is the dominant component:
#      same inputs, same anchor, same harvest, so the spread is pure model structure.
#   2. INTRA-MODEL (parameter) - within a single model's parameterization. The one
#      component we have as an actual pair of fits is FVS default vs calibrated
#      (the Bayesian posterior median vs the original parameters); |cal-def|/2 is used
#      as the available intra-model parameter band. CBM posterior draws (the 500-draw
#      UncertaintyEngine) were NOT produced for the CONUS bau run, so a true intra-CBM
#      band is flagged as future work, not fabricated.
#   3. FIA SAMPLING (anchor) - every model is anchored to the same FIA design total,
#      which carries the FIA sampling CV (cv_pct). Propagated as median * cv/100.
#
# Total SD combines the three in quadrature (treated as independent):
#   total_sd = sqrt(between_model_sd^2 + within_fvs^2 + anchor_se^2)
# 90% band = median +/- 1.645*total_sd (floored at 0).
#
# Outputs:
#   uncertainty_by_state_year.csv  - per state x {2025,2050,2075,2100}, all components + band
#   uncertainty_conus.csv          - CONUS rollup on the full-coverage models (FVS,YC,CBM)
# module load gcc/12.3.0 R/4.4.0

suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
ga <- function(f,d=NA){a<-commandArgs(TRUE);i<-match(f,a);if(is.na(i)||i==length(a))d else a[i+1]}

# --mode nodist (default) or disturbed (uses the *_disturbed.csv reserves + suffixed outputs)
MODE <- ga("--mode","nodist"); SUF <- if (MODE=="disturbed") "_disturbed" else "_anchored"
sfx <- function(stub) paste0(stub, SUF, ".csv")
files <- c(FVS=sfx("fvs_reserve_calibrated"),
           LANDIS=if(MODE=="disturbed") "harmonized_landis_reserve_7state_disturbed.csv" else "harmonized_landis_reserve_7state.csv",
           CEM=sfx("cem_reserve"), YieldCurve=sfx("yc_reserve"), CBM=sfx("cbm_reserve"))
FVS_DEF <- sfx("fvs_reserve_default")           # for the within-FVS parameter band
OUT_SY  <- paste0("uncertainty_by_state_year", if(MODE=="disturbed") "_disturbed" else "", ".csv")
OUT_CO  <- paste0("uncertainty_conus", if(MODE=="disturbed") "_disturbed" else "", ".csv")
YEARS <- c(2025,2050,2075,2100)
FIPS<-c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,LA=22,
        ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,NY=36,NC=37,
        ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,VA=51,WA=53,WV=54,WI=55,WY=56)
ab2fips <- FIPS; fips2ab <- setNames(names(FIPS), sprintf("%02d",FIPS))
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, cv=cv_pct)]

# interpolate one model's anchored reserve to the target years, per state
interp_model <- function(fn){
  d <- fread(file.path(FIA,fn)); d <- d[scenario=="reserve"]
  d[, dom := sprintf("%02d", as.integer(dom))]
  rbindlist(lapply(split(d, d$dom), function(s){
    s <- s[order(year)]; if (nrow(s)<2) return(NULL)
    data.table(state=fips2ab[s$dom[1]], year=YEARS,
               v=approx(s$year, s$agc_TgC_anchored, YEARS, rule=2)$y)
  }))
}
mods <- lapply(files, interp_model)
fvsdef <- interp_model(FVS_DEF)

# Real intra-FVS parameter band from the Bayesian posterior draws (fvs_posterior_uncertainty.py).
# posterior_ci_all.csv carries relative 2.5/97.5 percentile bounds (rel_lo, rel_hi) per state x year
# (7 states so far). Parameter SD (relative) = (rel_hi - rel_lo)/2 / 1.96; applied to the anchored
# FVS mean. For states without a posterior run, fall back to the |cal-def|/2 proxy.
fvs_post <- tryCatch(fread(file.path(FIA,"fvs_posterior_ci_all.csv")), error=function(e) NULL)
if (is.null(fvs_post)) fvs_post <- tryCatch(fread("fvs_posterior_ci_all.csv"), error=function(e) NULL)
fvs_relsd <- function(st, yr){
  if (is.null(fvs_post)) return(NA_real_)
  s <- fvs_post[ST==st]; if (nrow(s) < 2) return(NA_real_)
  rl <- approx(s$year, s$rel_lo, yr, rule=2)$y; rh <- approx(s$year, s$rel_hi, yr, rule=2)$y
  (rh - rl)/2/1.96
}

# assemble per state x year ensemble
keys <- CJ(state=names(FIPS), year=YEARS)
ens <- rbindlist(lapply(1:nrow(keys), function(i){
  st <- keys$state[i]; yr <- keys$year[i]
  vals <- sapply(names(mods), function(m){ x<-mods[[m]][state==st & year==yr]; if(nrow(x)) x$v else NA_real_ })
  vals <- vals[is.finite(vals)]
  if (length(vals) < 2) return(NULL)
  med <- median(vals); bsd <- sd(vals)
  fd <- fvsdef[state==st & year==yr]; fc <- mods$FVS[state==st & year==yr]
  relsd <- fvs_relsd(st, yr)                                  # real posterior band (relative)
  within_fvs <- if (is.finite(relsd) && nrow(fc)) fc$v*relsd  # preferred: Bayesian posterior SD
               else if (nrow(fd) && nrow(fc)) abs(fc$v - fd$v)/2 else 0  # fallback: cal-vs-def proxy
  within_src <- if (is.finite(relsd)) "posterior" else "cal-def"
  cv <- anc[state==st]$cv; anchor_se <- if(length(cv)) med*cv/100 else 0
  total_sd <- sqrt(bsd^2 + within_fvs^2 + anchor_se^2)
  data.table(state=st, year=yr, n_models=length(vals),
             median=round(med,1), min=round(min(vals),1), max=round(max(vals),1),
             between_model_sd=round(bsd,1), between_model_cv_pct=round(100*bsd/med,1),
             within_fvs_param=round(within_fvs,1), within_fvs_src=within_src,
             anchor_se=round(anchor_se,1),
             total_sd=round(total_sd,1), lo90=round(pmax(med-1.645*total_sd,0),1),
             hi90=round(med+1.645*total_sd,1),
             FVS=round(unname(mods$FVS[state==st&year==yr]$v[1]),1),
             LANDIS=round(unname(mods$LANDIS[state==st&year==yr]$v[1]),1),
             CEM=round(unname(mods$CEM[state==st&year==yr]$v[1]),1),
             YieldCurve=round(unname(mods$YieldCurve[state==st&year==yr]$v[1]),1),
             CBM=round(unname(mods$CBM[state==st&year==yr]$v[1]),1))
}))
fwrite(ens, file.path(FIA,OUT_SY))

# CONUS rollup on full-coverage models only (FVS, YieldCurve, CBM = 48 states each)
full <- c("FVS","YieldCurve","CBM")
conus <- rbindlist(lapply(YEARS, function(yr){
  tot <- sapply(full, function(m) sum(mods[[m]][year==yr]$v, na.rm=TRUE))
  med <- median(tot); bsd <- sd(tot)
  data.table(year=yr, n_full_models=length(full),
             FVS=round(tot["FVS"]), YieldCurve=round(tot["YieldCurve"]), CBM=round(tot["CBM"]),
             ensemble_median=round(med), between_model_sd=round(bsd),
             between_model_cv_pct=round(100*bsd/med,1),
             lo=round(min(tot)), hi=round(max(tot)))
}))
fwrite(conus, file.path(FIA,OUT_CO))

cat("INTER-MODEL UNCERTAINTY, CONUS reserve total (Tg C, full-coverage models FVS/YC/CBM):\n")
print(conus)
cat("\nMedian between-model CV by year (state-level structural spread):\n")
print(ens[, .(median_state_CV_pct=round(median(between_model_cv_pct),1),
              max_state_CV_pct=round(max(between_model_cv_pct),1)), by=year])
cat("\nExample state bands (2100):\n")
print(ens[year==2100 & state %in% c("ME","OR","MN","GA","CA","PA","OH"),
          .(state, median, lo90, hi90, between_model_cv_pct, n_models)])

cat("\nVARIANCE DECOMPOSITION (mean component SD, Tg C) - structural vs parameter vs sampling:\n")
print(ens[, .(between_model_struct=round(mean(between_model_sd),1),
              within_fvs_param=round(mean(within_fvs_param),1),
              anchor_sampling=round(mean(anchor_se),1)), by=year])
cat("\nStructural / parameter SD ratio (states with a real FVS posterior band):\n")
pst <- ens[within_fvs_src=="posterior" & within_fvs_param>0]
print(pst[, .(struct_over_param=round(mean(between_model_sd/within_fvs_param),1)), by=year])
