#!/usr/bin/env Rscript
# lsog_proxy.R
#
# Late-successional / old-growth (LSOG) BIOMASS PROXY across scenarios. This is a
# placeholder for the age-based LSOG metric, which needs the metrics-output rerun
# (cohort age). Here LSOG = fraction of plots whose live AGC exceeds a high-biomass
# threshold (documented default 75 Mg C/ha ~ 150 Mg biomass/ha, a late-successional
# level). Biomass is a weak surrogate for age, so treat as indicative.
#
#   reserve: LSOG_res(t) = fraction of plots with agc_MgC_ha(t) > THRESH
#   scenarios: harvest removes LSOG from the harvested area each year:
#       dL/dt = dL_res/dt - h*L ,  h = HCS rate * multiplier  (any harvest of an
#       old stand ends its LSOG status, so area-based, prescription-independent)
#
# Output: harmonized_lsog_proxy_4state.csv (state, scenario, year, lsog_frac)
# module load gcc/12.3.0; module load R/4.4.0

suppressPackageStartupMessages(library(data.table))
ga <- function(f,d=NA){a<-commandArgs(TRUE);i<-match(f,a);if(is.na(i)||i==length(a))d else a[i+1]}
FIA   <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
hcs_csv <- "/users/PUOM0008/crsfaaron/cbm_states/cross_state/libcbm/tools_conus/14_outputs/uncertainty/hcs_harvest_rate_by_state.csv"
THRESH <- as.numeric(ga("--thresh","75"))            # Mg C/ha
mult <- c(reserve=0, BAU=1, conservation=0.6, intensive=2)
hcs <- fread(hcs_csv)[, .(state, rate=harvest_rate_pct_yr/100)]

out <- list()
for (st in c("WA","MN","IN","OH","WI","MI")) {
  f <- file.path(FIA, paste0("landis_", st, "_reserve.csv"))
  if (!file.exists(f)) next
  d <- fread(f)
  Lres <- d[, .(lsog = mean(agc_MgC_ha > THRESH)), by = year][order(year)]
  rate <- hcs[state == st, rate]; if (!length(rate)) rate <- 0
  yrs <- Lres$year; ann <- seq(min(yrs), max(yrs)); Lr <- approx(yrs, Lres$lsog, ann)$y
  for (scn in names(mult)) {
    h <- rate * mult[scn]
    L <- numeric(length(ann)); L[1] <- Lr[1]
    for (i in 2:length(ann)) L[i] <- max(min(L[i-1] + (Lr[i]-Lr[i-1]) - h*L[i-1], 1), 0)
    out[[length(out)+1]] <- data.table(state=st, scenario=scn, year=ann[ann %in% yrs],
                                        lsog_frac=round(L[ann %in% yrs],3))
  }
}
R <- rbindlist(out)
fwrite(R, file.path(FIA, "harmonized_lsog_proxy_4state.csv"))
print(dcast(R[year %in% c(2025,2100)], state+scenario~year, value.var="lsog_frac"))
