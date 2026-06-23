#!/usr/bin/env Rscript
# build_cem_reserve.R
#
# CEM reserve trajectory re-anchored to the harmonized FIA design value and
# emitted in the common reserve schema, so CEM runs the SAME common harvest as
# LANDIS / FVS / yield curves (apples-to-apples) instead of its own native
# Harvest_* scenarios. Reads each state's newest conus_harmonized_sdimax CEM
# output (output/<ST>_*_conus_harmonized_sdimax_<ST>/ci_summaries.csv), takes the
# No_harvest scenario's mean_carbon by cycle, maps cycle -> year, and anchors
# year-0 to the FIA design total. As with the other models the anchor is a ratio,
# so CEM's internal carbon units cancel and only the reserve growth shape carries.
#
#   total(t) = FIA_total * carbon(t) / carbon(2025)
#   year     = 2025 + 5*(cycle-1), kept through 2100
#
# Output: cem_reserve_anchored.csv (model=CEM, dom, scenario=reserve, year,
#         agc_TgC_anchored, agc_TgC_anchored_se) -> apply_harvest_scenarios.R
# module load gcc/12.3.0 R/4.4.0

suppressPackageStartupMessages(library(data.table))
ga <- function(f,d=NA){a<-commandArgs(TRUE);i<-match(f,a);if(is.na(i)||i==length(a))d else a[i+1]}
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
OUTDIR <- ga("--cem","/users/PUOM0008/crsfaaron/fia_cem_projections/output")
OUT <- ga("--out", file.path(FIA,"cem_reserve_anchored.csv"))

FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,
          LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,
          NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,
          VA=51,WA=53,WV=54,WI=55,WY=56)
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, fia=agc_TgC_design, cv=cv_pct)]

out <- rbindlist(lapply(names(FIPS), function(st) {
  ds <- list.files(OUTDIR, pattern=sprintf("conus2100_%s$", st), full.names=TRUE)
  if (!length(ds)) ds <- list.files(OUTDIR, pattern=sprintf("conus_harmonized_sdimax_%s$", st), full.names=TRUE)
  if (!length(ds)) return(NULL)
  f <- file.path(sort(ds)[length(ds)], "ci_summaries.csv")   # newest
  if (!file.exists(f)) return(NULL)
  d <- fread(f)
  if (!all(c("scenario","cycle","mean_carbon_mean") %in% names(d))) return(NULL)
  r <- d[scenario == "No_harvest", .(cycle=as.integer(cycle),
                                     carbon=mean_carbon_mean,
                                     lo=mean_carbon_lo, hi=mean_carbon_hi)][order(cycle)]
  r[, year := 2025 + 5*(cycle-1)]
  r <- r[year >= 2025 & year <= 2100]
  a <- anc[state == st]
  if (!nrow(a) || !(2025 %in% r$year) || r$carbon[r$year==2025] <= 0) return(NULL)
  c0 <- r$carbon[r$year==2025]
  tot <- a$fia * r$carbon / c0
  # SE: combine FIA anchor CV with CEM's own relative CI half-width
  relci <- mean((r$hi - r$lo) / (2*r$carbon), na.rm=TRUE)
  cv <- sqrt((a$cv/100)^2 + relci^2)
  data.table(model="CEM", dom=sprintf("%02d", FIPS[st]), scenario="reserve",
             year=r$year, agc_TgC_anchored=round(tot,3), agc_TgC_anchored_se=round(tot*cv,3))
}))
fwrite(out, OUT)
cat(sprintf("CEM reserve anchored: %d states -> %s\n", uniqueN(out$dom), OUT))
print(dcast(out[year %in% c(2025,2100)], dom~year, value.var="agc_TgC_anchored")[1:8])
