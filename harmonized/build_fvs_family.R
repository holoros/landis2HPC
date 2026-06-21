#!/usr/bin/env Rscript
# build_fvs_family.R
# Collapse the FVS lineage into ONE ensemble member, structured by its two
# distinct sub-approaches (same lineage, different methods):
#   fvs-modern : default Wykoff engine + calibrated (Bayesian-recalibrated params)
#   fvs-conus  : species-dependent + species-free (new unified Bayesian equations)
# FVS is one tree-level approach, distinct from CEM / yield curves / LANDIS / CBM,
# so it is one ensemble vote. The lineage central is BALANCED across the two
# sub-approaches (so it is not skewed by how many arms each happens to have), and
# the engine-vs-equation gap is the dominant structural band term.
#
# Per state x year:
#   modern_c   = mean(default, calibrated points)         (sub-approach central)
#   conus_c    = mean(species-dep, species-free points)
#   central    = mean(present sub-approach centrals)       (balanced lineage central)
#   between_sd = sd(present sub-approach centrals)         (engine vs equation, structural)
#   within_sd  = sqrt( mean(within-sub-approach arm var) + mean(arm param/residual var) )
#   anchor_se  = central * FIA design cv
#   family_se  = sqrt(between_sd^2 + within_sd^2 + anchor_se^2)
# Uses whatever arms are present (3 now; 4 when species-free lands).
set.seed(42)
suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, cv=cv_pct)]
FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,VA=51,WA=53,WV=54,WI=55,WY=56)
dom2ab <- setNames(names(FIPS), sprintf("%02d",FIPS))

norm_pt <- function(f, arm, subfam){ p<-file.path(FIA,f); if(!file.exists(p)||file.info(p)$size<50) return(NULL)
  d<-fread(p); if("scenario"%in%names(d)) d<-d[scenario=="reserve"]
  d[, dom:=sprintf("%02d",as.integer(dom))]
  if("agc_TgC_point"%in%names(d)){ pc <- if("pred_cv"%in%names(d)) d$pred_cv else 0
    d <- d[, .(dom, year, point=agc_TgC_point, param_sd=agc_TgC_point*pc)]
  } else { d <- d[, .(dom, year, point=agc_TgC_anchored, param_sd=0)] }
  d[, `:=`(arm=arm, subfam=subfam)]; d }

defs <- list(
  c("fvs_reserve_default_wo1_anchored.csv",    "default",     "fvs-modern"),
  c("fvs_reserve_calibrated_wo1_anchored.csv", "calibrated",  "fvs-modern"),
  c("fvs_reserve_arm3_speciesdep_anchored.csv","speciesdep",  "fvs-conus"),
  c("fvs_reserve_arm4_speciesfree_anchored.csv","speciesfree","fvs-conus"))
all <- rbindlist(Filter(Negate(is.null), lapply(defs, function(x) norm_pt(x[1],x[2],x[3]))), use.names=TRUE)
cat("arms present:", paste(sort(unique(all$arm)),collapse=", "),
    "| sub-approaches:", paste(sort(unique(all$subfam)),collapse=", "), "\n")

# sub-approach central + within-sub-approach variance, per dom/year/subfam
sub <- all[, .(sub_c=mean(point), sub_var=if(.N>1) var(point) else 0,
               param_var=mean(param_sd^2), n_arm=.N), by=.(dom, year, subfam)]
# lineage aggregation per dom/year (balanced across sub-approaches)
fam <- sub[, {
    central <- mean(sub_c)
    between <- if(.N>1) sd(sub_c) else 0          # engine vs equation structural gap
    within  <- sqrt(mean(sub_var) + mean(param_var))
    ab <- dom2ab[dom[1]]; cv <- anc[state==ab]$cv; cv <- if(length(cv)) cv else 10
    ase <- central*cv/100
    .(agc_TgC_anchored=round(central,3),
      agc_TgC_anchored_se=round(sqrt(between^2 + within^2 + ase^2),3),
      n_subapproach=.N, between_approach_sd=round(between,3))
  }, by=.(dom, year)]
fam[, `:=`(model="FVS", scenario="reserve")]
setcolorder(fam, c("model","dom","scenario","year","agc_TgC_anchored","agc_TgC_anchored_se","n_subapproach","between_approach_sd"))
fwrite(fam, file.path(FIA,"fvs_reserve_family_anchored.csv"))
cat("FVS family written:", uniqueN(fam$dom), "states\n")
# transparency: sub-approach CONUS centrals
print(sub[, .(CONUS=round(sum(sub_c))), by=.(subfam, year)][order(year, subfam)][year %in% c(2025,2100)])
cat("CONUS FVS lineage reserve (Tg C), balanced central with family band:\n")
print(fam[, .(central=round(sum(agc_TgC_anchored)), se=round(sqrt(sum(agc_TgC_anchored_se^2)))), by=year][order(year)])
