# =============================================================================
# Title: Full model x state x scenario inventory + stress matrix
# Author: A. Weiskittel
# Date: 2026-06-14
# Description: Steps back across the harmonized assessment. Produces (1) a per-model
#   inventory (coverage, horizon, band), (2) a model x state coverage matrix per
#   scenario, (3) cross-model divergence + distinguishability per state, and (4)
#   anomaly flags (negative carbon, non-monotonic harvest gradient, reserve HWP!=0).
# Dependencies: FIA/harmonized_master_all_scenarios.csv, the *_reserve_anchored.csv,
#   uncertainty band files.
# =============================================================================
suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
m <- fread(file.path(FIA, "harmonized_master_all_scenarios.csv"))
fips2ab <- function(x) x  # state already abbreviation in master
SCN <- c("reserve","conservation","BAU","intensive")
m[, scenario := factor(scenario, levels = SCN)]
models <- sort(unique(m$model))

# --- (1) per-model inventory --------------------------------------------------
inv <- m[dist_mode == "nodisturb", .(
  n_states   = uniqueN(state),
  scenarios  = uniqueN(scenario),
  med_2100   = round(median(total_2100_TgC[scenario=="reserve"], na.rm=TRUE),1),
  min_state  = round(min(total_2100_TgC[scenario=="reserve"], na.rm=TRUE),1),
  max_state  = round(max(total_2100_TgC[scenario=="reserve"], na.rm=TRUE),1)
), by = model][order(-n_states)]
fwrite(inv, file.path(FIA, "inv_model_summary.csv"))
cat("=== (1) MODEL INVENTORY (nodisturb reserve 2100) ===\n"); print(inv)

# --- (2) model x state coverage (reserve, nodisturb) -------------------------
cov <- dcast(m[dist_mode=="nodisturb" & scenario=="reserve"], state ~ model,
             value.var = "total_2100_TgC")
covmat <- cov[, lapply(.SD, function(x) ifelse(is.na(x), 0L, 1L)), .SDcols = models]
covmat[, state := cov$state]
covmat[, n_models := rowSums(.SD), .SDcols = models]
fwrite(covmat, file.path(FIA, "inv_coverage_matrix.csv"))
cat("\n=== (2) COVERAGE: states by number of models present ===\n")
print(covmat[, .N, by = n_models][order(-n_models)])
cat("Full 6-model overlap states:", paste(covmat[n_models==max(n_models)]$state, collapse=", "), "\n")

# --- (3) cross-model divergence per state (reserve, nodisturb) ----------------
div <- m[dist_mode=="nodisturb" & scenario=="reserve" & is.finite(total_2100_TgC),
  .(n=uniqueN(model), lo=round(min(total_2100_TgC),1), hi=round(max(total_2100_TgC),1),
    med=round(median(total_2100_TgC),1),
    cv_pct=round(100*sd(total_2100_TgC)/mean(total_2100_TgC),1),
    fold=round(max(total_2100_TgC)/pmax(min(total_2100_TgC),1e-6),2)), by=state][order(-cv_pct)]
fwrite(div, file.path(FIA, "inv_crossmodel_divergence.csv"))
cat("\n=== (3) CROSS-MODEL DIVERGENCE (reserve 2100), most-divergent states ===\n")
print(head(div[n>=3], 12))
cat(sprintf("\nMedian cross-model CV across states (n>=3 models): %.1f%%; median fold-range: %.2fx\n",
            median(div[n>=3]$cv_pct), median(div[n>=3]$fold)))

# --- (4) anomaly flags --------------------------------------------------------
flags <- list()
# negative or zero carbon
neg <- m[total_2100_TgC <= 0]; if (nrow(neg)) flags$negative <- neg[, .(model,dist_mode,state,scenario,total_2100_TgC)]
# harvest gradient monotonicity: reserve >= conservation >= BAU >= intensive within model/state/mode
w <- dcast(m, model+dist_mode+state ~ scenario, value.var="total_2100_TgC")
w[, mono_ok := (reserve>=conservation-1e-6 & conservation>=BAU-1e-6 & BAU>=intensive-1e-6)]
nonmono <- w[mono_ok==FALSE]
if (nrow(nonmono)) flags$nonmonotonic <- nonmono[, .(model,dist_mode,state,reserve,conservation,BAU,intensive)]
# reserve HWP should be 0
rh <- m[scenario=="reserve" & abs(hwp_2100_TgC) > 0.01]
if (nrow(rh)) flags$reserve_hwp <- rh[, .(model,dist_mode,state,hwp_2100_TgC)]
cat("\n=== (4) ANOMALY FLAGS ===\n")
cat("negative/zero carbon rows:", if(!is.null(flags$negative)) nrow(flags$negative) else 0, "\n")
cat("non-monotonic harvest gradient rows:", nrow(nonmono), "\n")
cat("reserve-with-nonzero-HWP rows:", if(!is.null(flags$reserve_hwp)) nrow(flags$reserve_hwp) else 0, "\n")
if (nrow(nonmono)) { cat("  non-monotonic by model:\n"); print(nonmono[, .N, by=model]) }
saveRDS(flags, file.path(FIA, "inv_anomaly_flags.rds"))

# --- scenario gradient by model (CONUS, nodisturb) ---------------------------
grad <- m[dist_mode=="nodisturb", .(Pg=round(sum(total_2100_TgC,na.rm=TRUE)/1000,1)), by=.(model,scenario)]
grad <- dcast(grad, model~scenario, value.var="Pg")
cat("\n=== SCENARIO GRADIENT by model (CONUS 2100 Pg C, nodisturb; note partial-coverage models) ===\n")
print(grad)
cat("\nWrote inv_model_summary / inv_coverage_matrix / inv_crossmodel_divergence / inv_anomaly_flags.\n")
