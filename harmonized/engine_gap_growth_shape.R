# =============================================================================
# Title: Engine gap reassessed - absolute density vs anchored growth shape
# Author: A. Weiskittel
# Date: 2026-06-14
# Description: The harmonized CBM member is anchored to the FIA 2025 total, so the
#   projection uses the growth RATIO perha(t)/perha(2025); absolute density level
#   cancels. The relevant intra-CBM uncertainty is therefore the divergence in
#   GROWTH SHAPE between GCBM and libcbm, not the absolute density gap. This script
#   computes both for the 6 GCBM-complete states and compares.
# =============================================================================
suppressPackageStartupMessages(library(data.table))
GST <- "/users/PUOM0008/crsfaaron/cbm_states/states"
LIB <- "/users/PUOM0008/crsfaaron/cbm_states/cross_state/libcbm"
AG <- c("SoftwoodMerch","SoftwoodFoliage","SoftwoodOther","HardwoodMerch","HardwoodFoliage","HardwoodOther")
states <- c("GA","IN","ME","MN","OR","WA")

res <- rbindlist(lapply(states, function(st){
  # GCBM per-ha AG live C trajectory
  g <- fread(file.path(GST, st, "10_outputs", "gcbm_state_aggregate.csv"))[variable=="AG_Biomass_C"][order(step)]
  if (!nrow(g)) return(NULL)
  g_n <- nrow(g); g_yrs <- (g_n-1)*5                       # 5-yr steps
  g_growth_ann <- (g$mean_per_ha[g_n]/g$mean_per_ha[1])^(1/max(g_yrs,1)) - 1
  # libcbm per-ha AG live C trajectory (b13 50yr)
  lf <- file.path(LIB, st, sprintf("libcbm_pools_%s_b13_50yr.csv", st))
  if (!file.exists(lf)) return(NULL)
  d <- fread(lf); d[, ag := rowSums(.SD), .SDcols=AG]; d[, perha := ag/total_area_ha]
  d <- d[order(timestep)]; l_n <- nrow(d); l_yrs <- d$timestep[l_n]-d$timestep[1]
  l_growth_ann <- (d$perha[l_n]/d$perha[1])^(1/max(l_yrs,1)) - 1
  data.table(state=st,
    gcbm_perha_ann_pct = round(100*g_growth_ann,3),
    libcbm_perha_ann_pct = round(100*l_growth_ann,3),
    growth_gap_ann_pct = round(100*(g_growth_ann - l_growth_ann),3),
    # over a 75-yr projection, the anchored trajectory divergence:
    anchored_gap_75yr_pct = round(100*((1+g_growth_ann)^75/(1+l_growth_ann)^75 - 1),1))
}))
# bring in the absolute density gap for contrast
eg <- fread("/fs/scratch/PUOM0008/crsfaaron/FIA/cbm_engine_gap.csv")
res <- merge(res, eg[,.(state, abs_density_gap_pct=gcbm_over_libcbm_pct)], by="state", all.x=TRUE)
fwrite(res, "/fs/scratch/PUOM0008/crsfaaron/FIA/engine_gap_growth_vs_density.csv")
cat("=== Engine gap: anchored growth-shape vs absolute density ===\n")
print(res)
cat(sprintf("\nMedian |abs density gap|: %.1f%%   Median |anchored 75yr growth-shape gap|: %.1f%%\n",
            median(abs(res$abs_density_gap_pct)), median(abs(res$anchored_gap_75yr_pct))))
cat("If the anchored growth-shape gap << absolute density gap, the density gap overstates CBM\n")
cat("uncertainty in the harmonized (FIA-anchored) framework, and the band should use growth shape.\n")
