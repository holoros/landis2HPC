#!/usr/bin/env Rscript
# build_fvs_reserve.R
#
# Build an FVS "reserve" (baseline growth) trajectory per state in the harmonized
# reserve format, anchored to the FIA design total, so FVS can flow through the
# SAME harmonized scenario machinery (apply_harvest_scenarios.R) as LANDIS.
#
# FVS CONUS projection: fvs_treemap_vs_fiadb.csv (scale=state) gives TreeMap-painted
# live carbon (TgC) at 2030/2075/2125, all 48 states, FIADB-validated. We interpolate
# to the harmonized grid (2025,2050,2075,2100), anchor year-0 to the FIA design total
# (factor = FIA_y0 / FVS_y0), and emit reserve rows.
#
# Output: fvs_reserve_anchored.csv (model, dom, scenario, year, agc_TgC_anchored, agc_TgC_anchored_se)
# module load gcc/12.3.0; module load R/4.4.0

suppressPackageStartupMessages(library(data.table))
FIA   <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
fvs_csv <- "/fs/scratch/PUOM0008/crsfaaron/fvs_stress/treemap_conus/fvs_treemap_vs_fiadb.csv"
FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,VA=51,WA=53,WV=54,WI=55,WY=56)

fvs <- fread(fvs_csv)[scale=="state", .(state=key, year, fvs=treemap_TgC)]
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, fia=agc_TgC_design, cv=cv_pct)]

tgt <- c(2025,2050,2075,2100)
out <- rbindlist(lapply(unique(fvs$state), function(st) {
  d <- fvs[state==st][order(year)]
  if (nrow(d) < 2) return(NULL)
  traj <- approx(d$year, d$fvs, tgt, rule=2)$y         # interp/extrapolate to harmonized grid
  a <- anc[state==st]; if (!nrow(a)) return(NULL)
  factor <- a$fia / traj[1]                              # anchor year-0 to FIA design
  data.table(model="FVS", dom=sprintf("%02d", FIPS[st]), scenario="reserve",
             year=tgt, agc_TgC_anchored=round(traj*factor,3),
             agc_TgC_anchored_se=round(traj*factor*a$cv/100,3))
}))
fwrite(out, file.path(FIA,"fvs_reserve_anchored.csv"))
cat(sprintf("FVS reserve anchored: %d states\n", uniqueN(out$dom)))
print(out[dom %in% c("53","27","13"), .(dom,year,agc_TgC_anchored)])
