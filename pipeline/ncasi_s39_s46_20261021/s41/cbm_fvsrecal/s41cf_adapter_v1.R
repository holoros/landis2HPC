#!/usr/bin/env Rscript
## ---------------------------------------------------------------------------
## build_sit_yield_from_fvs
##
## Emits GCBM / libcbm yield tables (sit_yield.csv) from NCASI FVS stand
## trajectories, in the exact schema that GCBM2hpc build_gcbm_input_state.py
## expects at states/<ST>/data/processed/sit_yield.csv:
##
##   geography, ECOREGION_L3_CODE, TYPGRPCD, forest_type_group, stand_age, vol_m3_ha
##
## Writing that file stops the Maine fallback firing, so every one of the six
## NCASI states runs on its own engine curves instead of Maine ones.
##
## Functional form and age grid follow cbm_maine/R/utils.R line 82 and
## cbm_maine config/config.yml so the two are directly comparable:
##   Chapman-Richards  V(t) = b0 * (1 - exp(-b1 * t))^b2 , ages 0 to 200 by 1.
##
## Deliberate departures from the cbm_maine implementation, each stated:
##   1. No Maine cap table is applied. The Maine caps are carried as an
##      EXTERNAL plausibility reference and the comparison is reported, not
##      enforced. Capping here would police one project artifact with another.
##   2. geography is state_mean and ECOREGION_L3_CODE is NA, because assigning
##      an EPA Level III ecoregion to a stand needs FIA true plot coordinates,
##      which stay on Cardinal. Per-ecoregion curves are a Cardinal-side step.
##   3. Ages beyond the observed FVS domain are emitted but flagged in a
##      companion extrapolation ledger rather than silently shipped.
##   4. v2. The asymptote b0 is bounded on each stratum instead of capped
##      after the fact. An unconstrained Chapman-Richards fitted on a 50 yr
##      FVS window is not identifiable: b1 collapses toward zero and b0 runs
##      away, which in v1 produced asymptotes up to 84 times the Maine
##      reference ceiling on 13 of 66 strata. Bounding b0 within
##      [obs_vol_max, B0_UPPER_MULT * obs_vol_max] is the identifiability fix;
##      the Maine cap table then stays a reference rather than a mechanism.
##   5. v2. Thin strata are no longer dropped. A stratum with fewer than
##      MIN_STANDS stands falls back to the same forest type group fitted at
##      region scope, then at six state scope, and fit_scope records which.
##      This replaces the cbm_maine behaviour of falling back to Maine.
##
## Input:  fvs_growth_points_DATA_2026-09-17.csv  (no harvest, both FVS arms)
## Author: NCASI Model Evaluation Phase II
## ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(data.table)
  library(minpack.lm)
})

set.seed(20260917)
options(stringsAsFactors = FALSE)

## s41 cbm_fvsrecal copy (16 Oct 2026): ONLY change is that input and output paths
## come from the command line: Rscript s41cf_adapter_v1.R <points.csv> <outdir>
.s41a <- commandArgs(TRUE)
IN_CSV    <- .s41a[1]
OUT_DIR   <- .s41a[2]
ERR_LOG   <- file.path(OUT_DIR, "error_log.txt")
AGE_MAX   <- 200L
AGE_GRID  <- 0:AGE_MAX
MIN_STANDS <- 10L        # stratum gate: fewer than this is not fitted
RESPONSE  <- "merch_vol_m3ha"
B0_UPPER_MULT <- 2.0     # [ASSUMPTION: an unmanaged stratum asymptote does not
                         # exceed twice the maximum volume FVS actually reached
                         # in that stratum. Labeled, and swept in the sensitivity
                         # block at the end of this script.]

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)
logerr <- function(where, e) {
  cat(sprintf("[%s] %s: %s\n", format(Sys.time()), where,
              conditionMessage(e)), file = ERR_LOG, append = TRUE)
}

