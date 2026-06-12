#!/usr/bin/env Rscript
# western_growth_compare.R - early-period (2025->2050) reserve growth rate by model
# for western states, from the anchored reserves (all share the FIA 2025 anchor, so
# the early growth rate is a direct, comparable measure of each model's growth engine).
suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
f2a <- c(CA=6, OR=41, WA=53, ID=16, MT=30, NM=35, CO=8, NV=32)
g <- function(fn, lab){
  d <- fread(file.path(FIA,fn))[scenario=="reserve"]
  d[, dom := sprintf("%02d", as.integer(dom))]
  rbindlist(lapply(names(f2a), function(ab){
    s <- d[dom == sprintf("%02d", f2a[[ab]])][order(year)]
    if (nrow(s) < 2) return(NULL)
    v0  <- approx(s$year, s$agc_TgC_anchored, 2025, rule=2)$y
    v25 <- approx(s$year, s$agc_TgC_anchored, 2050, rule=2)$y
    v100<- approx(s$year, s$agc_TgC_anchored, 2100, rule=2)$y
    data.table(ST=ab, model=lab, g2550=round(100*(v25-v0)/v0), g2100=round(100*(v100-v0)/v0))
  }))
}
res <- rbind(g("fvs_reserve_calibrated_anchored.csv","FVScal"),
             g("fvs_reserve_default_anchored.csv","FVSdef"),
             g("cbm_reserve_anchored.csv","CBM"),
             g("yc_reserve_anchored.csv","YC"))
cat("2025->2050 reserve growth % by model (western):\n")
print(dcast(res, ST~model, value.var="g2550"))
cat("\n2025->2100 reserve growth % by model (western):\n")
print(dcast(res, ST~model, value.var="g2100"))
