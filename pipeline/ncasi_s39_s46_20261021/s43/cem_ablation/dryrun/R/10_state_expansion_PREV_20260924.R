# =============================================================================
# Title: State-Level Expansion for FIA CEM Projections (carbon, volume, RD)
# Author: A. Weiskittel
# Date: 2026-04-17
# Description: Post-processing for per-plot CEM projection output. Joins
#              FIA EXPNS weights (POP_PLOT_STRATUM_ASSGN + POP_STRATUM) to
#              per-plot projected values and aggregates to statewide totals
#              for the four primary attributes:
#                1. Aboveground carbon       (MMT AGC)
#                2. Total volume             (million ft3, from VOLCFNET)
#                3. Merchantable volume      (million ft3, from VOLCSNET)
#                4. Relative density         (area-weighted mean RD using
#                                             Woodall & Weiskittel 2021 SDImax
#                                             by ecoregion and forest type)
#
# Inputs:
#   per_plot_projections.rds   (one row per scenario x sim x cycle x condition)
#   config/sdimax_me.csv       (Woodall & Weiskittel 2021 SDImax by state x
#                               ecoregion x forest type)
#   config/REF_FOREST_TYPE.csv (FIA FORTYPCD -> MEANING lookup)
#   state POP_* CSVs           (for EXPNS)
#
# Output: one CSV per scenario set with long-form metric columns.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(data.table)
})

# ----------------------------------------------------------------------------
# 1. Unit conversions and constants
# ----------------------------------------------------------------------------
LB_TO_MMT   <- 4.53592e-10      # lb -> million metric tons
FT3_TO_MCF  <- 1e-6             # ft3 -> million cubic feet (for display)
# Reineke's SDI: SDI = TPA * (QMD / 10)^1.605 (inches-DBH convention)
REINEKE_EXP <- 1.605

# ----------------------------------------------------------------------------
# 2. EXPNS lookup (reads POP CSVs directly)
# ----------------------------------------------------------------------------
get_plot_expns <- function(state = "ME",
                           fia_dir = "~/fia_data",
                           evalid  = NULL) {

  cat(sprintf("Loading FIA POP tables for %s from %s\n", state, fia_dir))

  read_pop <- function(tbl) {
    f <- file.path(fia_dir, paste0(state, "_", tbl, ".csv"))
    if (!file.exists(f)) {
      stop(sprintf("%s not found. Run download_fia_pop.sh first.", f))
    }
    dt <- data.table::fread(
      f, showProgress = FALSE,
      colClasses = list(character = c("CN","PLT_CN","STRATUM_CN","EVAL_CN",
                                      "RSCD","PREV_STR_CN","PREV_PPSA_CN"))
    )
    as_tibble(dt)
  }

  POP_STRATUM            <- read_pop("POP_STRATUM")
  POP_PLOT_STRATUM_ASSGN <- read_pop("POP_PLOT_STRATUM_ASSGN")
  POP_EVAL               <- read_pop("POP_EVAL")
  POP_EVAL_TYP           <- read_pop("POP_EVAL_TYP")

  evt <- POP_EVAL_TYP |>
    inner_join(POP_EVAL |> select(CN, EVALID, END_INVYR, START_INVYR),
               by = c("EVAL_CN" = "CN"))
  cand <- evt |>
    filter(EVAL_TYP %in% c("EXPALL","EXPCURR","EXPVOL")) |>
    arrange(desc(END_INVYR))
  if (!is.null(evalid)) cand <- cand |> filter(EVALID == evalid)
  if (nrow(cand) == 0) stop("No EVALIDs found; cannot proceed.")
  cat(sprintf("  Using %d EVALIDs across EXPALL/EXPCURR/EXPVOL\n",
              length(unique(cand$EVALID))))

  expns_all <- POP_PLOT_STRATUM_ASSGN |>
    filter(EVALID %in% cand$EVALID) |>
    inner_join(POP_STRATUM |>
                 select(CN, EXPNS, P2POINTCNT,
                        ADJ_FACTOR_SUBP, ADJ_FACTOR_MACR),
               by = c("STRATUM_CN" = "CN")) |>
    inner_join(cand |> select(EVALID, END_INVYR, EVAL_TYP),
               by = "EVALID") |>
    mutate(PLT_CN = as.character(PLT_CN))

  expns <- expns_all |>
    group_by(PLT_CN) |>
    slice_max(END_INVYR, n = 1, with_ties = FALSE) |>
    ungroup() |>
    transmute(PLT_CN, EVALID, STRATUM_CN, EXPNS, END_INVYR, EVAL_TYP,
              ADJ_FACTOR_SUBP, ADJ_FACTOR_MACR)

  cat(sprintf("  Got EXPNS for %d unique plots (from %d rows)\n",
              nrow(expns), nrow(expns_all)))
  expns
}

