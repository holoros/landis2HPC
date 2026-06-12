#!/usr/bin/env Rscript
# treemap_allocate.R
#
# Generalized TreeMap-allocation step for ANY model with a per-plot reserve
# (columns PLT_CN, year, agc_MgC_ha). Area-weights each plot by its TreeMap
# imputed area and aggregates to the state, then anchors year-0 to the FIA design
# total - the same common anchor every model uses. This is the FIADB-vs-TreeMap
# 2nd-dataset axis applied uniformly (FIADB = the unweighted state-mean builders;
# TreeMap = this area-weighted version).
#
# Inputs joined via the physical plot id (pid), since model CNs and TreeMap CNs
# differ by inventory cycle:
#   - cn2pid.csv         CN -> pid (, STATECD)
#   - plt_area_treemap   PLT_CN -> area_ha (the full TreeMap 2016 donor set, ~65k plots)
#
# IMPORTANT CONSTRAINT: TreeMap allocation can only weight plots that ARE TreeMap
# donors. A model run on a different FIA plot set (e.g. a different inventory
# cycle) overlaps the donors only partially, so its TreeMap state aggregate rests
# on that overlap. Report n_plots per state; treat low-overlap states as a coarse
# sensitivity, not a full-population estimate. The clean way to a full TreeMap
# version is to run the model ON the TreeMap donor plots (as the yield curves do).
#
#   --reserve  per-plot reserve csv (PLT_CN, year, agc_MgC_ha)
#   --model    model tag for output rows ; --out  output csv
# module load gcc/12.3.0 R/4.4.0

suppressPackageStartupMessages(library(data.table))
ga <- function(f,d=NA){a<-commandArgs(TRUE);i<-match(f,a);if(is.na(i)||i==length(a))d else a[i+1]}
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"; FVS <- "/fs/scratch/PUOM0008/crsfaaron/fvs_stress"
RES <- ga("--reserve"); if (is.na(RES)) stop("--reserve required (PLT_CN,year,agc_MgC_ha)")
MODEL_TAG <- ga("--model","MODEL_TM"); OUT <- ga("--out","reserve_treemap_anchored.csv")
FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,
          LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,
          NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,
          VA=51,WA=53,WV=54,WI=55,WY=56)
fips2ab <- setNames(names(FIPS), FIPS)

cn2pid <- fread(file.path(FIA,"cn2pid.csv"), colClasses="character")[, .(CN, pid, STATECD)]
area <- fread(file.path(FVS,"plt_area_treemap.csv"), select=c("PLT_CN","area_ha"))[, PLT_CN:=as.character(PLT_CN)]
area <- merge(area, cn2pid[, .(CN, pid)], by.x="PLT_CN", by.y="CN")[, .(area_ha=sum(area_ha)), by=pid]

d <- fread(RES, colClasses=list(character="PLT_CN"))
setnames(d, grep("agc", names(d), value=TRUE)[1], "perha")
d <- merge(d, cn2pid[, .(CN, pid, STATECD)], by.x="PLT_CN", by.y="CN")
d <- merge(d, area, by="pid")
d[, ST := fips2ab[as.integer(STATECD)]]
ph <- d[, .(perha=sum(perha*area_ha)/sum(area_ha), n=uniqueN(pid)), by=.(ST, year)][order(ST, year)]
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, fia=agc_TgC_design, cv=cv_pct)]
out <- rbindlist(lapply(intersect(unique(ph$ST), names(FIPS)), function(st){
  s <- ph[ST==st][order(year)]; if (nrow(s) < 2) return(NULL)
  y0 <- s$perha[1]; if (y0<=0) return(NULL); a <- anc[state==st]; if(!nrow(a)) return(NULL)
  data.table(model=MODEL_TAG, dom=sprintf("%02d",FIPS[st]), scenario="reserve",
             year=s$year, agc_TgC_anchored=round(a$fia*s$perha/y0,3),
             agc_TgC_anchored_se=round(a$fia*s$perha/y0*a$cv/100,3), n_donor_plots=s$n[1])
}))
fwrite(out, OUT)
cat(sprintf("%s TreeMap-allocated: %d states -> %s ; median donor plots/state=%d\n",
            MODEL_TAG, uniqueN(out$dom), OUT, as.integer(median(out$n_donor_plots,na.rm=TRUE))))
print(out[year==max(year), .(dom, agc_2100=agc_TgC_anchored, n_donor_plots)][order(dom)][1:8])
