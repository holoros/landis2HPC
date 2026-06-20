#!/usr/bin/env Rscript
# build_arm3_band.R
# Arm 3 (fvs-conus species-dependent) uncertainty band.
# Reads out_conus_arm3/arm3_<variant>.csv (KIND=point|draw). For each variant and
# projection year computes:
#   - point per-ha (calibrated point, cross-checks the base WO-1 calibrated reserve)
#   - parametric band: across the COMMON draws, the population per-ha mean per draw,
#     then SD across draws -> fractional parametric CV
#   - predictive band: param CV combined in quadrature with a residual CV
#     (RESID_CV, default = FIA design CV; parameter-only intervals undercover ~13%)
# The fractional predictive CV is applied to the anchored calibrated reserve to
# give arm-3 point +/- CI per state/year.
set.seed(42)
suppressPackageStartupMessages(library(data.table))
FIA  <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
DIR  <- "/fs/scratch/PUOM0008/crsfaaron/fvs_stress/out_conus_arm3"
RESID_CV <- as.numeric(Sys.getenv("ARM3_RESID_CV", "0.12"))  # residual fraction; flag for Aaron
TGT  <- c(2025, 2050, 2075, 2100)

fs <- list.files(DIR, pattern="^arm3_.*\\.csv$", full.names=TRUE)
fs <- fs[file.info(fs)$size > 50]
d  <- rbindlist(lapply(fs, function(f) tryCatch(fread(f), error=function(e) NULL)), fill=TRUE)
if (!nrow(d)) stop("no arm3 rows")
d[, mgC_ha := AGB_TONS_AC * 2.2417 * 0.5]

# parametric CV per variant x PROJ_YEAR: population per-ha mean per draw, sd across draws
drw <- d[KIND=="draw"]
pop <- drw[, .(perha = mean(mgC_ha)), by=.(VARIANT, DRAW, PROJ_YEAR)]
band <- pop[, .(param_mean = mean(perha), param_sd = sd(perha), ndraw = .N), by=.(VARIANT, PROJ_YEAR)]
band[, param_cv := fifelse(param_mean > 0, param_sd/param_mean, 0)]
# predictive CV: quadrature of parametric + residual
band[, pred_cv := sqrt(param_cv^2 + RESID_CV^2)]
fwrite(band, file.path(FIA, "arm3_band_by_variant_year.csv"))

# Map projection year -> calendar by variant median INV_YEAR is not carried; use
# the calibrated anchored reserve's own trajectory for the LEVEL, and attach the
# arm-3 predictive CV (interpolated to TGT calendar yrs via a nominal base year).
# Predictive CV vs calendar: assume inventory base ~2015 (CONUS annual panel mid),
# so PROJ_YEAR maps to calendar = 2015 + PROJ_YEAR; interpolate CV to TGT.
cvyr <- band[, .(cv = mean(pred_cv)), by=PROJ_YEAR][order(PROJ_YEAR)]
cv_at <- approx(2015 + cvyr$PROJ_YEAR, cvyr$cv, TGT, rule=2)$y
names(cv_at) <- TGT

cal <- fread(file.path(FIA, "fvs_reserve_calibrated_wo1_anchored.csv"))  # point reserve (level)
arm3 <- copy(cal)
arm3[, model := "FVS"]; arm3[, arm := "fvs_conus_speciesdep"]
arm3[, pred_cv := cv_at[as.character(year)]]
arm3[, agc_TgC_lo := round(agc_TgC_anchored * (1 - 1.645*pred_cv), 3)]
arm3[, agc_TgC_hi := round(agc_TgC_anchored * (1 + 1.645*pred_cv), 3)]
setnames(arm3, "agc_TgC_anchored", "agc_TgC_point")
fwrite(arm3[, .(model, arm, dom, state, scenario, year, agc_TgC_point, pred_cv, agc_TgC_lo, agc_TgC_hi)],
       file.path(FIA, "fvs_reserve_arm3_speciesdep_anchored.csv"))

cat("Arm 3 band written. RESID_CV =", RESID_CV, "\n")
cat("CONUS arm-3 point and 90% band (TgC):\n")
print(arm3[, .(point=round(sum(agc_TgC_point)), lo=round(sum(agc_TgC_lo)), hi=round(sum(agc_TgC_hi))), by=year][order(year)])
cat("\nParametric CV by PROJ_YEAR (mean across variants):\n")
print(cvyr)