# ----------------------------------------------------------------------------
# 3. SDImax lookup by FORTYPCD
# ----------------------------------------------------------------------------

#' Build a FORTYPCD to SDImax lookup for a state using Woodall & Weiskittel
#' 2021 values. Falls back to the state x ecoregion "Mixed upland hardwoods"
#' SDImax when a specific match is not found.
build_sdimax_lookup <- function(state = "ME",
                                sdimax_csv,
                                fortype_csv,
                                default_ecoregion = "Acadian Plains and Hills") {
  stopifnot(file.exists(sdimax_csv), file.exists(fortype_csv))
  # Map two-letter state code to the STATE name used in Woodall & Weiskittel
  # SDImax CSV (e.g. "ME" -> "Maine").
  state_name <- switch(toupper(state),
                       "ME" = "Maine", "NH" = "New Hampshire", "VT" = "Vermont",
                       "NY" = "New York", "MA" = "Massachusetts",
                       "CT" = "Connecticut", "RI" = "Rhode Island",
                       "PA" = "Pennsylvania",
                       "MN" = "Minnesota", "WA" = "Washington", "GA" = "Georgia",
                       state)  # fallback: use as-is
  sdimax  <- read_csv(sdimax_csv, show_col_types = FALSE) |>
    filter(STATE == state_name)
  fortype <- read_csv(fortype_csv, show_col_types = FALSE) |>
    transmute(FORTYPCD = as.integer(VALUE),
              FORTYP_NAME = MEANING,
              TYPGRPCD = as.integer(TYPGRPCD))

  primary <- sdimax |>
    filter(ECOREGION == default_ecoregion) |>
    select(FORTYP_NAME, SDIMAX_ENGLISH_PRIMARY = SDIMAX_ENGLISH)
  fallback <- sdimax |>
    group_by(FORTYP_NAME) |>
    summarise(SDIMAX_ENGLISH_FALLBACK = mean(SDIMAX_ENGLISH, na.rm = TRUE),
              .groups = "drop")
  global_default <- mean(sdimax$SDIMAX_ENGLISH, na.rm = TRUE)

  lookup <- fortype |>
    left_join(primary,  by = "FORTYP_NAME") |>
    left_join(fallback, by = "FORTYP_NAME") |>
    mutate(SDIMAX_ENGLISH = coalesce(SDIMAX_ENGLISH_PRIMARY,
                                     SDIMAX_ENGLISH_FALLBACK,
                                     global_default)) |>
    select(FORTYPCD, FORTYP_NAME, SDIMAX_ENGLISH)

  cat(sprintf("  SDImax lookup built: %d FORTYPCD rows, %d explicit matches\n",
              nrow(lookup),
              sum(lookup$SDIMAX_ENGLISH != global_default, na.rm = TRUE)))
  lookup
}

