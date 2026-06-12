#!/usr/bin/env Rscript
# apply_harvest_scenarios.R
#
# Deterministic expected-value harvest scenarios on the anchored reserve LANDIS
# trajectory, with (a) internally consistent timber NPV from each scenario's
# removals and (b) a harvested-wood-products (HWP) carbon pool so total carbon =
# standing forest + HWP.
#
#   dB/dt      = g_reserve(t) - h*f*B          (h = HCS rate * multiplier, f = removal frac)
#   removal(t) = h*f*B(t)  Tg C/yr  (live AGC carbon removed from the forest)
#
# HWP (first-order, IPCC Tier-2 style): of removed carbon, HWP_FRAC enters products
# (rest is slash/mill loss, emitted); products split long-lived (sawnwood+panels,
# half-life HL_LONG) and short-lived (paper, HL_SHORT); a fraction LF_FRAC of
# decayed long-lived carbon enters a landfill pool (HL_LF), the rest is emitted.
#   pool(t+1) = pool(t)*(1-k) + input(t),  k = ln2/half-life
#   total_carbon(t) = forest_AGC(t) + HWP_in_use + HWP_landfill
#
# Timber NPV from removals: revenue = removal/CFRAC*MERCH*VOL_M3_PER_MG*STUMPAGE.
# Defaults are documented and sensitivity-checkable.
#
# Output: harmonized_landis_4scenario.csv (trajectory: forest, hwp, total) and
#         harmonized_carbon_npv_4state.csv (2100 summary + NPV).
# module load gcc/12.3.0; module load R/4.4.0

suppressPackageStartupMessages(library(data.table))
ga <- function(f,d=NA){a<-commandArgs(TRUE);i<-match(f,a);if(is.na(i)||i==length(a))d else a[i+1]}
reserve_csv <- ga("--reserve","/fs/scratch/PUOM0008/crsfaaron/FIA/harmonized_landis_8state.csv")
hcs_csv     <- ga("--hcs","/users/PUOM0008/crsfaaron/cbm_states/cross_state/libcbm/tools_conus/14_outputs/uncertainty/hcs_harvest_rate_by_state.csv")
out_traj    <- ga("--out","/fs/scratch/PUOM0008/crsfaaron/FIA/harmonized_landis_4scenario.csv")
out_sum     <- ga("--summary","/fs/scratch/PUOM0008/crsfaaron/FIA/harmonized_carbon_npv_4state.csv")
F_CLEARCUT<-0.85; F_PARTIAL<-0.45
CFRAC<-0.5; MERCH<-0.6; VOL_M3_PER_MG<-1.9; STUMPAGE<-14
HWP_FRAC<-0.5; LL_FRAC<-0.65; HL_LONG<-35; HL_SHORT<-4; HL_LF<-100; LF_FRAC<-0.20
kL<-log(2)/HL_LONG; kS<-log(2)/HL_SHORT; kF<-log(2)/HL_LF

FIPS<-c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,VA=51,WA=53,WV=54,WI=55,WY=56)
fips2abbr<-setNames(names(FIPS),sprintf("%02d",FIPS))

res<-fread(reserve_csv)
res<-res[scenario=="reserve",.(dom=sprintf("%02d",as.integer(dom)),year,B0=agc_TgC_anchored,
          se0=if("agc_TgC_anchored_se" %in% names(res)) agc_TgC_anchored_se else NA_real_)]
hcs<-fread(hcs_csv)[,.(abbr=state,rate=harvest_rate_pct_yr/100,cc=clearcut_frac,forest_ha)]
mult<-c(reserve=0,BAU=1,conservation=0.6,intensive=2)

traj<-list(); summ<-list()
for (sd0 in split(res,res$dom)) {
  sd<-sd0[order(year)]; ab<-fips2abbr[sd$dom[1]]; h0<-hcs[abbr==ab]; if(!nrow(h0))next
  yrs<-sd$year; ann<-seq(min(yrs),max(yrs)); B0a<-approx(yrs,sd$B0,ann)$y
  cv<-if(all(is.na(sd$se0)))NA else mean(sd$se0/sd$B0,na.rm=TRUE)
  for (scn in names(mult)) {
    m<-mult[scn]
    f<-switch(scn,reserve=0,BAU=h0$cc*F_CLEARCUT+(1-h0$cc)*F_PARTIAL,conservation=F_PARTIAL,intensive=F_CLEARCUT)
    h<-h0$rate*m
    B<-numeric(length(ann)); B[1]<-B0a[1]
    LLp<-SLp<-LFp<-numeric(length(ann))           # HWP pools (Tg C)
    npv03<-npv05<-0
    for (i in 2:length(ann)) {
      g<-B0a[i]-B0a[i-1]; rem<-h*f*B[i-1]
      B[i]<-max(B[i-1]+g-rem,0)
      prod<-rem*HWP_FRAC                            # carbon entering products
      inL<-prod*LL_FRAC; inS<-prod*(1-LL_FRAC)
      outL<-LLp[i-1]*kL                             # long-lived leaving in-use
      LLp[i]<-LLp[i-1]+inL-outL
      SLp[i]<-SLp[i-1]+inS-SLp[i-1]*kS
      LFp[i]<-LFp[i-1]+outL*LF_FRAC-LFp[i-1]*kF     # landfill gains share of out-of-use
      rev<-rem/CFRAC*MERCH*VOL_M3_PER_MG*1e6*STUMPAGE
      t<-ann[i]-min(ann); npv03<-npv03+rev/1.03^t; npv05<-npv05+rev/1.05^t
    }
    hwp<-LLp+SLp+LFp; tot<-B+hwp
    dt<-data.table(model="LANDIS",dom=sd$dom[1],scenario=scn,year=ann,
                   forest_TgC=round(B,3),hwp_TgC=round(hwp,3),total_TgC=round(tot,3))
    dt[,forest_TgC_se:=if(is.na(cv))NA_real_ else round(forest_TgC*cv,3)]
    traj[[length(traj)+1]]<-dt[year %in% yrs]
    n<-length(ann)
    summ[[length(summ)+1]]<-data.table(state=ab,scenario=scn,
        forest_2100_TgC=round(B[n],1), hwp_2100_TgC=round(hwp[n],1), total_2100_TgC=round(tot[n],1),
        npv_timber_perha_0.03=round(npv03/h0$forest_ha), npv_timber_perha_0.05=round(npv05/h0$forest_ha))
  }
}
fwrite(rbindlist(traj),out_traj)
S<-rbindlist(summ); setorder(S,state,-total_2100_TgC)
fwrite(S,out_sum); print(S)
