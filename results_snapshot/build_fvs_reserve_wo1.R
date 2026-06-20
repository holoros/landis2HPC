#!/usr/bin/env Rscript
# build_fvs_reserve_wo1.R
# Corrected base CONUS FVS reserve (SDIMAX WO-1 fix). Aggregates out_conus_wo1
# per-stand AGB to a per-state per-ha trajectory and anchors to FIA design totals,
# for BOTH default and calibrated configs.
#   Mg C/ha = AGB_TONS_AC * 2.2417 * 0.5
#   total(t) = FIA_total * mean_perha(t) / mean_perha(2025)
set.seed(42)
suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
DIR <- "/fs/scratch/PUOM0008/crsfaaron/fvs_stress/out_conus_wo1"
elog <- function(...) cat(sprintf(...), file="/tmp/wo1_err.txt", append=TRUE)
FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,VA=51,WA=53,WV=54,WI=55,WY=56)
fs <- list.files(DIR, pattern="^conus_.*\\.csv$", full.names=TRUE)
cat(sprintf("reading %d csv files\n", length(fs)))
d <- rbindlist(lapply(fs, function(f) tryCatch(
       fread(f, select=c("STAND_CN","STATE","YEAR","CONFIG","AGB_TONS_AC")),
       error=function(e){elog("read fail %s: %s\n", f, conditionMessage(e)); NULL})), fill=TRUE)
cat(sprintf("rows=%d  configs=%s\n", nrow(d), paste(unique(d$CONFIG), collapse=",")))
d <- d[!is.na(AGB_TONS_AC)]
d[, mgC_ha := AGB_TONS_AC * 2.2417 * 0.5]
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, fia=agc_TgC_design, cv=cv_pct)]
tgt <- c(2025,2050,2075,2100)
# per-state matched-plot diagnostic (config-independent stand count)
diag <- d[CONFIG==CONFIG[1], .(n_stands=uniqueN(STAND_CN)), by=STATE][order(n_stands)]
fwrite(diag, file.path(FIA,"fvs_wo1_matched_stands_by_state.csv"))
cat("LOW matched-stand states (<50):\n"); print(diag[n_stands<50])
build <- function(cfg){
  dd <- d[CONFIG==cfg]
  ph <- dd[, .(perha=mean(mgC_ha), n=uniqueN(STAND_CN)), by=.(STATE,YEAR)][order(STATE,YEAR)]
  out <- rbindlist(lapply(intersect(unique(ph$STATE), names(FIPS)), function(st){
    s <- ph[STATE==st]; if (nrow(s)<2) return(NULL)
    tr <- approx(s$YEAR, s$perha, tgt, rule=2)$y
    a <- anc[state==st]; if(!nrow(a) || tr[1]<=0) return(NULL)
    tot <- a$fia * tr / tr[1]
    data.table(model="FVS", arm=cfg, dom=sprintf("%02d",FIPS[st]), state=st, scenario="reserve",
               year=tgt, agc_TgC_anchored=round(tot,3), agc_TgC_anchored_se=round(tot*a$cv/100,3),
               n_matched=s$n[1])
  }))
  fn <- file.path(FIA, sprintf("fvs_reserve_%s_wo1_anchored.csv", cfg))
  fwrite(out, fn)
  cat(sprintf("%s: %d states -> %s  (CONUS 2025=%.0f 2100=%.0f TgC)\n",
      cfg, uniqueN(out$dom), basename(fn),
      out[year==2025, sum(agc_TgC_anchored)], out[year==2100, sum(agc_TgC_anchored)]))
  out
}
res <- rbindlist(lapply(c("default","calibrated"), build))
fwrite(res, file.path(FIA,"fvs_reserve_wo1_anchored_both.csv"))
cat("DONE\n")