# ----------------------------------------------------------------------------
# 4. Core expansion: per-plot -> statewide totals + RD
# ----------------------------------------------------------------------------
expand_to_state <- function(per_plot_file,
                            state             = "ME",
                            fia_dir           = "~/fia_data",
                            config_dir        = "~/fia_cem_projections/config",
                            baseline_year     = NULL,
                            cycle_length_yrs  = 5L,
                            output_prefix     = "state_metrics",
                            scenario_names    = NULL,
                            scenario_lookup   = NULL,
                            new_forest_c_frac = 0.30) {
  # scenario_lookup : optional data.frame with columns {scenario, conversion_rate,
  #   afforest_rate} from get_scenario_set("maine_land_use"). Triggers area
  #   adjustment for forest-to-development conversion and afforestation.
  # new_forest_c_frac : carbon density of newly afforested acres relative to
  #   the average state per-acre stock. Default 0.30 reflects young-stand
  #   density. Set to 1.0 to assume new forest is at average density.

  cat("=== State-Level Metric Expansion ===\n")
  cat(sprintf("Per-plot input: %s\n", per_plot_file))
  stopifnot(file.exists(per_plot_file))

  # FIA state code lookup (two-letter -> STATECD)
  statecd <- switch(toupper(state),
                    "ME" = 23L, "NH" = 33L, "VT" = 50L, "NY" = 36L,
                    "MA" = 25L, "CT" = 9L,  "RI" = 44L, "PA" = 42L,
                    "MN" = 27L, "WA" = 53L, "GA" = 13L,
                    NA_integer_)

  per_plot_raw <- readRDS(per_plot_file) |>
    mutate(PLT_CN = format(PLT_CN, scientific = FALSE, trim = TRUE))

  # Filter to target state only (the pipeline includes donor-state subjects
  # in its projection output but statewide expansion must be single-state)
  if (!is.na(statecd) && "STATECD" %in% names(per_plot_raw)) {
    pre_n <- nrow(per_plot_raw)
    per_plot <- per_plot_raw |> filter(STATECD == statecd)
    cat(sprintf("  Filtered to STATECD == %d (%s): %d -> %d rows\n",
                statecd, state, pre_n, nrow(per_plot)))
  } else {
    per_plot <- per_plot_raw
  }

  # Back-fill scenario column if the pipeline did not write one
  if (!"scenario" %in% names(per_plot) || all(is.na(per_plot$scenario))) {
    cat("  'scenario' column missing; reconstructing from sim ordering...\n")
    boundaries <- which(diff(per_plot$sim) < 0)
    block_id   <- c(1L, 1L + cumsum(seq_along(per_plot$sim[-1]) %in% boundaries))
    if (is.null(scenario_names)) {
      n_blocks <- max(block_id)
      scenario_names <- if (n_blocks == 1) "BAU" else paste0("scenario_", seq_len(n_blocks))
    }
    per_plot$scenario <- scenario_names[block_id]
  }

  # Carbon / biomass / volume: detect per-tree vs per-acre scale for backward
  # compatibility with older RDS files (pre-Fix A).
  carbon_scale <- median(per_plot$proj_carbon, na.rm = TRUE)
  is_per_tree  <- carbon_scale < 1000
  cat(sprintf("Detected proj_carbon scale = %.1f (%s)\n",
              carbon_scale, if (is_per_tree) "per-tree" else "per-acre"))

  per_plot <- per_plot |>
    mutate(
      carbon_lb_per_acre  = if (is_per_tree) proj_carbon * proj_tpa else proj_carbon,
      biomass_lb_per_acre = if (is_per_tree) proj_drybio * proj_tpa else proj_drybio,
      volcf_ft3_per_acre  = if (is_per_tree) proj_volcfnet * proj_tpa else proj_volcfnet,
      volcs_ft3_per_acre  = if ("proj_volcsnet" %in% names(per_plot)) {
                              if (is_per_tree) proj_volcsnet * proj_tpa else proj_volcsnet
                            } else NA_real_
    )

  # ------------------------------------------------------------------------
  # Multi-pool total carbon (Wear & Coulston 2019): total forest C =
  # above-ground live tree + below-ground live tree + standing/down dead +
  # understory (AG + BG) + litter + soil organic C. Live-tree AGL comes
  # from the projection; other pools are joined from COND (held constant
  # from the baseline condition). Below-ground live is approximated as a
  # fixed proportion of above-ground live (Jenkins 2003 component ratios).
  # Dead/litter/soil pools evolve more slowly than the 5-yr cycle so
  # treating them as stationary is a reasonable first-cut assumption.
  # ------------------------------------------------------------------------
  cond_pools_csv <- file.path(fia_dir, paste0(state, "_COND.csv"))
  if (file.exists(cond_pools_csv)) {
    pool_cols <- c("PLT_CN","CONDID","CARBON_DOWN_DEAD","CARBON_LITTER",
                   "CARBON_SOIL_ORG","CARBON_UNDERSTORY_AG","CARBON_UNDERSTORY_BG")
    cond_pools <- data.table::fread(cond_pools_csv, select = pool_cols,
                                    colClasses = list(character = "PLT_CN"),
                                    showProgress = FALSE) |> as_tibble()
    # Average per (PLT_CN, CONDID) across FIA panels so each projected
    # condition gets one value regardless of which INVYR it came from.
    cond_pools <- cond_pools |>
      group_by(PLT_CN, CONDID) |>
      summarise(across(starts_with("CARBON_"), ~ mean(., na.rm = TRUE)),
                .groups = "drop")
    per_plot <- per_plot |> left_join(cond_pools, by = c("PLT_CN","CONDID"))

    bg_ratio <- 0.22   # Jenkins et al. 2003 component ratio (eastern mix)
    # FIA COND pool columns (CARBON_DOWN_DEAD, CARBON_LITTER, CARBON_SOIL_ORG,
    # CARBON_UNDERSTORY_*) are reported in SHORT TONS per acre, whereas TREE
    # CARBON_AG is in POUNDS per tree (then lb/ac after TPA multiplication).
    # Multiply COND pools by 2000 to convert tons -> lb so all per-acre columns
    # share the same lb/acre scale before the final LB_TO_MMT aggregation.
    TON_TO_LB <- 2000
    per_plot <- per_plot |>
      mutate(
        carbon_bg_lb_per_acre        = carbon_lb_per_acre * bg_ratio,
        carbon_down_dead_lb_per_acre = coalesce(CARBON_DOWN_DEAD, 0)     * TON_TO_LB,
        carbon_litter_lb_per_acre    = coalesce(CARBON_LITTER, 0)        * TON_TO_LB,
        carbon_soil_lb_per_acre      = coalesce(CARBON_SOIL_ORG, 0)      * TON_TO_LB,
        carbon_under_ag_lb_per_acre  = coalesce(CARBON_UNDERSTORY_AG, 0) * TON_TO_LB,
        carbon_under_bg_lb_per_acre  = coalesce(CARBON_UNDERSTORY_BG, 0) * TON_TO_LB,
        carbon_total_lb_per_acre =
          carbon_lb_per_acre +              # above-ground live tree
          carbon_bg_lb_per_acre +           # below-ground live tree
          carbon_down_dead_lb_per_acre +    # standing + down dead
          carbon_litter_lb_per_acre +       # forest floor litter
          carbon_soil_lb_per_acre +         # soil organic
          carbon_under_ag_lb_per_acre +     # understory above-ground
          carbon_under_bg_lb_per_acre       # understory below-ground
      )
  } else {
    cat("  WARNING: COND CSV not found; skipping non-AGL pools\n")
    per_plot <- per_plot |>
      mutate(carbon_bg_lb_per_acre        = carbon_lb_per_acre * 0.22,
             carbon_down_dead_lb_per_acre = 0,
             carbon_litter_lb_per_acre    = 0,
             carbon_soil_lb_per_acre      = 0,
             carbon_under_ag_lb_per_acre  = 0,
             carbon_under_bg_lb_per_acre  = 0,
             carbon_total_lb_per_acre     = carbon_lb_per_acre * 1.22)
  }

  # SDI per acre: Reineke SDI = TPA * (QMD/10)^1.605
  per_plot <- per_plot |>
    mutate(sdi_per_acre = if ("proj_qmd" %in% names(per_plot))
                            proj_tpa * (proj_qmd / 10)^REINEKE_EXP else NA_real_)

  # Join EXPNS
  expns <- get_plot_expns(state = state, fia_dir = fia_dir)
  per_plot <- per_plot |> left_join(expns |> select(PLT_CN, EXPNS),
                                    by = "PLT_CN")

  n_missing <- sum(is.na(per_plot$EXPNS))
  if (n_missing > 0) {
    cat(sprintf("  WARNING: %d / %d rows (%.1f%%) missing EXPNS; dropping\n",
                n_missing, nrow(per_plot), 100 * n_missing / nrow(per_plot)))
    per_plot <- per_plot |> filter(!is.na(EXPNS))
  }

  # Join SDImax
  sdimax_csv  <- file.path(config_dir, paste0("sdimax_", tolower(state), ".csv"))
  fortype_csv <- file.path(config_dir, "REF_FOREST_TYPE.csv")
  if (file.exists(sdimax_csv) && file.exists(fortype_csv)) {
    sdimax_lu <- build_sdimax_lookup(state = state,
                                     sdimax_csv  = sdimax_csv,
                                     fortype_csv = fortype_csv)
    per_plot <- per_plot |>
      left_join(sdimax_lu, by = "FORTYPCD") |>
      mutate(rd = sdi_per_acre / SDIMAX_ENGLISH)
  } else {
    warning("SDImax or REF_FOREST_TYPE CSV not found; skipping RD")
    per_plot <- per_plot |> mutate(rd = NA_real_)
  }

  # R-hwpExp: ensure harvested-carbon-by-product columns exist (0 if pre-R-hwpEmit)
  for (.hc in c("harv_c_saw", "harv_c_pulp", "harv_c_residue"))
    if (!.hc %in% names(per_plot)) per_plot[[.hc]] <- 0

  # Per-sim state totals (7 carbon pools + biomass + volumes)
  sim_totals <- per_plot |>
    mutate(
      area_acres        = EXPNS * coalesce(CONDPROP_UNADJ, 1),
      plot_c_lb         = carbon_lb_per_acre              * area_acres,
      plot_c_bg_lb      = carbon_bg_lb_per_acre           * area_acres,
      plot_c_dead_lb    = carbon_down_dead_lb_per_acre    * area_acres,
      plot_c_litter_lb  = carbon_litter_lb_per_acre       * area_acres,
      plot_c_soil_lb    = carbon_soil_lb_per_acre         * area_acres,
      plot_c_under_lb   = (carbon_under_ag_lb_per_acre +
                           carbon_under_bg_lb_per_acre)   * area_acres,
      plot_c_total_lb   = carbon_total_lb_per_acre        * area_acres,
      plot_bio_lb       = biomass_lb_per_acre             * area_acres,
      plot_volcf_ft3    = volcf_ft3_per_acre              * area_acres,
      plot_volcs_ft3    = volcs_ft3_per_acre              * area_acres,
      plot_harv_saw_lb     = coalesce(harv_c_saw, 0)     * area_acres,
      plot_harv_pulp_lb    = coalesce(harv_c_pulp, 0)    * area_acres,
      plot_harv_residue_lb = coalesce(harv_c_residue, 0) * area_acres
    ) |>
    group_by(scenario, sim, cycle) |>
    summarise(
      mmt_agc         = sum(plot_c_lb,        na.rm = TRUE) * LB_TO_MMT,
      mmt_bgc         = sum(plot_c_bg_lb,     na.rm = TRUE) * LB_TO_MMT,
      mmt_dead_c      = sum(plot_c_dead_lb,   na.rm = TRUE) * LB_TO_MMT,
      mmt_litter_c    = sum(plot_c_litter_lb, na.rm = TRUE) * LB_TO_MMT,
      mmt_soil_c      = sum(plot_c_soil_lb,   na.rm = TRUE) * LB_TO_MMT,
      mmt_under_c     = sum(plot_c_under_lb,  na.rm = TRUE) * LB_TO_MMT,
      mmt_total_c     = sum(plot_c_total_lb,  na.rm = TRUE) * LB_TO_MMT,
      mmt_biomass     = sum(plot_bio_lb,      na.rm = TRUE) * LB_TO_MMT,
      total_vol_mcf   = sum(plot_volcf_ft3,   na.rm = TRUE) * FT3_TO_MCF,
      merch_vol_mcf   = sum(plot_volcs_ft3,   na.rm = TRUE) * FT3_TO_MCF,
      mmt_harv_saw     = sum(plot_harv_saw_lb,     na.rm = TRUE) * LB_TO_MMT,   # R-hwpExp
      mmt_harv_pulp    = sum(plot_harv_pulp_lb,    na.rm = TRUE) * LB_TO_MMT,   # R-hwpExp
      mmt_harv_residue = sum(plot_harv_residue_lb, na.rm = TRUE) * LB_TO_MMT,   # R-hwpExp
      rd_mean_wtd     = weighted.mean(rd,           w = area_acres, na.rm = TRUE),
      sdi_mean_wtd    = weighted.mean(sdi_per_acre, w = area_acres, na.rm = TRUE),
      total_area_mha  = sum(area_acres, na.rm = TRUE) * 0.000404686,
      n_conditions    = n(),
      n_harvested     = sum(was_harvested, na.rm = TRUE),
      n_planted       = sum(was_planted,   na.rm = TRUE),
      n_unmatched     = if ("was_unmatched" %in% names(per_plot))
                          sum(was_unmatched, na.rm = TRUE) else 0L,
      .groups         = "drop"
    )

  anchor_year <- baseline_year %||%
                 round(median(per_plot$INVYR[per_plot$cycle == min(per_plot$cycle, na.rm = TRUE)],
                              na.rm = TRUE))
  cat(sprintf("  Anchor year (cycle 0): %d\n", anchor_year))
  sim_totals <- sim_totals |>
    mutate(year = anchor_year + cycle * cycle_length_yrs)

  # R-hwpExp: write WPsCS input (state harvested carbon by product, MMT C)
  if (all(c("mmt_harv_saw", "mmt_harv_pulp", "mmt_harv_residue") %in% names(sim_totals))) {
    hbp <- sim_totals |>
      group_by(scenario, year) |>
      summarise(Sawlog   = mean(mmt_harv_saw,     na.rm = TRUE),
                Pulpwood = mean(mmt_harv_pulp,    na.rm = TRUE),
                Biomass  = mean(mmt_harv_residue, na.rm = TRUE), .groups = "drop") |>
      arrange(scenario, year)
    write_csv(hbp, paste0(output_prefix, "_harvest_by_product.csv"))
    cat(sprintf("  Wrote %s_harvest_by_product.csv (WPsCS HWP input)\n", output_prefix))
  }

  # ------------------------------------------------------------------------
  # Land-use scenario adjustment (maine_land_use scenario_set)
  # Forest-to-development conversion subtracts area linearly each year;
  # afforestation adds new forest acres at reduced C density (default 0.30).
  # Scaling is applied multiplicatively to state-level pools and area.
  # ------------------------------------------------------------------------
  if (!is.null(scenario_lookup)) {
    needed_cols <- c("scenario", "conversion_rate", "afforest_rate")
    if (!all(needed_cols %in% names(scenario_lookup))) {
      warning("scenario_lookup missing required cols; skipping land-use adj")
    } else {
      lu <- scenario_lookup |>
        select(scenario, conversion_rate, afforest_rate) |>
        mutate(conversion_rate = coalesce(conversion_rate, 0),
               afforest_rate   = coalesce(afforest_rate,   0))

      # Baseline forest area (mean across BAU sims at cycle 0)
      base_acres <- sim_totals |>
        filter(scenario == sim_totals$scenario[1], cycle == 0) |>
        pull(total_area_mha) |>
        mean(na.rm = TRUE) / 0.000404686  # back to acres

      cat(sprintf("  Land-use scaling: baseline forest area = %s ac\n",
                  format(round(base_acres), big.mark = ",")))

      sim_totals <- sim_totals |>
        left_join(lu, by = "scenario") |>
        mutate(
          yrs_elapsed     = cycle * cycle_length_yrs,
          conversion_ac   = coalesce(conversion_rate, 0) * yrs_elapsed,
          afforest_ac     = coalesce(afforest_rate,   0) * yrs_elapsed,
          area_factor_pre = (base_acres - conversion_ac) / base_acres,
          area_factor_aff = (afforest_ac * new_forest_c_frac) / base_acres,
          area_factor     = pmax(0, area_factor_pre + area_factor_aff)
        ) |>
        mutate(across(c(mmt_agc, mmt_bgc, mmt_dead_c, mmt_litter_c,
                        mmt_soil_c, mmt_under_c, mmt_total_c,
                        mmt_biomass, total_vol_mcf, merch_vol_mcf,
                        total_area_mha),
                      ~ . * area_factor)) |>
        select(-conversion_rate, -afforest_rate, -yrs_elapsed,
               -conversion_ac, -afforest_ac, -area_factor_pre,
               -area_factor_aff, -area_factor)

      cat("  Applied land-use area scaling to all C pools and area metrics\n")
    }
  }

  # CIs across sims per metric (now includes all 7 C pools)
  ci <- sim_totals |>
    group_by(scenario, cycle, year) |>
    summarise(
      across(c(mmt_agc, mmt_bgc, mmt_dead_c, mmt_litter_c, mmt_soil_c,
               mmt_under_c, mmt_total_c, mmt_biomass,
               total_vol_mcf, merch_vol_mcf,
               rd_mean_wtd, sdi_mean_wtd, total_area_mha),
             list(mean = ~mean(., na.rm = TRUE),
                  lo   = ~quantile(., 0.025, na.rm = TRUE),
                  hi   = ~quantile(., 0.975, na.rm = TRUE)),
             .names = "{.col}_{.fn}"),
      n_sims       = n(),
      n_conditions = round(mean(n_conditions)),
      .groups      = "drop"
    )

  write_csv(sim_totals, paste0(output_prefix, "_sim_totals.csv"))
  write_csv(ci,         paste0(output_prefix, "_ci.csv"))
  cat(sprintf("\n  Wrote %s_{sim_totals,ci}.csv\n", output_prefix))

  summary_long <- ci |>
    select(scenario, cycle, year,
           mmt_agc_mean, mmt_agc_lo, mmt_agc_hi,
           mmt_total_c_mean, mmt_total_c_lo, mmt_total_c_hi,
           mmt_biomass_mean, total_vol_mcf_mean, merch_vol_mcf_mean,
           rd_mean_wtd_mean, n_conditions, n_sims) |>
    mutate(across(where(is.numeric), ~round(., 3)))

  cat("\n=== Summary ===\n")
  print(summary_long, n = Inf)

  invisible(list(sim_totals = sim_totals, ci = ci))
}

