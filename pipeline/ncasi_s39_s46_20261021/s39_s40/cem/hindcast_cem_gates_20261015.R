#!/usr/bin/env Rscript
# =============================================================================
# scripts/hindcast_multistate.R
#
# Multistate subject matched hindcast. Adapts scripts/build_subject_matched_cv.R
# from Maine to any state, then computes a comparison table against the p1
# projection cycles.
#
# For each state, this script:
#   1. Loads the cycle 1 subject plot list from output/<STATE>_<date>_<tag>/per_plot_projections.rds
#   2. Loads per state FIA TREE, COND, PLOT, POP_PLOT_STRATUM_ASSGN, POP_STRATUM, POP_EVAL, POP_EVAL_TYP
#   3. Computes observed AGC for each EXPALL EVALID using the standard EXPNS expansion,
#      restricted to the intersection of subject plots and the EVALID's plot list
#   4. Computes projected AGC for each cycle by joining per plot proj_carbon to the
#      same EXPNS factors (using the most recent EVALID as a representative weight)
#   5. Matches projection cycles to EVALID years (cycle 1 = baseline + 5, etc.)
#   6. Writes a hindcast table with year, observed, projected, residual, plus
#      summary RMSE and bias rows
#
# Usage:
#   Rscript scripts/hindcast_multistate.R --state WA --tag rcp45_wear_p1 --date 20260510
#   Rscript scripts/hindcast_multistate.R --state MN --tag rcp45_wear_p1 --date 20260510
#
# Output:
#   output/hindcast/HINDCAST_<STATE>_<tag>.csv
#   docs/HINDCAST_<STATE>_<TAG>.md (memo)
#
# Author: Aaron Weiskittel (built 13 May 2026)
# Revised 24 September 2026: condition identity moved from (PLT_CN, CONDID) to
#   (STATECD, COUNTYCD, PLOT, CONDID); subject list moved from PLT_CN to the
#   real plot identity; CONDPROP taken from FIA COND rather than the archive.
#   Previous file: hindcast_multistate_PREV_20260924.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(data.table)
})
# firebreather port, 28 Sep 2026: tidyverse, optparse and here are not installed
# on ifm-kershaw; dplyr + purrr + a minimal --key value parser replace them.
# Numerical logic is unchanged from hindcast_multistate_v20260924a.R.

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

opt <- list(state = NULL, tag = "rcp45_wear_p1", date = "20260510",
            fia_dir = "~/fia_data", baseline_year = 1999L, out_dir = NULL,
            archive = NULL)
.args <- commandArgs(trailingOnly = TRUE)
for (.i in seq(1, length(.args), by = 2)) {
  .k <- sub("^--", "", .args[.i]); .v <- .args[.i + 1]
  opt[[.k]] <- if (.k == "baseline_year") as.integer(.v) else .v
}

if (is.null(opt$state)) stop("--state is required.")
opt$state <- toupper(opt$state)

# 15 Oct 2026 gate copy: NH, VT, MI, WI added. Numerical logic unchanged.
STATE_CODES <- c(WA = 53L, MN = 27L, GA = 13L, ME = 23L,
                 NH = 33L, VT = 50L, MI = 26L, WI = 55L)
if (!opt$state %in% names(STATE_CODES)) stop("Unknown state: ", opt$state)
state_cd <- STATE_CODES[[opt$state]]

# Cycle length in years
CYCLE_YEARS <- 5L

# Unit conversions
# CRITICAL: proj_carbon column in per_plot_projections.rds is in LB/AC, not
# kg/ac, because R/01_data_prep.R builds carbon_ag = sum(TPA_UNADJ * CARBON_AG)
# where CARBON_AG is in pounds per tree (FIA convention). The same conversion
# factor applies to both observed and projected. Earlier versions of this
# script used 1e-9 for the projection, treating it as kg, which produced a
# spurious 2.2x over prediction. See VALIDATION_SYNTHESIS_20260513.md for the
# investigation history.
LB_TO_MMT <- 4.53592e-10

# -----------------------------------------------------------------------------
# Resolve paths
# -----------------------------------------------------------------------------

fia_root <- Sys.getenv("FIA_CEM_DIR", "~/fia_cem_projections")
out_base <- opt$out_dir %||% file.path(fia_root, "output")
# --archive names the archive directory explicitly, so a state can be read
# from another state's archive (its donor rows). Default is the original rule.
state_dir <- if (!is.null(opt$archive)) file.path(out_base, opt$archive) else
  file.path(out_base, sprintf("%s_%s_%s", opt$state, opt$date, opt$tag))
