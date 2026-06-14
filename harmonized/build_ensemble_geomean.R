# =============================================================================
# Title: Full-coverage states + geometric-mean ensemble
# Author: A. Weiskittel
# Date: 2026-06-13
# Description: (1) Recompute which states have ALL FIVE models present (current
#   coverage, not the cached IN/OH/NH). (2) Add a geometric-mean ensemble
#   (exp(mean(log x))) alongside the arithmetic mean and median, for the reserve
#   and across scenarios, at the full-overlap states. Geometric mean is the
#   natural central estimate for strictly positive, multiplicatively varying
#   stocks and is less swayed by the high FVS end-member than the arithmetic mean.
# Dependencies: FIA/<model>_reserve_(anchored|disturbed).csv, harmonized_master_all_scenarios.csv
# =============================================================================
suppressPackageStartupMessages({library(data.table)})
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
YEARS <- c(2025, 2050, 2075, 2100)
files <- c(FVS = "fvs_reserve_calibrated_anchored.csv", YieldCurve = "yc_reserve_anchored.csv",
           CBM = "cbm_reserve_anchored.csv", CEM = "cem_reserve_anchored.csv",
           LANDIS = "harmonized_landis_reserve_9state.csv")
mods <- lapply(files, function(f) { d <- fread(file.path(FIA, f))[scenario == "reserve"]
  d[, dom := sprintf("%02d", as.integer(dom))]; d })

# --- (1) coverage: states present in every model -----------------------------
doms <- lapply(mods, function(d) unique(d$dom))
full <- Reduce(intersect, doms)
fips2ab <- c("18"="IN","39"="OH","33"="NH","27"="MN","55"="WI","26"="MI","53"="WA","23"="ME","50"="VT",
             "13"="GA","36"="NY","42"="PA","24"="MD","54"="WV","34"="NJ","21"="KY","47"="TN","29"="MO",
             "17"="IL","37"="NC","45"="SC","12"="FL","1"="AL","28"="MS","22"="LA","41"="OR","6"="CA")
cat("Model coverage (state count): ",
    paste(sprintf("%s=%d", names(doms), sapply(doms, length)), collapse = "  "), "\n")
cat("FULL 5-model overlap states (n=", length(full), "): ",
    paste(sort(na.omit(fips2ab[full])), collapse = ", "), "\n\n", sep = "")

# --- (2) ensembles at full-overlap states, reserve --------------------------
gm <- function(x) exp(mean(log(x)))           # geometric mean (x > 0)
interp <- function(d, dm, yr) { s <- d[dom == dm][order(year)]
  if (nrow(s) < 2) return(NA_real_); approx(s$year, s$agc_TgC_anchored, yr, rule = 2)$y }
ens <- rbindlist(lapply(full, function(dm) rbindlist(lapply(YEARS, function(yr) {
  v <- sapply(mods, interp, dm = dm, yr = yr); v <- v[is.finite(v) & v > 0]
  if (length(v) < 3) return(NULL)
  data.table(state = fips2ab[dm], year = yr, n = length(v),
             arith_mean = round(mean(v), 1), geom_mean = round(gm(v), 1),
             median = round(median(v), 1),
             geom_vs_arith_pct = round(100 * (gm(v) - mean(v)) / mean(v), 1))
}))))
fwrite(ens, file.path(FIA, "harmonized_ensemble_geomean.csv"))
cat("Reserve ensemble at full-overlap states (Tg C), 2100:\n")
print(ens[year == 2100][order(state)])

# --- CONUS reserve: arithmetic vs geometric (over full-coverage models) -----
# Use the three full-CONUS models (FVS,YC,CBM = 48 states) for a CONUS-wide compare.
cm <- c("FVS","YieldCurve","CBM")
conus <- rbindlist(lapply(YEARS, function(yr) {
  per_state <- rbindlist(lapply(unique(mods$CBM$dom), function(dm) {
    v <- sapply(mods[cm], interp, dm = dm, yr = yr); v <- v[is.finite(v) & v > 0]
    if (length(v) < 3) return(NULL)
    data.table(arith = mean(v), geom = gm(v), med = median(v)) }))
  data.table(year = yr, arith_Pg = round(sum(per_state$arith)/1000, 1),
             geom_Pg = round(sum(per_state$geom)/1000, 1),
             median_Pg = round(sum(per_state$med)/1000, 1)) }))
fwrite(conus, file.path(FIA, "harmonized_conus_geomean.csv"))
cat("\nCONUS reserve (Pg C), FVS+YC+CBM, arithmetic vs geometric vs median:\n")
print(conus)