# ----------------------------------------------------------------------------
# 5. Observed FIA totals (validation anchor)
# ----------------------------------------------------------------------------

#' Compute observed Maine statewide AGC, biomass, volume from raw FIA.
#' Uses the same per-acre * CONDPROP * EXPNS math but on the raw TREE and
#' COND tables rather than the pipeline's projected output. Produces a
#' single-row tibble with one observed value per metric, suitable as a
#' reference line on figures.
observed_state_totals <- function(state = "ME", fia_dir = "~/fia_data") {

  cat("=== Observed FIA totals (validation reference) ===\n")

  tre <- data.table::fread(file.path(fia_dir, paste0(state, "_TREE.csv")),
                           select = c("PLT_CN","CONDID","STATUSCD","DIA",
                                       "TPA_UNADJ","CARBON_AG","DRYBIO_AG",
                                       "VOLCFNET","VOLCSNET"),
                           colClasses = list(character = "PLT_CN"),
                           showProgress = FALSE) |> as_tibble()
  cnd <- data.table::fread(file.path(fia_dir, paste0(state, "_COND.csv")),
                           select = c("PLT_CN","CONDID","CONDPROP_UNADJ",
                                       "COND_STATUS_CD"),
                           colClasses = list(character = "PLT_CN"),
                           showProgress = FALSE) |> as_tibble()
  ppsa <- data.table::fread(file.path(fia_dir, paste0(state, "_POP_PLOT_STRATUM_ASSGN.csv")),
                            colClasses = list(character = c("PLT_CN","STRATUM_CN")),
                            showProgress = FALSE) |> as_tibble()
  ps <- data.table::fread(file.path(fia_dir, paste0(state, "_POP_STRATUM.csv")),
                          colClasses = list(character = "CN"),
                          showProgress = FALSE) |> as_tibble()
  pe <- data.table::fread(file.path(fia_dir, paste0(state, "_POP_EVAL.csv")),
                          colClasses = list(character = "CN"),
                          showProgress = FALSE) |> as_tibble()
  pet <- data.table::fread(file.path(fia_dir, paste0(state, "_POP_EVAL_TYP.csv")),
                           colClasses = list(character = "EVAL_CN"),
                           showProgress = FALSE) |> as_tibble()

  cond_stats <- tre |>
    filter(STATUSCD == 1, DIA >= 1.0) |>
    group_by(PLT_CN, CONDID) |>
    summarise(
      tpa_live      = sum(TPA_UNADJ, na.rm = TRUE),
      carbon_per_ac = sum(TPA_UNADJ * CARBON_AG,  na.rm = TRUE),
      bio_per_ac    = sum(TPA_UNADJ * DRYBIO_AG,  na.rm = TRUE),
      volcf_per_ac  = sum(TPA_UNADJ * VOLCFNET,   na.rm = TRUE),
      volcs_per_ac  = sum(TPA_UNADJ * coalesce(VOLCSNET, 0), na.rm = TRUE),
      .groups = "drop"
    ) |>
    inner_join(cnd |> filter(COND_STATUS_CD == 1) |>
                 select(PLT_CN, CONDID, CONDPROP_UNADJ),
               by = c("PLT_CN", "CONDID"))

  evt  <- pet |> inner_join(pe |> select(CN, EVALID, END_INVYR),
                            by = c("EVAL_CN" = "CN"))
  pick <- evt |> filter(EVAL_TYP == "EXPALL") |>
    arrange(desc(END_INVYR)) |> slice(1)
  cat(sprintf("  EVALID = %s (END_INVYR = %s)\n", pick$EVALID, pick$END_INVYR))

  expns <- ppsa |>
    filter(EVALID == pick$EVALID) |>
    inner_join(ps |> select(CN, EXPNS), by = c("STRATUM_CN" = "CN")) |>
    distinct(PLT_CN, EXPNS)

  dt <- cond_stats |> inner_join(expns, by = "PLT_CN")

  out <- tibble(
    scenario           = "OBSERVED",
    run                = "observed",
    cycle              = 0L,
    year               = as.integer(pick$END_INVYR),
    mmt_agc_mean       = sum(dt$carbon_per_ac * dt$CONDPROP_UNADJ * dt$EXPNS, na.rm = TRUE) * LB_TO_MMT,
    mmt_biomass_mean   = sum(dt$bio_per_ac    * dt$CONDPROP_UNADJ * dt$EXPNS, na.rm = TRUE) * LB_TO_MMT,
    total_vol_mcf_mean = sum(dt$volcf_per_ac  * dt$CONDPROP_UNADJ * dt$EXPNS, na.rm = TRUE) * FT3_TO_MCF,
    merch_vol_mcf_mean = sum(dt$volcs_per_ac  * dt$CONDPROP_UNADJ * dt$EXPNS, na.rm = TRUE) * FT3_TO_MCF,
    forest_acres_mil   = sum(dt$CONDPROP_UNADJ * dt$EXPNS, na.rm = TRUE) / 1e6,
    n_conditions       = nrow(dt)
  )
  for (v in c("mmt_agc","mmt_biomass","total_vol_mcf","merch_vol_mcf")) {
    out[[paste0(v, "_lo")]] <- out[[paste0(v, "_mean")]]
    out[[paste0(v, "_hi")]] <- out[[paste0(v, "_mean")]]
  }
  cat(sprintf("  MMT AGC obs = %.1f  |  MMT bio obs = %.1f  |  MMcf total = %.0f  |  forested acres = %.1f M\n",
              out$mmt_agc_mean, out$mmt_biomass_mean, out$total_vol_mcf_mean, out$forest_acres_mil))
  out
}

