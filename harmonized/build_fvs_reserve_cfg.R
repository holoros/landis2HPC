#!/usr/bin/env Rscript
# build_fvs_reserve_cfg.R
#
# Generalized FVS reserve builder for the 4-version FVS matrix
# (default|calibrated x FIADB|TreeMap). This script produces the FIADB-allocation
# reserve for a chosen FVS config; TreeMap allocation is a separate painting step.
#
#   --dir     density dir: out_fvs_v3 (CONFIG=default) or out_gompit_v3 (CONFIG=gompit)
#   --config  CONFIG value to select: default | gompit (=calibrated) | calibrated
#   --out     output csv
#
# Same anchor as every other model: state-mean per-ha carbon -> rescale year-0 to the
# FIA design total. Replicates build_fvs_reserve_v2's logic (all stress bands averaged,
# YEAR calendar grid) so default and calibrated are directly comparable.
#   Mg C/ha = AGB_TONS_AC * 2.2417 * 0.5 ;  total(t) = FIA * perha(t)/perha(2025)
# module load gcc/12.3.0 R/4.4.0

suppressPackageStartupMessages(library(data.table))
ga <- function(f,d=NA){a<-commandArgs(TRUE);i<-match(f,a);if(is.na(i)||i==length(a))d else a[i+1]}
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
DIR <- ga("--dir","/fs/scratch/PUOM0008/crsfaaron/fvs_stress/out_gompit_v3")
CFG <- ga("--config","gompit")
MODEL_TAG <- ga("--model", paste0("FVS_", CFG))
OUT <- ga("--out", file.path(FIA, sprintf("fvs_reserve_%s_anchored.csv", CFG)))

FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,
          LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,
          NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,
          VA=51,WA=53,WV=54,WI=55,WY=56)
fs <- list.files(DIR, pattern="^conus_.*\\.csv$", full.names=TRUE)
d  <- rbindlist(lapply(fs, function(f) tryCatch(
        fread(f, select=c("STATE","YEAR","CONFIG","AGB_TONS_AC")), error=function(e) NULL)), fill=TRUE)
d <- d[CONFIG==CFG & !is.na(AGB_TONS_AC)]
if (!nrow(d)) stop(sprintf("no rows with CONFIG=%s in %s", CFG, DIR))
d[, mgC_ha := AGB_TONS_AC * 2.2417 * 0.5]
ph <- d[, .(perha = mean(mgC_ha)), by=.(STATE, YEAR)][order(STATE, YEAR)]
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, fia=agc_TgC_design, cv=cv_pct)]
tgt <- c(2025,2050,2075,2100)
out <- rbindlist(lapply(intersect(unique(ph$STATE), names(FIPS)), function(st) {
  s <- ph[STATE==st]; if (nrow(s) < 2) return(NULL)
  tr <- approx(s$YEAR, s$perha, tgt, rule=2)$y
  a <- anc[state==st]; if (!nrow(a) || tr[1]<=0) return(NULL)
  data.table(model=MODEL_TAG, dom=sprintf("%02d", FIPS[st]), scenario="reserve",
             year=tgt, agc_TgC_anchored=round(a$fia*tr/tr[1],3), agc_TgC_anchored_se=round(a$fia*tr/tr[1]*a$cv/100,3))
}))
fwrite(out, OUT)
cat(sprintf("FVS reserve [%s] from %s: %d states -> %s\n", CFG, basename(DIR), uniqueN(out$dom), OUT))
print(dcast(out[year %in% c(2025,2100)], dom~year, value.var="agc_TgC_anchored")[1:6])