arch_lab <- basename(state_dir)

rds_file <- file.path(state_dir, "per_plot_projections.rds")
if (!file.exists(rds_file)) stop("per_plot RDS not found: ", rds_file)

fia_dir <- path.expand(opt$fia_dir)

out_csv  <- file.path(fia_root, "output", "hindcast",
                       sprintf("HINDCAST_%s_from_%s.csv", opt$state, arch_lab))
out_memo <- file.path(fia_root, "docs",
                       sprintf("HINDCAST_%s_from_%s.md", opt$state, arch_lab))
dir.create(dirname(out_csv),  showWarnings = FALSE, recursive = TRUE)
dir.create(dirname(out_memo), showWarnings = FALSE, recursive = TRUE)

cat(sprintf("State: %s (STATECD %d)\n", opt$state, state_cd))
cat(sprintf("Projection RDS: %s\n", rds_file))
cat(sprintf("FIA dir: %s\n\n", fia_dir))

# -----------------------------------------------------------------------------
# Load projection RDS, extract subject plots and per cycle projected AGC
# -----------------------------------------------------------------------------

cat("Loading per_plot RDS...\n")
t0 <- Sys.time()
d <- readRDS(rds_file)
cat(sprintf("  %d rows, %d cols, loaded in %.1f sec\n",
            nrow(d), ncol(d), as.numeric(Sys.time() - t0, units = "secs")))

# Filter to this state's BAU scenario for the hindcast comparison
d <- d |> filter(STATECD == state_cd, scenario == "BAU")
cat(sprintf("  After state + BAU filter: %d rows\n", nrow(d)))
if (nrow(d) == 0L) stop("No rows for ", opt$state, " in ", arch_lab)
if ("INVYR" %in% names(d)) {
  .iv <- d$INVYR[d$cycle == min(d$cycle)]
  cat(sprintf("ANCHOR: first cycle %d, INVYR %d to %d, cycles %d to %d\n",
              min(d$cycle), min(.iv), max(.iv), min(d$cycle), max(d$cycle)))
}

# -----------------------------------------------------------------------------
# CONDITION IDENTITY. Changed 24 September 2026.
#
# PLT_CN as written into these archives is not a usable identifier. Measured on
# Maine rows of the conus2100 archives it both fragments and merges: 22,306
# distinct values against 2,987 real plots, with 83 percent of those values
# spanning more than one real plot. The unique identity in these archives is
# (sim, STATECD, COUNTYCD, PLOT, CONDID, cycle), so the condition identity used
# here is (STATECD, COUNTYCD, PLOT, CONDID) and the trajectory adds sim.
#
# CONDPROP_UNADJ was also removed from the grouping. It travels with the
# imputation donor and therefore varies across sims for one real condition, so
# grouping on it split single conditions into several groups. Condition
# proportion is an FIA attribute, so it is now taken from the FIA COND table on
# both the observed and the projected side, which also makes the two symmetric.
# The archive's own mean CONDPROP is retained only as a reported sensitivity.
#
# Previous behaviour is preserved in hindcast_multistate_PREV_20260924.R.
# -----------------------------------------------------------------------------

id_cols <- c("STATECD", "COUNTYCD", "PLOT", "CONDID")
stopifnot(all(id_cols %in% names(d)))

# Identity diagnostics, printed so the delivered log carries them
idf <- data.frame(PLT_CN   = as.character(d$PLT_CN),
                  STATECD  = as.integer(d$STATECD),
                  COUNTYCD = as.integer(d$COUNTYCD),
                  PLOT     = as.integer(d$PLOT),
                  CONDID   = as.integer(d$CONDID),
                  cycle    = as.integer(d$cycle),
                  stringsAsFactors = FALSE)
n_pltcn   <- length(unique(idf$PLT_CN))
n_loc     <- nrow(unique(idf[, c("STATECD","COUNTYCD","PLOT")]))
n_cond    <- nrow(unique(idf[, c("STATECD","COUNTYCD","PLOT","CONDID")]))
cat(sprintf("Identity check: %d distinct PLT_CN, %d distinct (STATECD,COUNTYCD,PLOT), %d distinct conditions\n",
            n_pltcn, n_loc, n_cond))
pl_map <- unique(idf[, c("PLT_CN","STATECD","COUNTYCD","PLOT")])
n_multi <- sum(table(pl_map$PLT_CN) > 1L)
cat(sprintf("Identity check: %d of %d PLT_CN values span more than one real plot (%.1f percent)\n\n",
            n_multi, n_pltcn, 100 * n_multi / max(n_pltcn, 1L)))

