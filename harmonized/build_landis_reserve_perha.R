#!/usr/bin/env Rscript
# build_landis_reserve_perha.R
#
# State-level harmonized reserve trajectory for LANDIS WITHOUT a painting/donor
# dependency: per-state mean per-ha carbon from all of the state's LANDIS plots,
# anchored so the year-0 total equals the FIA design total. Painting is reserved
# for sub-state maps; the state aggregate only needs plot-mean per-ha + FIA total.
# This includes every state with LANDIS runs (fixes the WI/MI paint dropout).
#
#   total(t) = FIA_total * mean_perha(t) / mean_perha(2025)
#
# Output: harmonized_landis_reserve_6state.csv (model, dom, scenario=reserve,
#         year, agc_TgC_anchored, agc_TgC_anchored_se), the --reserve input to
#         apply_harvest_scenarios.R.
# module load gcc/12.3.0; module load R/4.4.0

suppressPackageStartupMessages(library(data.table))
ga <- function(f,d=NA){a<-commandArgs(TRUE);i<-match(f,a);if(is.na(i)||i==length(a))d else a[i+1]}
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
# CONUS FIPS lookup; --states selects which to build (default the original 6).
FIPS_ALL <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,
              LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,
              NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,
              VA=51,WA=53,WV=54,WI=55,WY=56)
sts  <- if (!is.na(ga("--states",NA))) strsplit(ga("--states"),",")[[1]] else c("WA","MN","IN","OH","WI","MI")
FIPS <- FIPS_ALL[sts]
OUT  <- ga("--out", file.path(FIA, sprintf("harmonized_landis_reserve_%dstate.csv", length(sts))))
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, fia=agc_TgC_design, cv=cv_pct)]

out <- rbindlist(lapply(names(FIPS), function(st) {
  f <- file.path(FIA, paste0("landis_", st, "_reserve.csv")); if (!file.exists(f)) return(NULL)
  d <- fread(f); ph <- d[, .(perha = mean(agc_MgC_ha)), by = year][order(year)]
  a <- anc[state == st]; if (!nrow(a) || !(2025 %in% ph$year)) return(NULL)
  tot <- a$fia * ph$perha / ph$perha[ph$year == 2025]
  data.table(model="LANDIS", dom=sprintf("%02d", FIPS[st]), scenario="reserve",
             year=ph$year, agc_TgC_anchored=round(tot,3), agc_TgC_anchored_se=round(tot*a$cv/100,3))
}))
fwrite(out, OUT)
cat(sprintf("reserve built for %d states -> %s\n", uniqueN(out$dom), OUT))
print(dcast(out[year %in% c(2025,2100)], dom~year, value.var="agc_TgC_anchored"))
