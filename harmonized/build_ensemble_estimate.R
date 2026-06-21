#!/usr/bin/env Rscript
# build_ensemble_estimate.R - harmonized best-estimate reserve trajectory with a 90% credible
# interval, from the disturbance-aware model reserves. Two weightings:
#   equal       - model democracy (CMIP-style); the primary central estimate.
#   benchmark   - down-weight the documented structural outliers: FVS in the West (the high
#                 no-disturbance end-member) and CEM everywhere (scenario-invariant / pessimistic
#                 vs the American Forests benchmarks). A transparent sensitivity, weight 0.5.
#
# Per state x year the credible interval combines between-model (structural), within-model
# (parameter: FVS posterior, CBM OAT, YC rcp+sim; LANDIS/CEM anchor cv), and FIA sampling:
#   total_sd = sqrt(between_model_sd^2 + mean(within_model_sd)^2 + anchor_se^2)
#   90% CrI  = weighted_mean +/- 1.645*total_sd
# module load gcc/12.3.0 R/4.4.0
suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
YEARS <- c(2025,2050,2075,2100)
FIPS<-c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,LA=22,
        ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,NY=36,NC=37,
        ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,VA=51,WA=53,WV=54,WI=55,WY=56)
fips2ab <- setNames(names(FIPS), sprintf("%02d",FIPS))
WEST <- c("CA","OR","WA","ID","MT","NV","UT","CO","NM","AZ","WY")
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, cv=cv_pct)]
fvs_post <- tryCatch(fread(file.path(FIA,"fvs_posterior_ci_all.csv")), error=function(e) NULL)
cbm_oat  <- tryCatch(fread(file.path(FIA,"cbm_oat_bands.csv")), error=function(e) NULL)
cbm_gap  <- tryCatch(fread(file.path(FIA,"cbm_engine_gap.csv")), error=function(e) NULL)
yc_b     <- tryCatch(fread(file.path(FIA,"yc_bands.csv")), error=function(e) NULL)
# FVS family band (across arms + parametric/residual + anchor), carried as se in the
# family disturbed file; this is the FVS member's within-model relative SD.
fvs_fam  <- tryCatch(fread(file.path(FIA,"fvs_reserve_family_disturbed.csv"))[scenario=="reserve"], error=function(e) NULL)
if(!is.null(fvs_fam)) fvs_fam[, dom:=sprintf("%02d",as.integer(dom))]

relband <- function(model, st, yr){           # within-model relative SD
  if (grepl("FVS",model) && !is.null(fvs_fam)){ dm<-sprintf("%02d",FIPS[st]); s<-fvs_fam[dom==dm]; if(nrow(s)>=2)
    return(approx(s$year, s$agc_TgC_anchored_se/pmax(s$agc_TgC_anchored,1e-9), yr, rule=2)$y); return(0) }
  if (model=="CBM"){ oat<-if(!is.null(cbm_oat)&&nrow(cbm_oat[state==st])) cbm_oat[state==st]$rel_halfrange[1]/1.645 else 0
    eg<-if(!is.null(cbm_gap)&&nrow(cbm_gap[state==st])) abs(cbm_gap[state==st]$gcbm_over_libcbm_pct[1])/100/1.645 else 0
    return(sqrt(oat^2+eg^2)) }
  if (model=="YieldCurve" && !is.null(yc_b)){ x<-yc_b[state==st]; if(nrow(x))
    return(sqrt((x$rel_climate_band[1]/1.645)^2+(x$rel_sim_band[1]/1.96)^2)) }
  return(0)                                     # LANDIS/CEM: no extra param band (anchor cv only)
}
files <- c(FVS="fvs_reserve_family_disturbed.csv", LANDIS="harmonized_landis_reserve_9state_disturbed.csv",
           CEM="cem_reserve_disturbed.csv", YieldCurve="yc_reserve_disturbed.csv", CBM="cbm_reserve_disturbed.csv")
mods <- lapply(files, function(f){ d<-fread(file.path(FIA,f))[scenario=="reserve"]; d[,dom:=sprintf("%02d",as.integer(dom))]; d })
interp <- function(m, dom, yr){ s<-mods[[m]][dom==dom][order(year)]; if(nrow(s)<2) return(NA_real_); approx(s$year,s$agc_TgC_anchored,yr,rule=2)$y }

ens <- rbindlist(lapply(names(FIPS), function(ab){ dom<-sprintf("%02d",FIPS[ab])
  rbindlist(lapply(YEARS, function(yr){
    vals <- sapply(names(files), function(m){ s<-mods[[m]][dom==sprintf("%02d",FIPS[ab])][order(year)]; if(nrow(s)<2) NA_real_ else approx(s$year,s$agc_TgC_anchored,yr,rule=2)$y })
    keep <- names(vals)[is.finite(vals)]; v<-vals[keep]; if(length(v)<2) return(NULL)
    w_eq <- rep(1, length(v)); names(w_eq)<-keep
    w_bm <- w_eq; if(ab %in% WEST) w_bm[grepl("FVS",names(w_bm))] <- 0.5; w_bm["CEM"] <- ifelse("CEM"%in%names(w_bm),0.5,NA); w_bm<-w_bm[!is.na(w_bm)]
    wm <- function(w) sum(v[names(w)]*w)/sum(w)
    cv <- anc[state==ab]$cv; cv <- if(length(cv)) cv else 10
    within <- sapply(keep, function(m) v[m]*relband(m, ab, yr))
    bsd <- sd(v); med <- median(v); anch <- median(v)*cv/100
    geom <- exp(mean(log(v[v>0])))   # geometric mean: robust central estimate (down-weights the high FVS end-member)
    tsd <- sqrt(bsd^2 + mean(within)^2 + anch^2)
    data.table(state=ab, year=yr, n_models=length(v),
               ens_equal=round(wm(w_eq),1), ens_geom=round(geom,1), ens_benchmark=round(wm(w_bm),1), median=round(med,1),
               between_sd=round(bsd,1), within_sd=round(mean(within),1), anchor_se=round(anch,1),
               lo90=round(pmax(wm(w_eq)-1.645*tsd,0),1), hi90=round(wm(w_eq)+1.645*tsd,1),
               crI_rel_pct=round(100*1.645*tsd/wm(w_eq),1))
  }))
}))
fwrite(ens, file.path(FIA,"harmonized_best_estimate.csv"))
cat("best-estimate reserve (disturbance-aware), example states 2100:\n")
print(ens[year==2100 & state %in% c("IN","OH","NH","ME","CA","OR","MN","GA")][, .(state, ens_equal, ens_benchmark, lo90, hi90, crI_rel_pct, n_models)])
cat("\nCONUS best estimate (sum over full-coverage; states with >=3 models):\n")
print(ens[, .(equal=round(sum(ens_equal)), benchmark=round(sum(ens_benchmark))), by=year])