# Subject conditions and subject plots are cycle 1 locations, on the real identity
subj_loc <- unique(idf[idf$cycle == 1L, c("STATECD","COUNTYCD","PLOT")])
subj_key <- paste(subj_loc$STATECD, subj_loc$COUNTYCD, subj_loc$PLOT, sep = "_")
cat(sprintf("Subject plot count (cycle 1, real identity): %d\n\n", length(subj_key)))

# Per cycle projected AGC at the condition level, mean across sims
proj_per_plot <- d |>
  group_by(STATECD, COUNTYCD, PLOT, CONDID, cycle) |>
  summarise(proj_carbon_lbac = mean(proj_carbon, na.rm = TRUE),
            condprop_archive = mean(CONDPROP_UNADJ, na.rm = TRUE),
            n_sim            = dplyr::n(),
            .groups = "drop") |>
  mutate(loc_key = paste(as.integer(STATECD), as.integer(COUNTYCD),
                         as.integer(PLOT), sep = "_"),
         CONDID  = as.integer(CONDID))

rm(d, idf); gc()

cat(sprintf("Aggregated projection: %d condition x cycle rows\n\n",
            nrow(proj_per_plot)))

# -----------------------------------------------------------------------------
# Load FIA tables for this state
# -----------------------------------------------------------------------------

cat("Loading FIA tables...\n")
t0 <- Sys.time()

tre_path <- file.path(fia_dir, sprintf("%s_TREE.csv", opt$state))
cnd_path <- file.path(fia_dir, sprintf("%s_COND.csv", opt$state))
plt_path <- file.path(fia_dir, sprintf("%s_PLOT.csv", opt$state))
ppsa_path <- file.path(fia_dir, sprintf("%s_POP_PLOT_STRATUM_ASSGN.csv", opt$state))
ps_path  <- file.path(fia_dir, sprintf("%s_POP_STRATUM.csv", opt$state))
pe_path  <- file.path(fia_dir, sprintf("%s_POP_EVAL.csv", opt$state))
pet_path <- file.path(fia_dir, sprintf("%s_POP_EVAL_TYP.csv", opt$state))

tre <- fread(tre_path,
             select = c("PLT_CN","CONDID","STATUSCD","DIA","TPA_UNADJ",
                        "CARBON_AG"),
             colClasses = list(character = "PLT_CN"))
cnd <- fread(cnd_path,
             select = c("PLT_CN","CONDID","CONDPROP_UNADJ","COND_STATUS_CD"),
             colClasses = list(character = "PLT_CN"))
plt  <- fread(plt_path,
             select = c("CN","STATECD","COUNTYCD","PLOT","INVYR"),
             colClasses = list(character = "CN"))
data.table::setnames(plt, "CN", "PLT_CN")
plt[, loc_key := paste(as.integer(STATECD), as.integer(COUNTYCD),
                       as.integer(PLOT), sep = "_")]
ppsa <- fread(ppsa_path, colClasses = list(character = c("PLT_CN","STRATUM_CN")))
ps   <- fread(ps_path,   colClasses = list(character = "CN"))
pe   <- fread(pe_path,   colClasses = list(character = "CN"))
pet  <- fread(pet_path,  colClasses = list(character = "EVAL_CN"))

cat(sprintf("  TREE %d rows, COND %d rows, PPSA %d rows, loaded in %.1f sec\n",
            nrow(tre), nrow(cnd), nrow(ppsa),
            as.numeric(Sys.time() - t0, units = "secs")))

# -----------------------------------------------------------------------------
# Per condition observed AGC (live trees, DIA >= 1.0)
# -----------------------------------------------------------------------------

cond_agc <- tre[STATUSCD == 1 & DIA >= 1.0,
                .(carbon_per_ac = sum(TPA_UNADJ * CARBON_AG, na.rm = TRUE)),
                by = .(PLT_CN, CONDID)]
cond_agc <- cnd[COND_STATUS_CD == 1, .(PLT_CN, CONDID, CONDPROP_UNADJ)][
  cond_agc, on = c("PLT_CN","CONDID"), nomatch = NULL]
rm(tre); gc()

# -----------------------------------------------------------------------------
# Pull EXPALL EVALIDs and EXPNS factors
# -----------------------------------------------------------------------------

evt <- merge(pet[, .(EVAL_CN, EVAL_TYP)],
             pe[, .(CN, EVALID, END_INVYR)],
             by.x = "EVAL_CN", by.y = "CN")
