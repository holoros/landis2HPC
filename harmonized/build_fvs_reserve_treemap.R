#!/usr/bin/env Rscript
# build_fvs_reserve_treemap.R
#
# TreeMap-allocation FVS reserve (cells 3-4 of the 4-version FVS matrix). Instead
# of the FIADB-uniform state mean, this area-weights each FVS plot by its TreeMap
# imputed area (plt_area_treemap.csv) and aggregates to the state, then anchors to
# the FIA design total. FVS STAND_CN and TreeMap PLT_CN carry different inventory-
# cycle CNs, so both are mapped to the physical plot id (pid) via cn2pid.csv.
#
# CAVEAT: TreeMap area weights exist only for TreeMap donor plots (~65k), so this
# uses the FVS plots that are TreeMap donors (~30% of FVS plots) - the inherent
# donor-subset basis of TreeMap allocation. Compare against the FIADB version.
#
#   --dir out_fvs_v3|out_gompit_v3   --config default|gompit   --out file.csv
# module load gcc/12.3.0 R/4.4.0

suppressPackageStartupMessages(library(data.table))
ga <- function(f,d=NA){a<-commandArgs(TRUE);i<-match(f,a);if(is.na(i)||i==length(a))d else a[i+1]}
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"; FVS <- "/fs/scratch/PUOM0008/crsfaaron/fvs_stress"
DIR <- ga("--dir", file.path(FVS,"out_gompit_v3")); CFG <- ga("--config","gompit")
MODEL_TAG <- ga("--model", paste0("FVS_", CFG, "_TM")); OUT <- ga("--out", file.path(FIA, sprintf("fvs_reserve_%s_treemap_anchored.csv", CFG)))

FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,
          LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,
          NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,
          VA=51,WA=53,WV=54,WI=55,WY=56)
fips2ab <- setNames(names(FIPS), FIPS)

cn2pid <- fread(file.path(FIA,"cn2pid.csv"), colClasses="character")[, .(CN, pid, STATECD)]
setkey(cn2pid, CN)
# TreeMap area per pid (sum across CNs mapping to a pid)
area <- fread(file.path(FVS,"plt_area_treemap.csv"), select=c("PLT_CN","area_ha"))
area[, PLT_CN := as.character(PLT_CN)]
area <- merge(area, cn2pid[, .(CN, pid)], by.x="PLT_CN", by.y="CN")
area <- area[, .(area_ha = sum(area_ha)), by=pid]

fs <- list.files(DIR, pattern="^conus_.*\\.csv$", full.names=TRUE)
d  <- rbindlist(lapply(fs, function(f) tryCatch(
        fread(f, select=c("STAND_CN","YEAR","CONFIG","AGB_TONS_AC"), colClasses=list(character="STAND_CN")),
        error=function(e) NULL)), fill=TRUE)
d <- d[CONFIG==CFG & !is.na(AGB_TONS_AC)]
d[, perha := AGB_TONS_AC * 2.2417 * 0.5]
d <- merge(d, cn2pid[, .(CN, pid, STATECD)], by.x="STAND_CN", by.y="CN")   # FVS plot -> pid+state
d <- merge(d, area, by="pid")                                             # -> TreeMap area weight
d[, ST := fips2ab[as.integer(STATECD)]]
# area-weighted mean per-ha by state x year
ph <- d[, .(perha = sum(perha*area_ha)/sum(area_ha), n=uniqueN(pid)), by=.(ST, YEAR)][order(ST,YEAR)]
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, fia=agc_TgC_design, cv=cv_pct)]
tgt <- c(2025,2050,2075,2100)
out <- rbindlist(lapply(intersect(unique(ph$ST), names(FIPS)), function(st){
  s <- ph[ST==st]; if (nrow(s) < 2) return(NULL)
  tr <- approx(s$YEAR, s$perha, tgt, rule=2)$y
  a <- anc[state==st]; if (!nrow(a) || tr[1]<=0) return(NULL)
  data.table(model=MODEL_TAG, dom=sprintf("%02d",FIPS[st]), scenario="reserve", year=tgt,
             agc_TgC_anchored=round(a$fia*tr/tr[1],3), agc_TgC_anchored_se=round(a$fia*tr/tr[1]*a$cv/100,3),
             n_donor_plots=s$n[1])
}))
fwrite(out, OUT)
cat(sprintf("FVS TreeMap reserve [%s]: %d states -> %s\n", CFG, uniqueN(out$dom), OUT))
cat(sprintf("median donor plots/state: %d\n", as.integer(median(out$n_donor_plots, na.rm=TRUE))))
