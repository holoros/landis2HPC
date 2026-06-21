#!/usr/bin/env Rscript
# stress_test_harmonized.R
# Pre-finalization stress test of every harmonized member reserve and the
# integration staging. Checks coverage, value sanity, cross-model spread, units,
# and whether the integration scripts point at the CORRECTED inputs.
suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
flag <- function(...) cat(sprintf("  [FLAG] %s\n", sprintf(...)))
ok   <- function(...) cat(sprintf("  [ok]   %s\n", sprintf(...)))
hd   <- function(s) cat(sprintf("\n=== %s ===\n", s))

# files the integration ACTUALLY reads
ci_files  <- c(LANDIS="harmonized_landis_reserve_9state.csv", FVS_cal="fvs_reserve_calibrated_anchored.csv",
               FVS_def="fvs_reserve_default_anchored.csv", YieldCurve="yc_reserve_anchored.csv",
               CEM="cem_reserve_anchored.csv", CBM="cbm_reserve_anchored.csv")
ens_files <- c(FVS="fvs_reserve_calibrated_disturbed.csv", LANDIS="harmonized_landis_reserve_9state_disturbed.csv",
               CEM="cem_reserve_disturbed.csv", YieldCurve="yc_reserve_disturbed.csv", CBM="cbm_reserve_disturbed.csv")
corrected <- c(FVS_cal_wo1="fvs_reserve_calibrated_wo1_anchored.csv", FVS_def_wo1="fvs_reserve_default_wo1_anchored.csv",
               FVS_arm3="fvs_reserve_arm3_speciesdep_anchored.csv", CEM47="cem_reserve_anchored_47.csv")

load1 <- function(f){ p<-file.path(FIA,f); if(!file.exists(p)||file.info(p)$size<50) return(NULL)
  d<-tryCatch(fread(p),error=function(e)NULL); if(is.null(d))return(NULL)
  vc<-grep("agc_TgC",names(d),value=TRUE)[1]; if(is.na(vc))return(NULL)
  d[, val:=get(vc)]; if("scenario"%in%names(d)) d<-d[scenario=="reserve"]
  d[, dom:=sprintf("%02d",as.integer(dom))]; d }

hd("1. member file presence (CI inputs)")
for(m in names(ci_files)){ d<-load1(ci_files[m]); if(is.null(d)) flag("%s MISSING/empty: %s",m,ci_files[m]) else ok("%s: %d states, years %d-%d",m,uniqueN(d$dom),min(d$year),max(d$year)) }
hd("2. member file presence (ensemble disturbed inputs)")
for(m in names(ens_files)){ d<-load1(ens_files[m]); if(is.null(d)) flag("%s MISSING/empty: %s",m,ens_files[m]) else ok("%s: %d states",m,uniqueN(d$dom)) }

hd("3. value sanity (negatives, zeros, NA, extremes)")
for(f in c(ci_files,ens_files,corrected)){ d<-load1(f); if(is.null(d)) next
  nneg<-sum(d$val<0,na.rm=TRUE); nna<-sum(is.na(d$val)); nzero<-sum(d$val==0,na.rm=TRUE); mx<-max(d$val,na.rm=TRUE)
  if(nneg>0) flag("%s: %d NEGATIVE carbon rows",f,nneg)
  if(nna>0)  flag("%s: %d NA carbon rows",f,nna)
  if(mx>5000) flag("%s: max state value %.0f TgC (check units/outlier)",f,mx)
  if(nneg==0&&nna==0&&mx<=5000) ok("%s: clean (max %.0f TgC)",f,mx) }

hd("4. CORRECTED vs CANONICAL staging gap (the key check)")
chk<-function(canon,corr,lab){ a<-load1(canon); b<-load1(corr); if(is.null(a)||is.null(b)){flag("cannot compare %s",lab);return()}
  av<-a[year==2100,sum(val)]; bv<-b[year==2100,sum(val)]
  if(abs(av-bv)/bv>0.01) flag("%s: integration reads %.0f TgC but CORRECTED is %.0f (%.1f%% gap) -> REPOINT NEEDED",lab,av,bv,100*(bv-av)/av)
  else ok("%s: canonical matches corrected",lab) }
chk("fvs_reserve_calibrated_anchored.csv","fvs_reserve_calibrated_wo1_anchored.csv","FVS calibrated")
chk("fvs_reserve_default_anchored.csv","fvs_reserve_default_wo1_anchored.csv","FVS default")
ce<-load1("cem_reserve_anchored.csv"); c47<-load1("cem_reserve_anchored_47.csv")
if(!is.null(ce)&&!is.null(c47)){ if(uniqueN(c47$dom)>uniqueN(ce$dom)) flag("CEM: integration reads %d states, rebuild has %d -> PROMOTE",uniqueN(ce$dom),uniqueN(c47$dom)) else ok("CEM coverage current") }

hd("5. FVS family (arms) wired into integration?")
flag("build_crossmodel_ci.R / build_ensemble_estimate.R reference only FVS default+calibrated; arms 3-4 NOT folded in (FVS-family-with-bounds expansion pending)")

hd("6. cross-model 2100 spread (overlap states, sanity)")
ms<-lapply(names(ci_files), function(m){d<-load1(ci_files[m]); if(is.null(d))return(NULL); d[year==max(year),.(model=m,dom,val)]})
ms<-rbindlist(ms); if(nrow(ms)){ ov<-ms[,.N,by=dom][N>=4]$dom
  sp<-ms[dom%in%ov,.(lo=min(val),hi=max(val),ratio=round(max(val)/pmax(min(val),0.01),1)),by=dom]
  ok("overlap states (>=4 models): %d; median hi/lo ratio %.1f, max %.1f",length(ov),median(sp$ratio),max(sp$ratio))
  big<-sp[ratio>5]; if(nrow(big)) flag("%d states with >5x cross-model spread (structural divergence): %s",nrow(big),paste(big$dom,collapse=",")) }
cat("\n=== stress test done ===\n")
