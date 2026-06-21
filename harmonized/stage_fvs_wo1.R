#!/usr/bin/env Rscript
# stage_fvs_wo1.R - promote the corrected WO-1 FVS calibrated reserve to the
# canonical filename the integration reads, matching the canonical schema.
suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
d <- fread(file.path(FIA,"fvs_reserve_calibrated_wo1_anchored.csv"))
out <- d[, .(model="FVS", dom=sprintf("%02d",as.integer(dom)), scenario, year,
             agc_TgC_anchored, agc_TgC_anchored_se)]
fwrite(out, file.path(FIA,"fvs_reserve_calibrated_anchored.csv"))
cat("promoted calibrated anchored: states", uniqueN(out$dom),
    "2100 sum", round(out[year==2100, sum(agc_TgC_anchored)]), "TgC\n")
