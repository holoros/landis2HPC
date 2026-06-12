#!/usr/bin/env Rscript
# add_nh_vt_landis_reserve.R - add the freshly calibrated NH and VT statewide LANDIS
# reserves to the harmonized LANDIS reserve (7 -> 9 states). The statewide build emits
# state_trajectory.csv (LANDIS year 0/25/50/75/100, median_Mg_ha biomass). Map LANDIS
# year -> calendar (0->2025 ... 75->2100; drop 100=2125, beyond horizon), anchor so
# 2025 == FIA design total (the ratio cancels biomass->carbon, so biomass is fine):
#   total(t) = FIA_total * perha(t)/perha(2025)
# module load gcc/12.3.0 R/4.4.0
suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
LAN <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states"
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, fia=agc_TgC_design, cv=cv_pct)]
FIPS <- c(NH=33, VT=50)
ymap <- c(`0`=2025, `25`=2050, `50`=2075, `75`=2100)   # 75 LANDIS yr = 2025..2100 window
add <- rbindlist(lapply(names(FIPS), function(st){
  tj <- fread(file.path(LAN, st, "perseus/statewide/reserve_v1/state_trajectory.csv"))
  tj <- tj[as.character(year) %in% names(ymap)]
  tj[, cyear := ymap[as.character(year)]]
  a <- anc[state==st]; p0 <- tj$median_Mg_ha[tj$cyear==2025]
  if (!nrow(a) || length(p0)!=1) return(NULL)
  tot <- a$fia * tj$median_Mg_ha / p0
  data.table(model="LANDIS", dom=sprintf("%02d", FIPS[st]), scenario="reserve",
             year=tj$cyear, agc_TgC_anchored=round(tot,3), agc_TgC_anchored_se=round(tot*a$cv/100,3))
}))
base <- fread(file.path(FIA,"harmonized_landis_reserve_7state.csv"))
nine <- rbind(base, add)
fwrite(nine, file.path(FIA,"harmonized_landis_reserve_9state.csv"))
cat(sprintf("LANDIS reserve: %d states -> harmonized_landis_reserve_9state.csv\n", uniqueN(nine$dom)))
print(add[, .(dom, year, agc_TgC_anchored)])
cat("NH/VT 2025->2100 growth %:\n")
print(add[year %in% c(2025,2100), .(g=100*(agc_TgC_anchored[year==2100]/agc_TgC_anchored[year==2025]-1)), by=dom])