## External plausibility reference (F5). Source: cbm_maine
## 02_yield_curves/import_yield_curves.R maine_max_caps. Held OUTSIDE this
## computation. Used to flag, never to truncate.
maine_ref_cap <- data.table(
  forest_type_group = c("Spruce / fir group", "White / red / jack pine group",
                        "Maple / beech / birch group", "Aspen / birch group",
                        "Oak / pine group", "Oak / hickory group",
                        "Elm / ash / cottonwood group", "Other hardwoods group",
                        "Exotic softwoods group", "Loblolly / shortleaf pine group",
                        "Longleaf / slash pine group"),
  maine_ref_m3_ha   = c(400, 500, 450, 350, 400, 350, 350, 400, 500, 500, 500))

## --- load ------------------------------------------------------------------
dt <- tryCatch(fread(IN_CSV), error = function(e) { logerr("fread", e); NULL })
if (is.null(dt)) stop("input not readable")
setnames(dt, RESPONSE, "vol")
dt <- dt[is.finite(vol) & is.finite(stand_age) & stand_age >= 0]
cat(sprintf("loaded %d points, %d stands, %d states, %d arms\n",
            nrow(dt), uniqueN(dt$stand_id), uniqueN(dt$state), uniqueN(dt$arm)))

## --- fit -------------------------------------------------------------------
fit_cr <- function(age, vol, b0_mult = B0_UPPER_MULT) {
  vmax <- max(vol, na.rm = TRUE)
  if (!is.finite(vmax) || vmax <= 0) return(NULL)
  st <- list(b0 = vmax * 1.05, b1 = 0.03, b2 = 2)
  tryCatch(
    nlsLM(vol ~ b0 * (1 - exp(-b1 * age))^b2, start = st,
          lower = c(b0 = vmax,            b1 = 1e-6, b2 = 1e-6),
          upper = c(b0 = vmax * b0_mult,  b1 = 1,    b2 = 20),
          control = nls.lm.control(maxiter = 400)),
    error = function(e) NULL)
}

## Fit one forest type group at a named scope and return coefficients or NULL.
fit_scope_group <- function(d) {
  if (!nrow(d)) return(NULL)
  m <- fit_cr(d$stand_age, d$vol)
  if (is.null(m)) return(NULL)
  cf <- coef(m)
  list(b0 = unname(cf["b0"]), b1 = unname(cf["b1"]), b2 = unname(cf["b2"]),
       rmse = sqrt(mean(residuals(m)^2)), n_stands = uniqueN(d$stand_id),
       n_points = nrow(d), age_hi = max(d$stand_age), age_lo = min(d$stand_age))
}

## Pre-fit the two fallback scopes so a thin state stratum inherits the same
## forest type group from its own region, never from another region.
region_of <- unique(dt[, .(state, region)])
fb_region <- list(); fb_pool <- list()
for (rg in unique(dt$region)) {
  for (g in unique(dt[region == rg]$TYPGRPCD)) {
    for (a in unique(dt$arm)) {
      f <- fit_scope_group(dt[region == rg & TYPGRPCD == g & arm == a])
      if (!is.null(f)) fb_region[[paste(rg, g, a, sep = "|")]] <- f
    }
  }
}
for (g in unique(dt$TYPGRPCD)) {
  for (a in unique(dt$arm)) {
    f <- fit_scope_group(dt[TYPGRPCD == g & arm == a])
    if (!is.null(f)) fb_pool[[paste(g, a, sep = "|")]] <- f
  }
}
cat(sprintf("fallback fits: region %d, pooled %d\n", length(fb_region), length(fb_pool)))

strata <- unique(dt[, .(region, state, arm, TYPGRPCD, forest_type_group)])
coef_rows <- list(); curve_rows <- list(); i <- 0L