evt <- evt[EVAL_TYP == "EXPALL"][order(END_INVYR)]
cat(sprintf("\nEXPALL EVALIDs: %d (years %d to %d)\n",
            nrow(evt), min(evt$END_INVYR), max(evt$END_INVYR)))

# -----------------------------------------------------------------------------
# Per EVALID: observed full panel AGC, observed subject AGC, projected AGC
# matched to the cycle that aligns with END_INVYR
# -----------------------------------------------------------------------------

cat("\nComputing per EVALID observed vs projected AGC...\n")

results <- map_dfr(seq_len(nrow(evt)), function(i) {
  e <- evt[i, ]

  expns_e <- ppsa[EVALID == e$EVALID][ps, on = c("STRATUM_CN" = "CN"),
                                       nomatch = NULL]
  expns_e <- unique(expns_e[, .(PLT_CN = as.character(PLT_CN), EXPNS)],
                    by = "PLT_CN")

  # Observed AGC, full panel
  obs_full <- cond_agc[expns_e, on = "PLT_CN", nomatch = NULL]
  obs_full_agc <- sum(obs_full$carbon_per_ac * obs_full$CONDPROP_UNADJ *
                       obs_full$EXPNS, na.rm = TRUE) * LB_TO_MMT

  # Bridge this EVALID's PLT_CN list to the real plot identity via the FIA PLOT table
  expns_loc <- plt[expns_e, on = "PLT_CN", nomatch = NULL][
    , .(PLT_CN, loc_key, EXPNS)]
  expns_loc <- unique(expns_loc, by = "PLT_CN")
  subj_pltcn <- expns_loc[loc_key %in% subj_key, PLT_CN]

  # Observed AGC, subject only (intersection of subject locations and EVALID plots)
  obs_subj <- obs_full[PLT_CN %in% subj_pltcn]
  obs_subj_agc <- sum(obs_subj$carbon_per_ac * obs_subj$CONDPROP_UNADJ *
                       obs_subj$EXPNS, na.rm = TRUE) * LB_TO_MMT

  # Match this EVALID year to a projection cycle.
  # Baseline year + cycle * CYCLE_YEARS == END_INVYR  =>  cycle = (END_INVYR - baseline) / 5
  cycle_match <- (e$END_INVYR - opt$baseline_year) / CYCLE_YEARS
  cycle_match <- if (cycle_match == round(cycle_match) &&
                     cycle_match >= 1 && cycle_match <= 15) {
    as.integer(round(cycle_match))
  } else NA_integer_

  proj_agc  <- NA_real_
  proj_agc_arch <- NA_real_
  n_proj_cond <- NA_integer_
  if (!is.na(cycle_match)) {
    # This EVALID's conditions, with the FIA condition proportion and EXPNS,
    # carried on the real plot identity rather than on PLT_CN
    eval_cond <- cnd[COND_STATUS_CD == 1,
                     .(PLT_CN, CONDID = as.integer(CONDID), CONDPROP_UNADJ)][
      expns_loc, on = "PLT_CN", nomatch = NULL]
    pj <- proj_per_plot |>
      filter(cycle == cycle_match) |>
      inner_join(as.data.frame(eval_cond), by = c("loc_key", "CONDID"))
    n_proj_cond <- nrow(pj)
    proj_agc <- sum(pj$proj_carbon_lbac * pj$CONDPROP_UNADJ * pj$EXPNS,
                     na.rm = TRUE) * LB_TO_MMT
    proj_agc_arch <- sum(pj$proj_carbon_lbac * pj$condprop_archive * pj$EXPNS,
                     na.rm = TRUE) * LB_TO_MMT
  }

  data.frame(
    year                  = as.integer(e$END_INVYR),
    EVALID                = e$EVALID,
    cycle_match           = cycle_match,
    n_full_plots          = nrow(expns_e),
    n_subj_plots_in_eval  = length(subj_pltcn),
    n_proj_conditions     = n_proj_cond,
    obs_full_agc_mmt      = round(obs_full_agc, 1),
    obs_subj_agc_mmt      = round(obs_subj_agc, 1),
    proj_subj_agc_mmt     = round(proj_agc, 1),
    proj_subj_agc_archcp_mmt = round(proj_agc_arch, 1),
    residual_mmt          = round(proj_agc - obs_subj_agc, 1)
  )
})

# Summary stats: RMSE and bias over years with matched projections
matched <- results[!is.na(results$cycle_match) & !is.na(results$proj_subj_agc_mmt), ]
rmse <- if (nrow(matched) > 0) {
  sqrt(mean((matched$residual_mmt)^2, na.rm = TRUE))
} else NA_real_
bias <- if (nrow(matched) > 0) {
  mean(matched$residual_mmt, na.rm = TRUE)
} else NA_real_

