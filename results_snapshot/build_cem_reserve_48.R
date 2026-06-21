#!/usr/bin/env Rscript
# build_cem_reserve_48.R
# Rebuild the CEM no-disturbance reserve for ALL 48 CONUS states from the
# conus2100 No_harvest outputs, anchored to FIA design totals. Replaces the
# stale 37-state cem_reserve_anchored.csv (the integrator self-deleted before GA
# landed). Method verified to reproduce the existing states exactly:
#   agc_TgC_anchored(t) = FIA_design_total * mean_carbon_NoHarvest(t)/mean_carbon_NoHarvest(2025)
#   cycle c -> year 2025 + 5*(c-1)   (16 cycles -> 2025..2100)
#   se(t) = agc(t) * relative MC sd from the No_harvest 95% CI
set.seed(42)
suppressPackageStartupMessages(library(data.table))
OUT  <- "/users/PUOM0008/crsfaaron/fia_cem_projections/output"
FIA  <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,VA=51,WA=53,WV=54,WI=55,WY=56)
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, fia=agc_TgC_design)]

dirs <- list.files(OUT, pattern="conus2100", full.names=TRUE)
dirs <- dirs[dir.exists(dirs)]
rows <- list()
for (d in dirs) {
  st <- sub("_.*","", basename(d))               # leading 2-letter state code
  if (!st %in% names(FIPS)) next
  f <- file.path(d, "ci_summaries.csv")
  if (!file.exists(f)) next
  if (file.info(f)$size < 50) { cat("SKIP empty ci_summaries:", st, "\n"); next }
  ci <- tryCatch(fread(f), error=function(e) NULL)
  if (is.null(ci) || !nrow(ci) || !("scenario" %in% names(ci))) { cat("SKIP unreadable:", st, "\n"); next }
  nh <- ci[scenario=="No_harvest"]; if (!nrow(nh)) next
  setorder(nh, cycle)
  fa <- anc[state==st, fia]; if (!length(fa) || !nrow(nh) || nh$mean_carbon_mean[1]<=0) next
  yr <- 2025 + 5*(nh$cycle - 1)
  shape <- nh$mean_carbon_mean / nh$mean_carbon_mean[1]
  agc <- fa * shape
  rel_sd <- (nh$mean_carbon_hi - nh$mean_carbon_lo) / (2*1.96*pmax(nh$mean_carbon_mean,1e-9))
  rows[[st]] <- data.table(model="CEM", dom=sprintf("%02d",FIPS[st]), scenario="reserve",
                           year=yr, agc_TgC_anchored=round(agc,3),
                           agc_TgC_anchored_se=round(agc*rel_sd,3))
}
res <- rbindlist(rows)
res <- res[year %in% seq(2025,2100,5)]
cat("states built:", uniqueN(res$dom), " (target 48)\n")
cat("missing FIPS:", paste(setdiff(names(FIPS), unique(names(FIPS)[match(as.integer(res$dom),FIPS)])), collapse=","), "\n")

## validation vs existing 37-state file
old <- fread(file.path(FIA,"cem_reserve_anchored.csv"))
old[, dom := sprintf("%02d", as.integer(dom))]
cmp <- merge(res[,.(dom,year,new=agc_TgC_anchored)], old[,.(dom,year,old=agc_TgC_anchored)], by=c("dom","year"))
cmp[, pct_diff := 100*(new-old)/old]
cat(sprintf("validation vs existing %d states: max abs pct diff = %.3f%%, mean = %.4f%%\n",
            uniqueN(old$dom), max(abs(cmp$pct_diff),na.rm=TRUE), mean(abs(cmp$pct_diff),na.rm=TRUE)))
cat("GA present:", any(res$dom=="13"), " | CONUS 2025 sum:", round(res[year==2025,sum(agc_TgC_anchored)]),
    " 2100 sum:", round(res[year==2100,sum(agc_TgC_anchored)]), "TgC\n")

if (max(abs(cmp$pct_diff),na.rm=TRUE) < 1.0) {
  file.copy(file.path(FIA,"cem_reserve_anchored.csv"),
            file.path(FIA,"cem_reserve_anchored.csv.bak_pre48"), overwrite=TRUE)
  fwrite(res, file.path(FIA,"cem_reserve_anchored_48.csv"))
  cat("WROTE cem_reserve_anchored_48.csv (validation passed; existing backed up)\n")
} else {
  fwrite(res, file.path(FIA,"cem_reserve_anchored_48_REVIEW.csv"))
  cat("VALIDATION DIFF > 1%; wrote _REVIEW copy, did NOT replace. Inspect before use.\n")
}