for (k in seq_len(nrow(strata))) {
  s <- strata[k]
  d <- dt[state == s$state & arm == s$arm & TYPGRPCD == s$TYPGRPCD]
  n_stands <- uniqueN(d$stand_id)
  f <- NULL; scope <- NA_character_
  if (n_stands >= MIN_STANDS) { f <- fit_scope_group(d); if (!is.null(f)) scope <- "state" }
  if (is.null(f)) {
    f <- fb_region[[paste(s$region, s$TYPGRPCD, s$arm, sep = "|")]]
    if (!is.null(f)) scope <- "region"
  }
  if (is.null(f)) {
    f <- fb_pool[[paste(s$TYPGRPCD, s$arm, sep = "|")]]
    if (!is.null(f)) scope <- "pooled_six_state"
  }
  base <- data.table(region = s$region, state = s$state, arm = s$arm,
                     TYPGRPCD = s$TYPGRPCD, forest_type_group = s$forest_type_group,
                     n_stands_state = n_stands,
                     obs_age_min = min(d$stand_age), obs_age_max = max(d$stand_age),
                     obs_vol_max = max(d$vol))
  if (is.null(f)) {
    i <- i + 1L
    coef_rows[[i]] <- cbind(base, data.table(fit_scope = "none", n_stands_fit = NA_integer_,
      n_points_fit = NA_integer_, fit_age_max = NA_real_, b0 = NA_real_,
      b1 = NA_real_, b2 = NA_real_, rmse = NA_real_, status = "no_convergence"))
    next
  }
  i <- i + 1L
  coef_rows[[i]] <- cbind(base, data.table(fit_scope = scope, n_stands_fit = f$n_stands,
    n_points_fit = f$n_points, fit_age_max = f$age_hi, b0 = f$b0, b1 = f$b1,
    b2 = f$b2, rmse = f$rmse, status = "fitted"))
  curve_rows[[length(curve_rows) + 1L]] <- data.table(
    geography = "state_mean", ECOREGION_L3_CODE = NA_integer_,
    state = s$state, arm = s$arm, TYPGRPCD = s$TYPGRPCD,
    forest_type_group = s$forest_type_group, fit_scope = scope, stand_age = AGE_GRID,
    vol_m3_ha = pmax(0, f$b0 * (1 - exp(-f$b1 * AGE_GRID))^f$b2),
    extrapolated = AGE_GRID > f$age_hi)
}

coefs  <- rbindlist(coef_rows)
curves <- rbindlist(curve_rows)
gc()

## --- gates -----------------------------------------------------------------
## F5 absolute plausibility: compare the fitted asymptote b0 against the
## external Maine reference ceiling. Flag, do not truncate.
coefs <- merge(coefs, maine_ref_cap, by = "forest_type_group", all.x = TRUE)
coefs[, asymptote_vs_maine_ref := b0 / maine_ref_m3_ha]
coefs[, gate_F5_asymptote := fifelse(is.na(maine_ref_m3_ha), "no_reference",
                              fifelse(is.na(b0), "not_fitted",
                              fifelse(asymptote_vs_maine_ref > 2, "FLAG_high",
                              fifelse(asymptote_vs_maine_ref < 0.25, "FLAG_low", "pass"))))]
## Extrapolation ledger: what share of the emitted 0 to 200 grid is beyond data.
coefs[, extrap_share := fifelse(is.na(fit_age_max), NA_real_,
                          (AGE_MAX - pmin(fit_age_max, AGE_MAX)) / AGE_MAX)]
## Monotonicity: Chapman-Richards is monotone by construction, verify anyway.
mono <- curves[, .(monotone = all(diff(vol_m3_ha) >= -1e-9)), by = .(state, arm, TYPGRPCD)]
coefs[, b0_at_upper_bound := !is.na(b0) & abs(b0 - obs_vol_max * B0_UPPER_MULT) < 1e-6 * obs_vol_max]
coefs <- merge(coefs, mono, by = c("state", "arm", "TYPGRPCD"), all.x = TRUE)

setorder(coefs, region, state, arm, TYPGRPCD)
fwrite(coefs, file.path(OUT_DIR, "yield_curve_coefficients_DATA_2026-09-17.csv"))

## --- emit sit_yield.csv per state per arm ----------------------------------
SIT_COLS <- c("geography", "ECOREGION_L3_CODE", "TYPGRPCD",
              "forest_type_group", "stand_age", "vol_m3_ha")
for (st in sort(unique(curves$state))) {
  for (a in sort(unique(curves$arm))) {
    d <- curves[state == st & arm == a]
    if (!nrow(d)) next
    setorder(d, TYPGRPCD, stand_age)
    f <- file.path(OUT_DIR, sprintf("sit_yield_%s_%s.csv", st, a))
    fwrite(d[, ..SIT_COLS], f)
    cat(sprintf("wrote %s  groups=%d rows=%d\n", basename(f),
                uniqueN(d$TYPGRPCD), nrow(d)))
  }
}
fwrite(curves, file.path(OUT_DIR, "yield_curves_long_DATA_2026-09-17.csv"))