#' Compute observed totals across ALL historical EXPALL EVALIDs.
#' Produces one row per EVALID END_INVYR (e.g. 2004, 2009, 2014, 2019, 2024)
#' for validation of multi-cycle projections like the 1999 baseline.
observed_state_totals_multi <- function(state = "ME", fia_dir = "~/fia_data") {

  cat("=== Observed FIA totals (multiple EVALIDs) ===\n")

  tre  <- data.table::fread(file.path(fia_dir, paste0(state, "_TREE.csv")),
                            select = c("PLT_CN","CONDID","STATUSCD","DIA",
                                        "TPA_UNADJ","CARBON_AG","DRYBIO_AG",
                                        "VOLCFNET","VOLCSNET"),
                            colClasses = list(character = "PLT_CN"),
                            showProgress = FALSE) |> as_tibble()
  cnd  <- data.table::fread(file.path(fia_dir, paste0(state, "_COND.csv")),
                            select = c("PLT_CN","CONDID","CONDPROP_UNADJ",
                                        "COND_STATUS_CD"),
                            colClasses = list(character = "PLT_CN"),
                            showProgress = FALSE) |> as_tibble()
  ppsa <- data.table::fread(file.path(fia_dir, paste0(state, "_POP_PLOT_STRATUM_ASSGN.csv")),
                            colClasses = list(character = c("PLT_CN","STRATUM_CN")),
                            showProgress = FALSE) |> as_tibble()
  ps   <- data.table::fread(file.path(fia_dir, paste0(state, "_POP_STRATUM.csv")),
                            colClasses = list(character = "CN"),
                            showProgress = FALSE) |> as_tibble()
  pe   <- data.table::fread(file.path(fia_dir, paste0(state, "_POP_EVAL.csv")),
                            colClasses = list(character = "CN"),
                            showProgress = FALSE) |> as_tibble()
  pet  <- data.table::fread(file.path(fia_dir, paste0(state, "_POP_EVAL_TYP.csv")),
                            colClasses = list(character = "EVAL_CN"),
                            showProgress = FALSE) |> as_tibble()

  cond_stats <- tre |>
    filter(STATUSCD == 1, DIA >= 1.0) |>
    group_by(PLT_CN, CONDID) |>
    summarise(
      carbon_per_ac = sum(TPA_UNADJ * CARBON_AG,  na.rm = TRUE),
      bio_per_ac    = sum(TPA_UNADJ * DRYBIO_AG,  na.rm = TRUE),
      volcf_per_ac  = sum(TPA_UNADJ * VOLCFNET,   na.rm = TRUE),
      volcs_per_ac  = sum(TPA_UNADJ * coalesce(VOLCSNET, 0), na.rm = TRUE),
      .groups = "drop"
    ) |>
    inner_join(cnd |> filter(COND_STATUS_CD == 1) |>
                 select(PLT_CN, CONDID, CONDPROP_UNADJ),
               by = c("PLT_CN", "CONDID"))

  evt <- pet |> inner_join(pe |> select(CN, EVALID, END_INVYR),
                           by = c("EVAL_CN" = "CN")) |>
    filter(EVAL_TYP == "EXPALL") |>
    arrange(END_INVYR)
  cat(sprintf("  EXPALL EVALIDs found: %d (END_INVYR %d to %d)\n",
              nrow(evt), min(evt$END_INVYR), max(evt$END_INVYR)))

  purrr::map_dfr(seq_len(nrow(evt)), function(i) {
    e <- evt[i, ]
    expns <- ppsa |>
      filter(EVALID == e$EVALID) |>
      inner_join(ps |> select(CN, EXPNS), by = c("STRATUM_CN" = "CN")) |>
      distinct(PLT_CN, EXPNS)
    dt <- cond_stats |> inner_join(expns, by = "PLT_CN")
    tibble(
      scenario = "OBSERVED",
      run      = "observed",
      cycle    = -i,
      year     = as.integer(e$END_INVYR),
      mmt_agc_mean       = sum(dt$carbon_per_ac * dt$CONDPROP_UNADJ * dt$EXPNS, na.rm = TRUE) * LB_TO_MMT,
      mmt_biomass_mean   = sum(dt$bio_per_ac    * dt$CONDPROP_UNADJ * dt$EXPNS, na.rm = TRUE) * LB_TO_MMT,
      total_vol_mcf_mean = sum(dt$volcf_per_ac  * dt$CONDPROP_UNADJ * dt$EXPNS, na.rm = TRUE) * FT3_TO_MCF,
      merch_vol_mcf_mean = sum(dt$volcs_per_ac  * dt$CONDPROP_UNADJ * dt$EXPNS, na.rm = TRUE) * FT3_TO_MCF,
      n_plots  = nrow(expns)
    )
  })
}

# ----------------------------------------------------------------------------
# 6. Legacy wrapper for backward compatibility
# ----------------------------------------------------------------------------
expand_to_state_mmt <- function(per_plot_file, state = "ME",
                                fia_dir = "~/fia_data",
                                baseline_year = NULL,
                                cycle_length_yrs = 5L,
                                output_file = NULL,
                                scenario_names = NULL,
                                scenario_lookup = NULL,
                                new_forest_c_frac = 0.30) {
  out <- expand_to_state(
    per_plot_file     = per_plot_file,
    state             = state,
    fia_dir           = fia_dir,
    baseline_year     = baseline_year,
    output_prefix     = sub("\\.csv$", "", output_file %||% "state_metrics"),
    scenario_names    = scenario_names,
    scenario_lookup   = scenario_lookup,
    new_forest_c_frac = new_forest_c_frac
  )
  invisible(out)
}
