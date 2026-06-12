#!/usr/bin/env Rscript
# build_master_scenarios.R - finalize ALL projections and scenarios across CONUS.
# Consolidates every model x scenario x state into one master table, builds the
# multi-model ensemble best estimate for EACH of the four harvest scenarios (reserve,
# conservation, BAU, intensive), and rolls up to CONUS per scenario.
#
# Inputs: harmonized_carbon_npv_<MODEL>.csv (state, scenario, forest_2100_TgC,
#         hwp_2100_TgC, total_2100_TgC, npv_*). Models: FVScalibrated, YC, CBM, CEM,
#         LANDIS (9state). FVSdefault kept in the master as a sensitivity, excluded
#         from the ensemble to avoid double-counting FVS.
# Outputs: harmonized_master_all_scenarios.csv, harmonized_ensemble_by_scenario.csv,
#          harmonized_conus_by_scenario.csv
# module load gcc/12.3.0 R/4.4.0
suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
# both disturbance modes x all models
srcND <- c(FVS_cal="FVScalibrated", FVS_def="FVSdefault", YieldCurve="YC", CBM="CBM", CEM="CEM", LANDIS="9state")
readset <- function(mode){
  suf <- if(mode=="disturbed") "_dist" else ""
  rbindlist(lapply(names(srcND), function(m){
    f <- file.path(FIA, sprintf("harmonized_carbon_npv_%s%s.csv", srcND[m], suf)); if(!file.exists(f)) return(NULL)
    d <- fread(f); d[, `:=`(model=m, dist_mode=mode)]
    d[, .(model, dist_mode, state, scenario, forest_2100_TgC, hwp_2100_TgC, total_2100_TgC,
          npv_0.03=npv_timber_perha_0.03, npv_0.05=npv_timber_perha_0.05)]
  }))
}
master <- rbind(readset("nodisturb"), readset("disturbed"))
setcolorder(master, c("model","dist_mode","state","scenario","total_2100_TgC","forest_2100_TgC","hwp_2100_TgC","npv_0.03","npv_0.05"))
fwrite(master[order(state,scenario,model)], file.path(FIA,"harmonized_master_all_scenarios.csv"))

# ensemble across the 5 structural models (exclude FVS_def) per state x scenario
ENS <- c("FVS_cal","YieldCurve","CBM","CEM","LANDIS")
WEST <- c("CA","OR","WA","ID","MT","NV","UT","CO","NM","AZ","WY")
em <- master[model %in% ENS]
ens <- em[, {
  v <- total_2100_TgC; names(v) <- model
  w_eq <- rep(1, .N); names(w_eq) <- model
  w_bm <- w_eq
  if (state[1] %in% WEST) w_bm[grepl("FVS",names(w_bm))] <- 0.5
  if ("CEM" %in% names(w_bm)) w_bm["CEM"] <- 0.5
  bsd <- if(.N>1) sd(v) else 0
  .(n_models=.N, ens_equal=round(sum(v*w_eq)/sum(w_eq),1),
    ens_benchmark=round(sum(v*w_bm)/sum(w_bm),1), median=round(median(v),1),
    min=round(min(v),1), max=round(max(v),1), between_sd=round(bsd,1),
    lo90=round(pmax(median(v)-1.645*bsd,0),1), hi90=round(median(v)+1.645*bsd,1))
}, by=.(state, dist_mode, scenario)]
fwrite(ens[order(state,factor(scenario,levels=c("reserve","conservation","BAU","intensive")))],
       file.path(FIA,"harmonized_ensemble_by_scenario.csv"))

# CONUS rollup per scenario: each model summed over the states it covers, + ensemble of full-coverage
full <- c("FVS_cal","YieldCurve","CBM")   # 48-state models -> comparable CONUS totals
conus <- master[model %in% full, .(CONUS_TgC=round(sum(total_2100_TgC))), by=.(model,dist_mode,scenario)]
conus_w <- dcast(conus, dist_mode+scenario~model, value.var="CONUS_TgC")
conus_w[, ensemble_median := round(apply(.SD,1,median)), .SDcols=full]
conus_w[, ens_lo := round(apply(.SD,1,min)), .SDcols=full][, ens_hi := round(apply(.SD,1,max)), .SDcols=full]
conus_w <- conus_w[order(dist_mode, factor(scenario,levels=c("reserve","conservation","BAU","intensive")))]
fwrite(conus_w, file.path(FIA,"harmonized_conus_by_scenario.csv"))

cat("MASTER:", nrow(master), "rows (",uniqueN(master$model),"models x", uniqueN(master$state),"states x 4 scenarios x 2 disturbance modes)\n\n")
cat("CONUS 2100 total carbon by scenario x disturbance mode (Tg C), full-coverage models + ensemble:\n")
print(conus_w)
cat("\nEnsemble best estimate, example states x scenario (Tg C, equal weight [90% CI]):\n")
print(ens[state %in% c("IN","OH","NH","CA","GA"), .(state, scenario, ens_equal, lo90, hi90, n_models)][order(state)])