## --- headless figure -------------------------------------------------------
tryCatch({
  png(file.path(OUT_DIR, "f1-fvs-yield-curves_FIG_2026-09-17.png"),
      width = 2400, height = 1600, res = 300)
  op <- par(mfrow = c(2, 3), mar = c(4, 4, 2.5, 0.8), mgp = c(2.4, 0.8, 0),
            bg = "white", las = 1, cex.axis = 0.8)
  sts <- c("ME", "NH", "VT", "MI", "WI", "MN")
  grps <- sort(unique(curves$TYPGRPCD))
  pal <- hcl.colors(length(grps), "Dark 3")
  names(pal) <- as.character(grps)
  ymax <- max(curves[extrapolated == FALSE]$vol_m3_ha, na.rm = TRUE) * 1.15
  for (st in sts) {
    plot(NA, xlim = c(0, 200), ylim = c(0, ymax), xlab = "Stand age (yr)",
         ylab = expression(paste("Merchantable volume (", m^3, " ", ha^-1, ")")),
         main = st, font.main = 2)
    for (g in grps) {
      d <- curves[state == st & arm == "calibrated" & TYPGRPCD == g]
      if (!nrow(d)) next
      lines(d$stand_age[!d$extrapolated], d$vol_m3_ha[!d$extrapolated],
            col = pal[as.character(g)], lwd = 2.2)
      lines(d$stand_age[d$extrapolated], d$vol_m3_ha[d$extrapolated],
            col = pal[as.character(g)], lwd = 1.1, lty = 3)
    }
  }
  par(op); dev.off()
}, error = function(e) { logerr("figure", e); try(dev.off(), silent = TRUE) })

## --- run summary -----------------------------------------------------------
cat("\n--- fit summary ---\n")
print(coefs[, .N, by = status])
cat("\n--- F5 asymptote gate ---\n")
print(coefs[, .N, by = gate_F5_asymptote])
cat("\n--- fit scope ---\n")
print(coefs[, .N, by = fit_scope])
cat("\n--- strata pinned at the b0 upper bound (identifiability watch) ---\n")
print(coefs[, .N, by = b0_at_upper_bound])
cat("\n--- fitted strata ---\n")
print(coefs[status == "fitted" & arm == "calibrated",
      .(state, TYPGRPCD, scope = fit_scope, n = n_stands_state,
        obs_max = round(obs_vol_max), b0 = round(b0, 1), b1 = round(b1, 4),
        b2 = round(b2, 2), rmse = round(rmse, 1),
        ref_ratio = round(asymptote_vs_maine_ref, 2), gate_F5_asymptote)])

## --- B0_UPPER_MULT sensitivity ---------------------------------------------
cat("\n--- B0_UPPER_MULT sensitivity, calibrated arm, state-scope strata ---\n")
sens <- rbindlist(lapply(c(1.5, 2.0, 3.0), function(mm) {
  st2 <- unique(dt[arm == "calibrated", .(state, TYPGRPCD)])
  rr <- rbindlist(lapply(seq_len(nrow(st2)), function(j) {
    d <- dt[arm == "calibrated" & state == st2$state[j] & TYPGRPCD == st2$TYPGRPCD[j]]
    if (uniqueN(d$stand_id) < MIN_STANDS) return(NULL)
    m <- fit_cr(d$stand_age, d$vol, b0_mult = mm)
    if (is.null(m)) return(NULL)
    data.table(mult = mm, v100 = unname(coef(m)["b0"]) *
      (1 - exp(-unname(coef(m)["b1"]) * 100))^unname(coef(m)["b2"]))
  }))
  rr
}))
print(sens[, .(n = .N, median_v100 = round(median(v100), 1),
               q10 = round(quantile(v100, 0.1), 1),
               q90 = round(quantile(v100, 0.9), 1)), by = mult])
cat("\ndone\n")
