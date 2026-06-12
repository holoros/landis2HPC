#!/usr/bin/env Rscript
# build_yc_reserve.R
#
# Yield-curve reserve trajectory re-anchored to the harmonized FIA design value
# and emitted in the common reserve schema, so the yield curves run the SAME
# common harvest as LANDIS and FVS (apples-to-apples) instead of their own native
# Harvest_* scenarios. Reads the per-state canonical yield-curve CI files
# (ci_yc_fiadb_<st>_<rcp>.csv), takes the No_harvest scenario's state-total
# aboveground carbon (mmt_agc_mean, Tg C), and anchors year-0 to the FIA design
# total. As with FVS/LANDIS the anchor is a ratio, so unit constants cancel and
# only the reserve growth shape carries through.
#
#   total(t) = FIA_total * agc(t) / agc(2025)
#
# Output: yc_reserve_anchored.csv (model=YC, dom, scenario=reserve, year,
#         agc_TgC_anchored, agc_TgC_anchored_se) -> apply_harvest_scenarios.R
# module load gcc/12.3.0; module load R/4.4.0

suppressPackageStartupMessages(library(data.table))
ga <- function(f,d=NA){a<-commandArgs(TRUE);i<-match(f,a);if(is.na(i)||i==length(a))d else a[i+1]}
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
CAN <- ga("--canon","/users/PUOM0008/crsfaaron/yield_curves_conus/canonical")
RCP <- ga("--rcp","rcp45")     # yield curves carry rcp45/85 only; rcp45 = near-current headline
OUT <- ga("--out", file.path(FIA,"yc_reserve_anchored.csv"))

FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,
          LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,
          NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,
          VA=51,WA=53,WV=54,WI=55,WY=56)
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, fia=agc_TgC_design, cv=cv_pct)]

out <- rbindlist(lapply(names(FIPS), function(st) {
  f <- file.path(CAN, sprintf("ci_yc_fiadb_%s_%s.csv", tolower(st), RCP))
  if (!file.exists(f)) return(NULL)
  d <- fread(f)
  if (!all(c("scenario","year","mmt_agc_mean") %in% names(d))) return(NULL)
  r <- d[scenario == "No_harvest", .(agc = mean(mmt_agc_mean)), by = year][order(year)]
  r <- r[year >= 2025 & year <= 2100]
  a <- anc[state == st]
  if (!nrow(a) || !(2025 %in% r$year) || r$agc[r$year == 2025] <= 0) return(NULL)
  tot <- a$fia * r$agc / r$agc[r$year == 2025]
  data.table(model="YC", dom=sprintf("%02d", FIPS[st]), scenario="reserve",
             year=r$year, agc_TgC_anchored=round(tot,3), agc_TgC_anchored_se=round(tot*a$cv/100,3))
}))
fwrite(out, OUT)
cat(sprintf("YC reserve anchored (%s): %d states -> %s\n", RCP, uniqueN(out$dom), OUT))
print(dcast(out[year %in% c(2025,2100)], dom~year, value.var="agc_TgC_anchored")[1:8])
