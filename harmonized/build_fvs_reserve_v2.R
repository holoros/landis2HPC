#!/usr/bin/env Rscript
# build_fvs_reserve_v2.R
#
# Proper FVS reserve trajectory from the per-stand FVS densities (not the partial
# treemap summary). Reads conus_*.csv (STAND_CN, STATE, YEAR, CONFIG, AGB_TONS_AC),
# state-mean per-ha carbon by year, interpolated to the harmonized grid and anchored
# to the FIA design total. Output feeds apply_harvest_scenarios.R, so FVS runs the
# SAME common harvest as LANDIS (apples-to-apples), not its native managed run.
#
#   Mg C/ha = AGB_TONS_AC * 2.2417 (ton/ac -> Mg/ha) * 0.5 (carbon fraction)
#   total(t) = FIA_total * mean_perha(t) / mean_perha(2025)
#
# Output: fvs_reserve_anchored.csv (model, dom, scenario=reserve, year, agc_TgC_anchored, agc_TgC_anchored_se)
# module load gcc/12.3.0; module load R/4.4.0

suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
DIR <- "/fs/scratch/PUOM0008/crsfaaron/fvs_stress/out_gompit_v3"
FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,VA=51,WA=53,WV=54,WI=55,WY=56)

fs <- list.files(DIR, pattern="^conus_.*\\.csv$", full.names=TRUE)
d  <- rbindlist(lapply(fs, function(f) tryCatch(
        fread(f, select=c("STATE","YEAR","CONFIG","AGB_TONS_AC")), error=function(e) NULL)), fill=TRUE)
cfgs <- unique(d$CONFIG)
cfg  <- c("gompit","calibrated","default")[c("gompit","calibrated","default") %in% cfgs][1]
cat("configs present:", paste(cfgs, collapse=","), "| using:", cfg, "\n")
d <- d[CONFIG==cfg & !is.na(AGB_TONS_AC)]
d[, mgC_ha := AGB_TONS_AC * 2.2417 * 0.5]
ph <- d[, .(perha = mean(mgC_ha)), by=.(STATE, YEAR)][order(STATE, YEAR)]

anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, fia=agc_TgC_design, cv=cv_pct)]
tgt <- c(2025,2050,2075,2100)
out <- rbindlist(lapply(intersect(unique(ph$STATE), names(FIPS)), function(st) {
  s <- ph[STATE==st]; if (nrow(s) < 2) return(NULL)
  tr <- approx(s$YEAR, s$perha, tgt, rule=2)$y
  a <- anc[state==st]; if (!nrow(a) || tr[1]<=0) return(NULL)
  tot <- a$fia * tr / tr[1]
  data.table(model="FVS", dom=sprintf("%02d", FIPS[st]), scenario="reserve",
             year=tgt, agc_TgC_anchored=round(tot,3), agc_TgC_anchored_se=round(tot*a$cv/100,3))
}))
fwrite(out, file.path(FIA,"fvs_reserve_anchored.csv"))
cat(sprintf("FVS reserve anchored: %d states\n", uniqueN(out$dom)))
print(dcast(out[year %in% c(2025,2100)], dom~year, value.var="agc_TgC_anchored")[1:8])
