#!/usr/bin/env Rscript
# harmonized_aggregate.R
#
# Integration layer for the harmonized cross-model assessment. Paints per-plot
# model output onto the landscape via TreeMap area weights, aggregates to a
# spatial domain by year, rescales to the FIA year-0 design anchor, and runs the
# acceptance gate.
#
# PLOT LINKAGE: model plots and TreeMap donor plots are joined on PHYSICAL PLOT
# identity (STATECD_COUNTYCD_PLOT, the "pid"), not the raw control number, since
# the two sources carry different inventory-cycle CNs for the same plot. The
# crosswalk cn2pid.csv (CN, pid, STATECD) is built once from ENTIRE_PLOT.
#
# Common per-plot schema (long): model, scenario, PLT_CN, year, agc_MgC_ha
# Rescale: factor(model,state) = anchor_TgC(state) / model_TgC(model,state,year0);
#          agc_anchored(t) = agc(t) * factor ; isolates dynamics, common year-0.
#
# Usage: Rscript harmonized_aggregate.R --model-output mo.csv --out harm_state.csv
# module load gcc/12.3.0; module load R/4.4.0

suppressPackageStartupMessages(library(data.table))
args <- commandArgs(trailingOnly = TRUE)
ga <- function(f, d = NA) { i <- match(f, args); if (is.na(i) || i == length(args)) d else args[i+1] }
fia        <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
area_csv   <- "/fs/scratch/PUOM0008/crsfaaron/fvs_stress/plt_area_treemap.csv"
anchor_csv <- file.path(fia, "fia_agc_anchor_design_by_state.csv")
cn2pid_csv <- file.path(fia, "cn2pid.csv")

FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,
          KS=20,KY=21,LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,
          NV=32,NH=33,NJ=34,NM=35,NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,
          SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,VA=51,WA=53,WV=54,WI=55,WY=56)

cn2pid <- fread(cn2pid_csv, integer64 = "character"); cn2pid[, CN := as.character(CN)]

# TreeMap area per physical plot
area <- fread(area_csv, select = c("PLT_CN","area_ha"), integer64 = "character")
area[, PLT_CN := as.character(PLT_CN)]
area <- merge(area, cn2pid, by.x = "PLT_CN", by.y = "CN")
area_pid <- area[, .(area_ha = sum(area_ha), STATECD = STATECD[1]), by = pid]

# model output -> physical plot
mo <- fread(ga("--model-output"), integer64 = "character"); mo[, PLT_CN := as.character(PLT_CN)]
mo <- merge(mo, cn2pid[, .(CN, pid)], by.x = "PLT_CN", by.y = "CN")

d <- merge(mo, area_pid, by = "pid")                 # physical-plot join
d[, dom := sprintf("%02d", STATECD)]
d[, mgC := agc_MgC_ha * area_ha]
agg <- d[, .(area_ha = sum(area_ha), agc_TgC = sum(mgC)/1e6), by = .(model, scenario, dom, year)]
agg[, per_ha_MgC := round(agc_TgC*1e6/area_ha, 2)]

## anchor rescale + SE propagation
if (file.exists(anchor_csv)) {
  anc <- fread(anchor_csv)
  anc[, dom := sprintf("%02d", FIPS[state])]
  y0 <- min(agg$year)
  base0 <- agg[year == y0, .(m0 = mean(agc_TgC)), by = .(model, dom)]
  base0 <- merge(base0, anc[, .(dom, anchor_TgC = agc_TgC_design, anchor_cv = cv_pct)], by = "dom")
  base0[, factor := anchor_TgC / m0]
  agg <- merge(agg, base0[, .(model, dom, factor, anchor_cv)], by = c("model","dom"), all.x = TRUE)
  agg[, agc_TgC_anchored := round(agc_TgC * factor, 3)]
  agg[, agc_TgC_anchored_se := round(agc_TgC_anchored * anchor_cv/100, 3)]
}

setorder(agg, model, scenario, dom, year)
fwrite(agg, ga("--out","harmonized_state.csv"))

## coverage + acceptance
cov <- d[year == min(year), .(painted_pids = uniqueN(pid), area_ha = sum(area_ha)), by = dom]
cat("painting coverage by state (physical plots, ha):\n"); print(cov)
sc <- agg[, .(scen = paste(sort(unique(scenario)), collapse=",")), by = model]
cat("identical scenario list across models:", length(unique(sc$scen)) == 1, "\n")
if ("agc_TgC_anchored" %in% names(agg)) {
  chk <- agg[year == min(year), .(spread = round(max(agc_TgC_anchored)/min(agc_TgC_anchored),4)), by = dom]
  cat("post-anchor year-0 agreement (should be 1):\n"); print(chk)
}
cat(sprintf("wrote %s: %d rows, %d states, %d models, %d scenarios\n",
            ga("--out","harmonized_state.csv"), nrow(agg),
            uniqueN(agg$dom), uniqueN(agg$model), uniqueN(agg$scenario)))
