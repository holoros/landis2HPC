#!/usr/bin/env Rscript
# build_fvs_family.R
# Collapse the FVS arms into ONE ensemble member with structural bounds. FVS is a
# single tree-level statistical approach; the arms (default Wykoff, calibrated,
# fvs-conus species-dependent, fvs-conus species-free) are different ways to run
# it, so they define the FVS structural band, not separate ensemble votes.
#
# Per state x year:
#   central        = mean across available arm point estimates
#   between_arm_sd = sd across arm points (structural, engine vs equation)
#   within_sd      = mean of each arm's own parametric+residual SD (0 for the
#                    engine default/calibrated points; pred band for arms 3-4)
#   anchor_se      = central * FIA design cv
#   family_se      = sqrt(between_arm_sd^2 + within_sd^2 + anchor_se^2)
# Output fvs_reserve_family_anchored.csv (model,dom,scenario,year,agc_TgC_anchored,
#   agc_TgC_anchored_se, n_arms, between_arm_sd) in the canonical integration schema.
# Uses whatever arms are present (3 now, 4 when species-free lands).
set.seed(42)
suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
anc <- fread(file.path(FIA,"fia_agc_anchor_design_by_state.csv"))[, .(state, cv=cv_pct)]
FIPS <- c(AL=1,AZ=4,AR=5,CA=6,CO=8,CT=9,DE=10,FL=12,GA=13,ID=16,IL=17,IN=18,IA=19,KS=20,KY=21,LA=22,ME=23,MD=24,MA=25,MI=26,MN=27,MS=28,MO=29,MT=30,NE=31,NV=32,NH=33,NJ=34,NM=35,NY=36,NC=37,ND=38,OH=39,OK=40,OR=41,PA=42,RI=44,SC=45,SD=46,TN=47,TX=48,UT=49,VT=50,VA=51,WA=53,WV=54,WI=55,WY=56)
dom2ab <- setNames(names(FIPS), sprintf("%02d",FIPS))

# normalize an arm file to (dom, year, point, param_sd)
norm_pt <- function(f){ p<-file.path(FIA,f); if(!file.exists(p)||file.info(p)$size<50) return(NULL)
  d<-fread(p); if("scenario"%in%names(d)) d<-d[scenario=="reserve"]
  d[, dom:=sprintf("%02d",as.integer(dom))]
  if("agc_TgC_point"%in%names(d)){      # arm3/arm4: point + predictive band
    pc <- if("pred_cv"%in%names(d)) d$pred_cv else 0
    d[, .(dom, year, point=agc_TgC_point, param_sd=agc_TgC_point*pc)]
  } else {                               # default/calibrated: engine point, no extra band
    d[, .(dom, year, point=agc_TgC_anchored, param_sd=0)]
  }
}
arms <- list(
  default     = norm_pt("fvs_reserve_default_wo1_anchored.csv"),
  calibrated  = norm_pt("fvs_reserve_calibrated_wo1_anchored.csv"),
  speciesdep  = norm_pt("fvs_reserve_arm3_speciesdep_anchored.csv"),
  speciesfree = norm_pt("fvs_reserve_arm4_speciesfree_anchored.csv"))
present <- names(arms)[!sapply(arms, is.null)]
cat("FVS arms present:", paste(present, collapse=", "), "(", length(present), ")\n")
all <- rbindlist(lapply(present, function(a) arms[[a]][, arm:=a]), use.names=TRUE)

fam <- all[, {
    central <- mean(point)
    bsd     <- if(.N>1) sd(point) else 0
    wsd     <- mean(param_sd)
    ab      <- dom2ab[dom[1]]; cv <- anc[state==ab]$cv; cv <- if(length(cv)) cv else 10
    ase     <- central*cv/100
    .(agc_TgC_anchored=round(central,3),
      agc_TgC_anchored_se=round(sqrt(bsd^2 + wsd^2 + ase^2),3),
      n_arms=.N, between_arm_sd=round(bsd,3))
  }, by=.(dom, year)]
fam[, `:=`(model="FVS", scenario="reserve")]
setcolorder(fam, c("model","dom","scenario","year","agc_TgC_anchored","agc_TgC_anchored_se","n_arms","between_arm_sd"))
fwrite(fam, file.path(FIA,"fvs_reserve_family_anchored.csv"))
cat("FVS family written:", uniqueN(fam$dom), "states,", length(present), "arms\n")
cat("CONUS FVS family reserve (Tg C), central with family band:\n")
print(fam[, .(central=round(sum(agc_TgC_anchored)),
              se=round(sqrt(sum(agc_TgC_anchored_se^2)))), by=year][order(year)])