# -----------------------------------------------------------------------------
# Write outputs
# -----------------------------------------------------------------------------

fwrite(results, out_csv)
cat(sprintf("\nWrote %s\n", out_csv))

# Markdown memo
sink(out_memo)
cat(sprintf("# Hindcast validation: %s %s\n\n", opt$state, toupper(opt$tag)))
cat(sprintf("*Generated %s from %s*\n\n",
            format(Sys.time(), "%Y-%m-%d %H:%M %Z"), state_dir))

cat("## Summary\n\n")
cat(sprintf("- Subject plot count (cycle 1, real identity): %d\n", length(subj_key)))
cat(sprintf("- EXPALL EVALIDs analyzed: %d\n", nrow(results)))
cat(sprintf("- Year range: %d to %d\n",
            min(results$year), max(results$year)))
matched_years <- matched$year
if (length(matched_years) > 0) {
  cat(sprintf("- Years with projection match: %s\n",
              paste(matched_years, collapse = ", ")))
}
if (!is.na(rmse)) {
  cat(sprintf("- **RMSE: %.1f MMT AGC**\n", rmse))
  cat(sprintf("- **Bias: %+.1f MMT AGC** (projected minus observed)\n", bias))
  cat(sprintf("- RMSE as percent of observed mean: %.1f%%\n",
              100 * rmse / mean(matched$obs_subj_agc_mmt)))
  cat(sprintf("- Bias as percent of observed mean: %+.1f%%\n",
              100 * bias / mean(matched$obs_subj_agc_mmt)))
}
cat("\n")

cat("## Detail by EVALID\n\n")
cat("| Year | EVALID | Cycle | N full plots | N subj plots | Obs full (MMT) | Obs subj (MMT) | Proj subj (MMT) | Residual (MMT) |\n",
    "|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n", sep = "")
for (i in seq_len(nrow(results))) {
  r <- results[i, ]
  cat(sprintf("| %d | %s | %s | %d | %d | %.1f | %.1f | %s | %s |\n",
              r$year, as.character(r$EVALID),
              if (is.na(r$cycle_match)) "—" else as.character(r$cycle_match),
              r$n_full_plots, r$n_subj_plots_in_eval,
              r$obs_full_agc_mmt, r$obs_subj_agc_mmt,
              if (is.na(r$proj_subj_agc_mmt)) "—" else sprintf("%.1f", r$proj_subj_agc_mmt),
              if (is.na(r$residual_mmt)) "—" else sprintf("%+.1f", r$residual_mmt)))
}
cat("\n")

cat("## Interpretation\n\n")
if (!is.na(rmse)) {
  ref_mean <- mean(matched$obs_subj_agc_mmt)
  pct_rmse <- 100 * rmse / ref_mean
  pct_bias <- 100 * bias / ref_mean
  status <- if (pct_rmse < 10 && abs(pct_bias) < 5) {
    "Strong hindcast performance."
  } else if (pct_rmse < 20 && abs(pct_bias) < 10) {
    "Acceptable hindcast performance."
  } else {
    "Hindcast performance outside expected bounds; investigate."
  }
  cat(sprintf("%s RMSE of %.1f MMT is %.1f%% of the subject matched observed mean ",
              status, rmse, pct_rmse))
  cat(sprintf("(%.1f MMT). Bias of %+.1f MMT is %+.1f%% of the observed mean.\n\n",
              ref_mean, bias, pct_bias))

  cat("Reference line removed 24 September 2026. The string previously printed here,\n")
  cat("\"ME r11 hindcast (reference): RMSE 16 MMT AGC (6% of mean), bias -2 MMT (-1.1%)\",\n")
  cat("was a hardcoded literal in this script, not a value computed by any run it\n")
  cat("produced. It is the origin of the 16 MMT AGC figure that circulated as a\n")
  cat("result. Cite the RMSE computed above instead.\n")
}
sink()
cat(sprintf("Wrote %s\n", out_memo))

print(results)
cat(sprintf("SUMMARY,%s,%s,%d,%.4f,%.4f,%.4f\n", opt$state, arch_lab, nrow(matched),
            rmse, bias, mean(matched$obs_subj_agc_mmt)))
cat(sprintf("\nRMSE: %.1f MMT, Bias: %+.1f MMT\n",
            rmse %||% NA_real_, bias %||% NA_real_))
