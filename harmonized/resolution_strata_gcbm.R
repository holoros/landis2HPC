# =============================================================================
# Title: Resolution / temporal / strata information-loss analysis (GCBM Maine)
# Author: A. Weiskittel
# Date: 2026-06-14
# Description: For PERSEUS ingestion, find the coarsest representation of the GCBM
#   spatial carbon maps that preserves decision-relevant information.
#   (A) SPATIAL: aggregate AG live C from 30 m to 90/270/810/990 m; report total-C
#       bias (should be ~0 under area-mean) and the fraction of spatial variance
#       retained (between-coarse-cell var / native var).
#   (B) TEMPORAL: state total C trajectory across the 5-yr steps; how well do
#       coarser steps (10/15 yr) reconstruct it.
#   (C) STRATA: stratify native cells by GCBM stand-age class; variance explained
#       by stratum means = how few numbers reproduce the map (compression for PERSEUS).
# Dependencies: FIA/gcbm_rasters/ME/{AG_Biomass_C_<yr>,Age_<yr>}.tif
# =============================================================================
suppressPackageStartupMessages({library(terra); library(data.table)})
RAS <- "/fs/scratch/PUOM0008/crsfaaron/FIA/gcbm_rasters/ME"; OUT <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
YR <- 2050
ag <- rast(file.path(RAS, sprintf("AG_Biomass_C_%d.tif", YR)))
ag <- ifel(ag <= 0, NA, ag)                    # forest only
res_m <- mean(res(ag)) * 111320                # approx m per deg at ME lat -> ~m
cat(sprintf("native ~%.0f m, %d x %d cells\n", res_m, nrow(ag), ncol(ag)))
A_native <- prod(res(ag))                      # deg^2 (cancels in ratios)
tot_native <- as.numeric(global(ag, "sum", na.rm=TRUE))
var_native <- as.numeric(global(ag, "var", na.rm=TRUE))

# --- (A) spatial aggregation ---
facs <- c(1,3,9,27,33)
spat <- rbindlist(lapply(facs, function(f){
  r <- if (f==1) ag else aggregate(ag, fact=f, fun="mean", na.rm=TRUE)
  tot <- as.numeric(global(r, "sum", na.rm=TRUE)) * f*f   # sum of means * cells-per-coarse = conserved total
  vbetween <- as.numeric(global(r, "var", na.rm=TRUE))
  data.table(res_m=round(res_m*f), fact=f, n_cells=as.numeric(global(!is.na(r),"sum")$sum),
             total_rel_pct=round(100*(tot/ (tot_native) - 1),3),
             var_retained_pct=round(100*vbetween/var_native,1))
}))
fwrite(spat, file.path(OUT,"perseus_spatial_resolution.csv"))
cat("\n=== (A) SPATIAL aggregation (GCBM ME AG live C", YR, ") ===\n"); print(spat)

# --- (B) temporal ---
yrs <- c(2030,2035,2040,2045,2050)
traj <- rbindlist(lapply(yrs, function(y){ r<-rast(file.path(RAS,sprintf("AG_Biomass_C_%d.tif",y)))
  data.table(year=y, total=as.numeric(global(ifel(r<=0,NA,r)*cellSize(r,unit="ha"),"sum",na.rm=TRUE))/1e6) }))
# reconstruct from 10-yr (2030,2040,2050) and 15-yr (2030,2045) linear interpolation
rec10 <- approx(traj[year %in% c(2030,2040,2050)]$year, traj[year %in% c(2030,2040,2050)]$total, yrs)$y
rec15 <- approx(traj[year %in% c(2030,2045)]$year, traj[year %in% c(2030,2045)]$total, yrs)$y
traj[, `:=`(rec_10yr=round(rec10,2), rec_15yr=round(rec15,2))]
traj[, `:=`(err10_pct=round(100*(rec_10yr-total)/total,2), err15_pct=round(100*(rec_15yr-total)/total,2))]
fwrite(traj, file.path(OUT,"perseus_temporal_steps.csv"))
cat("\n=== (B) TEMPORAL: 5-yr trajectory + reconstruction error from coarser steps ===\n"); print(traj)

# --- (C) age-class strata ---
age <- rast(file.path(RAS, sprintf("Age_%d.tif", YR)))
agecls <- classify(age, rcl=matrix(c(-1,20,1, 20,40,2, 40,60,3, 60,80,4, 80,100,5,
  100,140,6, 140,200,7, 200,1e4,8), ncol=3, byrow=TRUE))
z <- zonal(ag, agecls, fun="mean", na.rm=TRUE); setDT(z); setnames(z, c("ageclass","mean_C"))
zc <- zonal(!is.na(ag), agecls, fun="sum", na.rm=TRUE); setDT(zc)
z[, n := zc[[2]]]
# variance explained by stratum means = between-stratum var / total var
grand <- tot_native/as.numeric(global(!is.na(ag),"sum")$sum)
between <- sum(z$n*(z$mean_C-grand)^2, na.rm=TRUE) / sum(z$n, na.rm=TRUE)
ve_age <- 100*between/var_native
fwrite(z, file.path(OUT,"perseus_age_strata.csv"))
cat("\n=== (C) AGE-CLASS STRATA (8 classes) ===\n"); print(z)
cat(sprintf("\nVariance explained by 8 age-class means alone: %.1f%%\n", ve_age))
cat(sprintf("Compression: %g forest cells -> 8 stratum means.\n", as.numeric(global(!is.na(ag),"sum")$sum)))
cat("\nWrote perseus_spatial_resolution / perseus_temporal_steps / perseus_age_strata.\n")
