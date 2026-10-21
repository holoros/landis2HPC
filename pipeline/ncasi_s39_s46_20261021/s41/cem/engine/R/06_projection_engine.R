# =============================================================================
# Title: Main Projection Engine
# Author: A. Weiskittel
# Date: 2026-03-19
# Description: Integrates CEM matching, harvest choice, planting, and scenario
#              biasing into a unified projection loop. Implements the Forest
#              Dynamics Model (FDM) approach from Wear & Coulston (2025) using
#              CEM imputation from Van Deusen & Roesch (2013).
# Dependencies: All modules 00-05, 08_climate_interface.R
# =============================================================================

library(tidyverse)

# Source all modules
# source("R/00_config.R")
# source("R/01_data_prep.R")
# source("R/02_cem_matching.R")
# source("R/03_harvest_choice.R")
# source("R/04_planting_model.R")
# source("R/05_scenario_biasing.R")
# source("R/08_climate_interface.R")

# =============================================================================
# Helpers
# =============================================================================

#' Look up the per-plot county harvest probability multiplier (R12).
#' Reads config/maine_county_harvest_calibration.csv once per session
#' (cached on .GlobalEnv$.COUNTY_MULT_LOOKUP). Multiplier =
#' rate_relative_to_statewide capped to [0.3, 2.5] for stability. Returns
#' 1.0 when flag off or lookup missing.
get_county_harvest_mult <- function(projected, cfg) {
  if (!isTRUE(cfg$harvest$use_county_harvest %||% FALSE)) {
    return(rep(1.0, nrow(projected)))
  }
  if (!exists(".COUNTY_MULT_LOOKUP", envir = .GlobalEnv)) {
    cfg_dir <- cfg$paths$config_dir %||% "config"
    cal_csv <- file.path(cfg_dir, "maine_county_harvest_calibration.csv")
    if (!file.exists(cal_csv)) {
      warning(sprintf("use_county_harvest TRUE but %s missing", cal_csv))
      return(rep(1.0, nrow(projected)))
    }
    cal <- read.csv(cal_csv, stringsAsFactors = FALSE)
    cal$STATECD <- 23L
    cal$county_harvest_mult <- pmin(2.5, pmax(0.3,
                                              cal$rate_relative_to_statewide))
    keep <- cal[, c("STATECD", "COUNTYCD", "county_harvest_mult")]
    assign(".COUNTY_MULT_LOOKUP", keep, envir = .GlobalEnv)
    cat(sprintf("  R12 county-mult lookup loaded: %d county rows; range [%.2f, %.2f]\n",
                nrow(keep),
                min(keep$county_harvest_mult), max(keep$county_harvest_mult)))
  }
  lk <- get(".COUNTY_MULT_LOOKUP", envir = .GlobalEnv)
  key <- paste(projected$STATECD, projected$COUNTYCD, sep = "_")
  lkk <- paste(lk$STATECD,        lk$COUNTYCD,        sep = "_")
  m <- lk$county_harvest_mult[match(key, lkk)]
  m[is.na(m)] <- 1.0
  m
}

#' Look up the per-plot HCB owner-class harvest probability multiplier (R14).
#' Reads config/fia_plots_with_owner.csv and config/owner_class_legend.csv
#' once per session (cached on .GlobalEnv$.OWNER_MULT_LOOKUP) and returns a
#' numeric vector aligned to projected. Returns 1.0 for every row when the
#' flag is off or when lookup files are missing.
get_owner_harvest_mult <- function(projected, cfg) {
  if (!isTRUE(cfg$harvest$use_owner_stratification %||% FALSE)) {
    return(rep(1.0, nrow(projected)))
  }
  if (!exists(".OWNER_MULT_LOOKUP", envir = .GlobalEnv)) {
    cfg_dir <- cfg$paths$config_dir %||% "config"
    own_csv <- file.path(cfg_dir, "fia_plots_with_owner.csv")
    leg_csv <- file.path(cfg_dir, "owner_class_legend.csv")
    if (!file.exists(own_csv) || !file.exists(leg_csv)) {
      warning(sprintf("use_owner_stratification TRUE but %s or %s missing",
                      own_csv, leg_csv))
      return(rep(1.0, nrow(projected)))
    }
    own  <- read.csv(own_csv, stringsAsFactors = FALSE)
    leg  <- read.csv(leg_csv, stringsAsFactors = FALSE)
    if (!"harvest_mult" %in% names(leg)) {
      leg$harvest_mult <- c(
        1.0, 0.0, 0.0,                 # 0 unknown, 1 nonforest, 2 water
        0.5, 1.5, 0.2, 0.2, 0.5, 0.3   # 3 NIPF, 4 Corp, 5 Trib, 6 Fed, 7 St, 8 Loc
      )[match(leg$hcb_class, 0:8)]
    }
    keep <- own[, c("STATECD", "COUNTYCD", "PLOT", "hcb_class")]
    keep$owner_harvest_mult <- leg$harvest_mult[match(keep$hcb_class, leg$hcb_class)]
    keep$owner_harvest_mult[is.na(keep$owner_harvest_mult)] <- 1.0

    ## Optional: forest-area-mean mass-balance rescale (R14-bal). Multipliers
    ## are divided by the forest-area mean so that the average plot has
    ## multiplier 1.0 — isolates the spatial redistribution effect from the
    ## net rate reduction. Activated by cfg$harvest$use_owner_balanced.
    if (isTRUE(cfg$harvest$use_owner_balanced %||% FALSE)) {
      forest_mask <- keep$hcb_class %in% 3:8
      fa_mean <- mean(keep$owner_harvest_mult[forest_mask], na.rm = TRUE)
      if (is.finite(fa_mean) && fa_mean > 0) {
        keep$owner_harvest_mult <- keep$owner_harvest_mult / fa_mean
        cat(sprintf("  R14-bal mass-balance rescale: divided multipliers by forest-area mean %.3f\n",
                    fa_mean))
      }
    }
    assign(".OWNER_MULT_LOOKUP", keep, envir = .GlobalEnv)
    cat(sprintf("  R14 owner-mult lookup loaded: %d plot rows; mean mult %.3f\n",
                nrow(keep), mean(keep$owner_harvest_mult)))
  }
  lk <- get(".OWNER_MULT_LOOKUP", envir = .GlobalEnv)
  key <- paste(projected$STATECD, projected$COUNTYCD, projected$PLOT, sep = "_")
  lkk <- paste(lk$STATECD,        lk$COUNTYCD,        lk$PLOT,        sep = "_")
  m <- lk$owner_harvest_mult[match(key, lkk)]
  m[is.na(m)] <- 1.0
  m
}

#' Look up state-varying climate / disturbance / SDImax constants from
#' config/state_constants.csv (see MULTISTATE_PORTABILITY_GAPS.md Section 8
#' step 6). Falls back to Maine values when the state is missing or the CSV
#' is absent so existing ME runs are unaffected. Cached on
#' .GlobalEnv$.STATE_CONSTANTS.
#'
#' @return A 1-row data.frame with: dT_2099_rcp45, dT_2099_rcp85,
#'   fire_baseline_per_cycle, sdimax_default_english, sbw_relevance,
#'   terminal_age.
get_state_constants <- function(cfg) {
  state <- cfg$target_state %||% "ME"
  if (!exists(".STATE_CONSTANTS", envir = .GlobalEnv)) {
    cfg_dir <- cfg$paths$config_dir %||% cfg$config_dir %||% "config"
    sc_csv  <- file.path(cfg_dir, "state_constants.csv")
    if (file.exists(sc_csv)) {
      sc <- read.csv(sc_csv, stringsAsFactors = FALSE)
      assign(".STATE_CONSTANTS", sc, envir = .GlobalEnv)
      cat(sprintf("  state_constants.csv loaded: %d states\n", nrow(sc)))
    } else {
      assign(".STATE_CONSTANTS", NULL, envir = .GlobalEnv)
    }
  }
  sc <- get(".STATE_CONSTANTS", envir = .GlobalEnv)
  ## Hardcoded Maine fallback (matches the pre-externalization values exactly).
  me_default <- data.frame(
    state = "ME", statecd = 23L,
    dT_2099_rcp45 = 2.5, dT_2099_rcp85 = 4.5,
    fire_baseline_per_cycle = 0.005, sdimax_default_english = 440,
    sbw_relevance = "full", terminal_age = 120,
    stringsAsFactors = FALSE
  )
  if (is.null(sc)) {
    if (state != "ME") {
      warning(sprintf("state_constants.csv missing; using ME fallback for %s",
                      state))
    }
    return(me_default)
  }
  row <- sc[sc$state == state, , drop = FALSE]
  if (nrow(row) == 0) {
    warning(sprintf("No state_constants row for '%s'; using ME fallback",
                    state))
    return(me_default)
  }
  row[1, , drop = FALSE]
}

# =============================================================================
# 1. Single Cycle Projection
# =============================================================================

#' Project one FIA measurement cycle forward
#' @param subjects Current subject plot conditions
#' @param remeasured Pool of remeasured donor plot pairs
#' @param scenario Scenario specification (from define_scenario)
#' @param prices Timber prices for this cycle
#' @param climate_data Climate data for this cycle (optional)
#' @param cfg Configuration list
#' @param cycle_num Current cycle number (for tracking)
#' @param sim_id Simulation replicate ID
#' @return List: projected conditions, summary statistics, match quality
project_one_cycle <- function(subjects, remeasured, scenario,
                              prices = NULL, climate_data = NULL,
                              cfg = CONFIG, cycle_num = 1, sim_id = 1) {

  if (is.null(prices)) prices <- cfg$harvest$base_prices

  # Apply price multiplier from scenario
  if (!is.null(scenario$price_mult) && scenario$price_mult != 1.0) {
    prices <- modify_prices(prices, scenario$price_mult)
  }

  # Compute cycle calendar year (baseline_year + cycle_num * cycle_length_yrs).
  # Used by the Maine economic harvest module to look up county-specific real
  # stumpage prices by projection year.
  cycle_year <- (cfg$baseline_year %||% 1999) +
                 cycle_num * (cfg$cycle_length_yrs %||% 5L)

  # If the Maine economic harvest overlay is enabled, replace the generic
  # Wear & Coulston Northeast regional prices with Maine county-level prices
  # for this projection year (weighted average across component species).
  if (isTRUE(cfg$use_maine_econ) && exists("maine_prices_for_year")) {
    mp <- tryCatch(
      maine_prices_for_year(year = cycle_year, county = NULL, cfg = cfg),
      error = function(e) { message("  maine_prices lookup failed: ", e$message); NULL })
    if (!is.null(mp)) {
      # Only overwrite values that are non-NA to avoid wiping prices if a
      # product type has no Maine data for this year.
      for (prod in c("sawtimber","pulpwood")) for (wt in c("softwood","hardwood")) {
        v <- mp[[prod]][[wt]]
        if (!is.null(v) && !is.na(v)) prices[[prod]][[wt]] <- v
      }
      if (cycle_num <= 1 || cycle_num %% 4 == 0) {
        cat(sprintf("  Maine econ prices @ %d: SW saw=$%.0f HW saw=$%.0f SW pulp=$%.1f HW pulp=$%.1f\n",
                    cycle_year, prices$sawtimber$softwood, prices$sawtimber$hardwood,
                    prices$pulpwood$softwood, prices$pulpwood$hardwood))
      }
    }
  }

  # --- Step 1: CEM Matching --------------------------------------------------
  cem_result <- run_cem_matching(subjects, remeasured, cfg)

  # --- Step 2: Determine harvest probability (economic model) ----------------
  if (cfg$harvest$use_economic_model) {
    subjects_econ <- predict_harvest_probability(
      subjects, prices = prices, cfg = cfg
    )
  }

  # --- Step 3: Select matches with scenario biasing --------------------------
  # The biasing operates on the CEM match pool
  selected <- apply_scenario_bias(
    cem_result$all_matches,
    bias_params = scenario,
    seed = cfg$seed + cycle_num * 1000 + sim_id
  )

  # --- Step 4: Build projected conditions ------------------------------------
  # Replace subject conditions with time 2 values from selected donors
  donors <- cem_result$donors

  # Donor's T1 values (unprefixed after 02_cem_matching's rename). We rename
  # them to d_* so we can compute growth rates (T2 / T1) downstream without
  # colliding with subject-side columns.
  donor_t1_cols <- intersect(
    c("carbon_ag","volcfnet","volcsnet","drybio_ag","tpa_live","BA","qmd"),
    names(donors)
  )
  donors_for_join <- donors |>
    rename_with(~ paste0("d_", .), .cols = all_of(donor_t1_cols)) |>
    mutate(d_CONDID = CONDID) |>  # s41 patch: donor condition id (output only)
    select(donor_id,
           starts_with("T2_"),
           starts_with("d_"),
           remper, harvested, starts_with("has_"))

  projected <- selected |>
    left_join(donors_for_join, by = c("donor_idx" = "donor_id"))

  # If economic model is active, override harvest decisions probabilistically
  if (cfg$harvest$use_economic_model) {
    set.seed(cfg$seed + cycle_num * 2000 + sim_id)

    projected <- projected |>
      left_join(
        subjects_econ |>
          select(STATECD, COUNTYCD, PLOT, CONDID,
                 harvest_prob, harvest_prob_adj),
        by = c("STATECD", "COUNTYCD", "PLOT", "CONDID")
      ) |>
      mutate(
        # Blend CEM biasing with economic probability
        harvest_draw = runif(n()),
        econ_harvest = harvest_draw < coalesce(harvest_prob_adj, harvest_prob),
        # Final harvest decision: CEM result or economic model
        final_harvest = harvested | econ_harvest
      )
  } else if (isTRUE(cfg$force_no_harvest)) {
    # Round 1 specification: no harvest for any period.
    projected <- projected |> mutate(final_harvest = FALSE)
  } else if (!is.null(cfg$fixed_harvest_rate)) {
    # Fixed harvest rate scaled by scenario harvest_Q multiplier. At 2% of
    # area per year with 5-yr cycle, base rate = 0.10. Scenario Q values:
    # No_harvest = 0.00 (forces 0), Harvest_m25 = 0.75, BAU = 1.00,
    # Harvest_p25 = 1.25, Harvest_p50 = 1.50. Compatible with
    # --untreated_donors because it does not depend on mean(harvested).
    q_h <- tryCatch(scenario$Q_values$harvested, error = function(e) 1)
    q_h <- if (is.null(q_h) || !is.finite(q_h)) 1 else q_h
    base_target <- pmin(0.95, pmax(0, as.numeric(cfg$fixed_harvest_rate) * q_h))
    set.seed(cfg$seed + cycle_num * 7919 + sim_id)

    # ---- R12 county + R14 HCB owner multipliers (applied per plot) -----
    county_mult <- get_county_harvest_mult(projected, cfg)
    owner_mult  <- get_owner_harvest_mult(projected, cfg)
    projected <- projected |>
      mutate(
        county_harvest_mult = county_mult,
        owner_harvest_mult  = owner_mult,
        target_prob = pmin(0.95, pmax(0, base_target *
                                          county_harvest_mult *
                                          owner_harvest_mult)),
        final_harvest = runif(n()) < target_prob
      ) |>
      select(-county_harvest_mult, -owner_harvest_mult, -target_prob)
    if (cycle_num <= 1) {
      cat(sprintf("  Fixed harvest: base=%.3f * Q=%.2f = %.3f; county-mult mean=%.3f; owner-mult mean=%.3f\n",
                  cfg$fixed_harvest_rate, q_h, base_target,
                  mean(county_mult, na.rm = TRUE),
                  mean(owner_mult, na.rm = TRUE)))
    }
  } else {
    # Without economic harvest model, the scenario harvest_Q directly scales
    # the statewide harvest rate. Base rate = fraction of donors harvested
    # (typically ~11% for Maine). Target rate = base * scenario$Q_values$harvested.
    q_h <- tryCatch(scenario$Q_values$harvested, error = function(e) 1)
    q_h <- if (is.null(q_h) || !is.finite(q_h)) 1 else q_h
    set.seed(cfg$seed + cycle_num * 7919 + sim_id)
    county_mult <- get_county_harvest_mult(projected, cfg)
    owner_mult  <- get_owner_harvest_mult(projected, cfg)
    projected <- projected |>
      mutate(
        base_prob           = mean(harvested, na.rm = TRUE),
        county_harvest_mult = county_mult,
        owner_harvest_mult  = owner_mult,
        target_prob = pmin(0.95, pmax(0, base_prob * q_h *
                                          county_harvest_mult *
                                          owner_harvest_mult)),
        final_harvest = runif(n()) < target_prob
      ) |>
      select(-base_prob, -target_prob,
             -county_harvest_mult, -owner_harvest_mult)
  }

  # --- Step 5: Apply harvest intensity and compute removals ------------------
  harvested_plots <- projected |> filter(final_harvest)

  # If no rows will be harvested in this cycle/scenario (e.g. No_harvest
  # with Q = 0, or force_no_harvest = TRUE), seed the columns the
  # harvested-branch bind_rows mutate requires so they exist as empty
  # vectors. For non-empty harvested_plots, let predict_harvest_intensity
  # and estimate_removals populate them normally.
  if (nrow(harvested_plots) == 0) {
    harvested_plots$harvest_intensity     <- numeric(0)
    harvested_plots$planted               <- logical(0)
    harvested_plots$vol_removed_sawtimber <- numeric(0)
    harvested_plots$vol_removed_pulpwood  <- numeric(0)
    harvested_plots$vol_removed_total     <- numeric(0)
    harvested_plots$rev_sawtimber         <- numeric(0)
    harvested_plots$rev_pulpwood          <- numeric(0)
    # Maine econ overlay: ensure is_clearcut column exists for bind_rows below
    harvested_plots$is_clearcut           <- logical(0)
  }

  if (nrow(harvested_plots) > 0) {
    # Add base-named duplicates of T2_ donor columns so estimate_removals and
    # predict_planting_probability can reference volcfnet, tpa_live, etc.
    # The original T2_* columns are preserved for later growth calculations.
    .t2_cols  <- names(harvested_plots)[startsWith(names(harvested_plots), "T2_")]
    .t2_bases <- sub("^T2_", "", .t2_cols)
    # Preserve subject-side (pre-projection) values as pre_* so downstream
    # growth = T2 - pre logic still works for harvested rows
    .conflict <- intersect(names(harvested_plots), .t2_bases)
    if (length(.conflict) > 0) {
      harvested_plots <- harvested_plots |>
        rename_with(~ paste0("pre_", .), .cols = all_of(.conflict))
    }
    # Copy T2_X to X (keep T2_X intact)
    for (.i in seq_along(.t2_cols)) {
      harvested_plots[[.t2_bases[.i]]] <- harvested_plots[[.t2_cols[.i]]]
    }
    harvested_plots <- predict_harvest_intensity(harvested_plots, cfg$rpa_region)
    # Override intensity if the run spec pins a fixed value (e.g. 0.50 for
    # the "2% area * 50% biomass" round-2 harvest regime).
    if (!is.null(cfg$fixed_harvest_intensity)) {
      harvested_plots$harvest_intensity <- as.numeric(cfg$fixed_harvest_intensity)
    }
    # Maine partial-vs-clearcut split (Wear 2019 + SAR 2015-2023). Assigns
    # is_clearcut per plot based on its county's observed clearcut share.
    # Clearcuts remove ~95% of standing biomass and reset STDAGE to 0; partial
    # harvests retain the predicted intensity and apply a 40-yr age setback.
    if (isTRUE(cfg$use_maine_econ) && exists("split_partial_clearcut")) {
      harvested_plots <- split_partial_clearcut(
        harvested_plots, cfg, cycle_year,
        seed = cfg$seed + cycle_num * 11 + sim_id)
      # Clearcut plots: force intensity near 1.0 to reflect stand reset
      if ("is_clearcut" %in% names(harvested_plots)) {
        cc_mask <- harvested_plots$is_clearcut
        harvested_plots$harvest_intensity[cc_mask] <- 0.95
        if (cycle_num <= 1 || cycle_num %% 4 == 0) {
          cat(sprintf("  Maine harvest split @ cycle %d: n_partial=%d n_clearcut=%d (share=%.2f)\n",
                      cycle_num, sum(!cc_mask), sum(cc_mask),
                      sum(cc_mask) / max(1, length(cc_mask))))
        }
      }
    } else {
      # Default: no split, treat all harvests as partial
      harvested_plots$is_clearcut <- FALSE
    }
    harvested_plots <- estimate_removals(harvested_plots, prices)
    # Derive per-acre revenue streams used by the planting model
    harvested_plots <- harvested_plots |>
      mutate(
        rev_sawtimber = coalesce(vol_removed_sawtimber, 0) *
                          coalesce(prices$sawtimber$softwood, 250),
        rev_pulpwood  = coalesce(vol_removed_pulpwood, 0) *
                          coalesce(prices$pulpwood$softwood, 12)
      )
  }

  # --- Step 6: Apply planting decisions to harvested plots -------------------
  if (cfg$planting$model_planting && nrow(harvested_plots) > 0) {
    harvested_plots <- predict_planting_probability(
      harvested_plots, prices, cfg
    )
    harvested_plots <- apply_planting_decision(
      harvested_plots, seed = cfg$seed + cycle_num * 3000 + sim_id
    )
  }

  # --- Step 7: Assemble projected inventory ----------------------------------
  # Non-harvested plots get time 2 values directly.
  not_harvested <- projected |>
    filter(!final_harvest)

  # Unmatched subjects (CEM could not find any donor at any coarsening level).
  # Carry these forward with their T1 values so they are NOT dropped from the
  # state total or the next cycle's subject pool. This prevents the cascading
  # attrition bug where n_conditions shrinks 3 to 4x per cycle.
  unmatched <- cem_result$unmatched

  # -- Climate-scenario multiplier (HadGEM2-AO RCP 4.5 / 8.5) ---------------
  # Computes a time-varying growth multiplier and disturbance weighting
  # based on cumulative warming from 1999 to the projected year for the
  # selected RCP. Per-state warming targets come from config/state_constants.csv
  # (see MULTISTATE_PORTABILITY_GAPS.md Section 8 step 6); ME values match the
  # original HadGEM2-AO downscaled projections (MACA/ClimateNA).
  state_const <- get_state_constants(cfg)
  climate_mult <- 1.0   # default: no climate effect
  fire_climate_mult   <- 1.0
  insect_climate_mult <- 1.0
  if (!is.null(cfg$climate_rcp)) {
    rcp <- as.numeric(cfg$climate_rcp)
    # Warming at 2099 for the target state under each RCP.
    dT_2099 <- switch(as.character(rcp),
                       "4.5" = state_const$dT_2099_rcp45,
                       "8.5" = state_const$dT_2099_rcp85,
                       0)
    # Linear ramp from baseline to 2099
    years_elapsed <- (cycle_num) * (cfg$cycle_length_yrs %||% 5L)
    t_frac <- pmin(1.0, years_elapsed / 100)
    dT <- dT_2099 * t_frac

    # -- Decoupled climate factors (R8) -------------------------------------
    # Split the legacy lumped climate_mult into separable temperature and CO2
    # components. Default behavior (use_decoupled_climate = NULL or FALSE)
    # preserves the legacy combined multiplier for backward compatibility.
    if (isTRUE(cfg$use_decoupled_climate)) {
      # Temperature-only effect: empirical Maine forest growth response per
      # degree C warming, accounting for drought/heat-stress saturation.
      temp_mult <- if (rcp == 4.5) 1 + 0.010 * dT
                   else             1 + 0.010 * dT - 0.003 * pmax(0, dT - 3)^2

      # CO2 fertilization: log-linear in atmospheric concentration following
      # Norby et al. 2010 FACE meta-analysis (~0.10 per doubling CO2 for
      # northern temperate hardwood-conifer forests).
      # CO2 trajectories (ppm): RCP 4.5 plateaus near 540, RCP 8.5 climbs to ~940.
      co2_baseline <- 370   # year 2000 baseline
      co2_2099     <- if (rcp == 4.5) 538 else 936
      co2_year     <- co2_baseline + (co2_2099 - co2_baseline) * t_frac
      co2_beta     <- cfg$co2_effect_mult %||% 0.10  # per doubling CO2
      co2_mult     <- 1 + co2_beta * log2(co2_year / co2_baseline)

      climate_mult <- temp_mult * co2_mult
      if (cycle_num <= 1 || cycle_num %% 4 == 0) {
        cat(sprintf("  Climate decoupled RCP %.1f cycle %d: dT=%.2f temp_mult=%.3f CO2=%.0f ppm co2_mult=%.3f -> climate_mult=%.3f\n",
                    rcp, cycle_num, dT, temp_mult, co2_year, co2_mult, climate_mult))
      }
    } else {
      # Legacy combined multiplier (RCP 4.5: +1.5% per C; RCP 8.5: bends past 3C)
      climate_mult <- if (rcp == 4.5) 1 + 0.015 * dT
                      else             1 + 0.015 * dT - 0.003 * pmax(0, dT - 3)^2
      if (cycle_num <= 1 || cycle_num %% 4 == 0) {
        cat(sprintf("  Climate RCP %.1f @ cycle %d (year+%d): dT=%.2f, gr_mult=%.3f\n",
                    rcp, cycle_num, years_elapsed, dT, climate_mult))
      }
    }

    # Disturbance sensitivity (fire +10 percent per C, insect +5 percent per C)
    fire_climate_mult   <- 1 + 0.10 * dT
    insect_climate_mult <- 1 + 0.05 * dT
  }

  # -- Species-specific climate response coefficients (R4) ------------------
  # When --use_potter_vcc is set, climate sensitivity (beta_per_C) comes from
  # Potter et al. 2017 CAPTURE framework via spcd_potter_vcc.csv lookup. The
  # per-plot coefficient is the SPCD-weighted average using FIA dom_spcd as
  # a single-species proxy (extension to weighted basal-area composition is
  # straightforward but requires per-tree data not in projection output).
  #
  # Otherwise (default), use coarser FORTYPCD-based coefficients drawn from
  # D'Amato et al. 2011 (Maine spruce-fir/northern hardwood), Iverson et al.
  # 2008, and Janowiak et al. 2018.
  fortypcd_climate_beta <- function(fortypcd) {
    sf  <- c(121L, 122L, 123L, 124L, 125L, 126L)               # spruce-fir
    swp <- c(101L, 102L, 103L, 104L, 105L, 127L, 128L)         # softwood pine/cedar/hemlock
    nh  <- c(701L, 801L, 802L, 803L, 805L, 809L)               # northern hardwood
    oak <- c(381L, 501L, 502L, 503L, 505L, 509L, 513L, 519L)   # oak
    asp <- c(901L, 902L, 903L, 904L, 905L, 707L)               # aspen/birch
    rm  <- c(702L, 705L, 708L, 802L)                            # red maple, lowland hardwood
    dplyr::case_when(
      fortypcd %in% sf  ~ -0.025,
      fortypcd %in% swp ~ -0.005,
      fortypcd %in% nh  ~  0.000,
      fortypcd %in% oak ~  0.025,
      fortypcd %in% asp ~  0.005,
      fortypcd %in% rm  ~  0.020,
      TRUE              ~  0.010
    )
  }

  # SPCD-level Potter VCC lookup (loaded once if --use_potter_vcc set)
  potter_vcc_lookup <- NULL
  if (isTRUE(cfg$use_potter_vcc)) {
    vcc_csv <- file.path(cfg$config_dir %||% "config", "spcd_potter_vcc.csv")
    if (file.exists(vcc_csv)) {
      potter_vcc_lookup <- data.table::fread(vcc_csv,
        select = c("SPCD","beta_per_C","potter_VCC_score","potter_cluster"))
      cat(sprintf("  Potter VCC lookup loaded: %d species\n", nrow(potter_vcc_lookup)))
    } else {
      cat("  Potter VCC requested but spcd_potter_vcc.csv not found; using FORTYPCD fallback\n")
    }
  }

  # Applied per-plot; produces a multiplier in addition to the global climate_mult.
  apply_species_climate <- function(df, dT) {
    if (!isTRUE(cfg$use_species_climate) && !isTRUE(cfg$use_potter_vcc)) return(df)
    if (is.null(dT) || !is.numeric(dT) || dT == 0) return(df)
    if (isTRUE(cfg$use_potter_vcc) && !is.null(potter_vcc_lookup) && "dom_spcd" %in% names(df)) {
      # Potter VCC: SPCD-resolved beta from Potter 2017 CAPTURE framework
      df <- df |>
        dplyr::left_join(as.data.frame(potter_vcc_lookup) |>
                          dplyr::select(SPCD, beta_per_C),
                          by = c("dom_spcd" = "SPCD")) |>
        dplyr::mutate(
          sp_clim_beta = dplyr::coalesce(beta_per_C, fortypcd_climate_beta(FORTYPCD)),
          sp_clim_mult = 1 + sp_clim_beta * dT,
          proj_BA       = proj_BA       * sp_clim_mult,
          proj_volcfnet = proj_volcfnet * sp_clim_mult,
          proj_volcsnet = if ("proj_volcsnet" %in% names(df)) proj_volcsnet * sp_clim_mult else proj_volcsnet,
          proj_drybio   = proj_drybio   * sp_clim_mult,
          proj_carbon   = proj_carbon   * sp_clim_mult
        ) |>
        dplyr::select(-beta_per_C, -sp_clim_beta, -sp_clim_mult)
      if (cycle_num <= 1) {
        cat(sprintf("  Potter VCC species climate applied @ dT=%.2f\n", dT))
      }
    } else {
      # Fallback to FORTYPCD-coarse coefficients
      df <- df |>
        dplyr::mutate(
          sp_clim_beta = fortypcd_climate_beta(FORTYPCD),
          sp_clim_mult = 1 + sp_clim_beta * dT,
          proj_BA       = proj_BA       * sp_clim_mult,
          proj_volcfnet = proj_volcfnet * sp_clim_mult,
          proj_volcsnet = if ("proj_volcsnet" %in% names(df)) proj_volcsnet * sp_clim_mult else proj_volcsnet,
          proj_drybio   = proj_drybio   * sp_clim_mult,
          proj_carbon   = proj_carbon   * sp_clim_mult
        ) |>
        dplyr::select(-sp_clim_beta, -sp_clim_mult)
      if (cycle_num <= 1) {
        cat(sprintf("  FORTYPCD species climate applied @ dT=%.2f\n", dT))
      }
    }
    df
  }
  if (!exists("dT")) dT <- 0  # safety for non-climate runs

  # -- Episodic disturbance module (R6) -------------------------------------
  # Models climate-modulated stochastic disturbance. Three event types:
  #   spruce_budworm: 30-year cycle peak; high impact on spruce-fir forests,
  #                   low elsewhere. Last major outbreak 1970s-80s; next
  #                   peak modeled around 2030-2040 with climate amplification.
  #   windstorm:      2 to 5 percent area per decade, climate-amplified, all
  #                   forest types affected; partial-canopy mortality.
  #   wildfire:       Maine baseline 0.1% per year, climate-amplified per RCP.
  # Each plot is drawn for each event type per cycle. Affected plots receive
  # biomass and BA reductions matching observed FIA disturbance code response.
  apply_disturbance <- function(df, cycle_num, sim_id) {
    if (!isTRUE(cfg$use_disturbance)) return(df)

    set.seed(cfg$seed + cycle_num * 1373 + sim_id * 7)
    n <- nrow(df)
    if (n == 0) return(df)

    # --- Spruce budworm (30-yr cycle, climate-amplified) ---
    # Phase peaks 2030-2040 (last outbreak ~1975 plus 30 yr + 25 yr lag).
    proj_year <- (cfg$baseline_year %||% 1999) +
                  cycle_num * (cfg$cycle_length_yrs %||% 5L)
    sbw_phase <- 0.5 + 0.5 * cos(2 * pi * (proj_year - 2035) / 30)  # peaks 2035, 2065
    sbw_amp   <- (cfg$insect_amp_mult %||% 1.0) * insect_climate_mult
    is_spruce_fir <- df$FORTYPCD %in% c(121L, 122L, 123L, 124L, 125L, 126L)
    sbw_p_per_cycle <- ifelse(is_spruce_fir, 0.20 * sbw_phase * sbw_amp,
                              0.02 * sbw_phase * sbw_amp)
    sbw_hit <- runif(n) < pmin(sbw_p_per_cycle, 0.85)

    # --- Wind / blowdown (2-5% per decade) ---
    wind_p_per_cycle <- 0.025 * (cfg$wind_amp_mult %||% 1.0)
    wind_hit <- runif(n) < wind_p_per_cycle

    # --- Wildfire (per-state baseline, climate-amplified) ---
    # Baseline reads from state_constants.csv. ME 0.005/cycle (~0.1%/yr);
    # WA ~0.06/cycle (10x ME); GA ~0.04/cycle; MN ~0.01/cycle.
    fire_baseline <- state_const$fire_baseline_per_cycle %||% 0.005
    fire_p_per_cycle <- fire_baseline * fire_climate_mult *
                        (cfg$fire_amp_mult %||% 1.0)
    fire_hit <- runif(n) < fire_p_per_cycle

    # Apply per-plot reductions:
    #   sbw: 30% biomass mortality on softwood, 5% on hardwood
    #   wind: 20% partial canopy loss on affected plots
    #   fire: 60% biomass mortality
    sbw_red  <- ifelse(is_spruce_fir & sbw_hit,  0.70, 1.0)  # retain 70%
    wind_red <- ifelse(wind_hit, 0.80, 1.0)  # retain 80%
    fire_red <- ifelse(fire_hit, 0.40, 1.0)  # retain 40%
    total_red <- sbw_red * wind_red * fire_red

    df <- df |>
      dplyr::mutate(
        proj_BA       = proj_BA       * total_red,
        proj_volcfnet = proj_volcfnet * total_red,
        proj_volcsnet = if ("proj_volcsnet" %in% names(df)) proj_volcsnet * total_red else proj_volcsnet,
        proj_drybio   = proj_drybio   * total_red,
        proj_carbon   = proj_carbon   * total_red,
        was_disturbed_sbw  = sbw_hit,
        was_disturbed_wind = wind_hit,
        was_disturbed_fire = fire_hit
      )
    if (cycle_num <= 1 || cycle_num %% 4 == 0) {
      cat(sprintf("  Disturbance @ cycle %d (year %d): SBW phase=%.2f, %d sbw / %d wind / %d fire\n",
                  cycle_num, proj_year, sbw_phase,
                  sum(sbw_hit), sum(wind_hit), sum(fire_hit)))
    }
    df
  }

  # -- Age-class saturation (Wear & Coulston 2019) --------------------------
  # Forest stands approach a terminal age at which net growth approaches zero
  # (carrying-capacity saturation). Without this correction, compounding
  # growth-rate multipliers under RCP 8.5 cause mature stands to project
  # unboundedly. We apply a linear ramp from full growth at age <=60 down to
  # zero at the terminal age (120 for Maine northern hardwood-conifer mixes).
  # Both growth-rate departures and the climate multiplier are attenuated
  # by the same saturation factor.
  terminal_age     <- cfg$terminal_age     %||% state_const$terminal_age %||% 120  # R-stateTerm: per-state terminal age (GA 80, WA 200, MN 110); ME 120 unchanged
  growth_start_age <- cfg$growth_start_age %||% 60
  # R-plantTerm: optional stand-origin-aware rotation age. Planted stands
  # (STDORGCD==1) use a shorter terminal/rotation age so plantation carbon does
  # not over-accumulate toward the natural terminal age. NULL -> unchanged.
  plant_term   <- cfg$plantation_terminal_age
  plant_gstart <- cfg$plantation_growth_start %||% 15
  .row_term <- function(stdorg) if (is.null(plant_term)) rep(terminal_age, length(stdorg)) else dplyr::if_else(dplyr::coalesce(stdorg, 0L) == 1L, as.numeric(plant_term), as.numeric(terminal_age))
  .row_gstart <- function(stdorg) if (is.null(plant_term)) rep(growth_start_age, length(stdorg)) else dplyr::if_else(dplyr::coalesce(stdorg, 0L) == 1L, as.numeric(plant_gstart), as.numeric(growth_start_age))
  sat_for_age <- function(age, term = terminal_age, gstart = growth_start_age) {
    term  <- pmax(term, gstart + 5)
    age   <- pmin(pmax(coalesce(age, 0), 0), term)
    pmax(0, pmin(1, (term - age) / (term - gstart)))
  }

  # -- BRMS Reineke SDImax cap (R5) -----------------------------------------
  # If --use_brms_sdimax is set, load plot- and FORTYPCD-level SDImax lookups
  # and cap projected growth so that proj_SDI does not exceed plot-specific
  # SDImax. Lookup priority: PLT_CN-level (BRMS plot posterior mean) >
  # COUNTY x FORTYPCD aggregated > STATE x FORTYPCD aggregated >
  # global Maine mean (~440 trees/acre, ~1080 trees/ha).
  REINEKE_EXP <- 1.605
  brms_lookup <- NULL
  fortyp_state_lookup <- NULL
  if (isTRUE(cfg$use_brms_sdimax)) {
    plot_csv <- file.path(cfg$config_dir %||% "config", "sdimax_brms_plot.csv")
    state_csv <- file.path(cfg$config_dir %||% "config", "sdimax_brms_fortyp.csv")
    if (file.exists(plot_csv) && file.exists(state_csv)) {
      brms_lookup <- data.table::fread(plot_csv, select = c("PLT_CN","sdimax_english_mean"),
                                        colClasses = list(character = "PLT_CN"))
      data.table::setnames(brms_lookup, "sdimax_english_mean", "sdimax_eng_plot")
      fortyp_state_lookup <- data.table::fread(state_csv,
                                                select = c("STATECD","FORTYPCD","sdimax_english_mean"))
      data.table::setnames(fortyp_state_lookup, "sdimax_english_mean", "sdimax_eng_fortyp")
      cat(sprintf("  BRMS SDImax cap enabled: %d plots, %d state-FORTYPCD entries\n",
                  nrow(brms_lookup), nrow(fortyp_state_lookup)))
    } else {
      cat("  BRMS SDImax cap disabled: lookup CSVs not found\n")
    }
  }
  GLOBAL_SDIMAX_DEFAULT_ENG <- state_const$sdimax_default_english %||% 440
  # Per-state SDImax fallback (English: trees per acre). Used when neither
  # the BRMS plot lookup nor the state x FORTYPCD lookup hits. ME 440;
  # MN 330; WA 510 (Doug-fir / hemlock-Sitka); GA 360.

  # -- v4 productivity multiplier (Phase 2 yield curve archive) -------------
  # When --use_v4_prod_mult is set, load FIA empirical asymptote multipliers
  # from cem_productivity_multipliers_v4.csv keyed by (forest type x
  # ecoregion x owner), join via yc_plot_membership.csv, and apply a
  # per-cycle scalar prod_mult^(strength / N_CYCLES_TOTAL) to BA, volume,
  # drybio, and carbon. With strength=1 the cumulative effect over 30
  # cycles equals prod_mult; the multiplier is applied BEFORE the SDImax
  # cap so over-capped strata still get bounded.
  v4_mult_lookup <- NULL
  N_CYCLES_TOTAL <- 30
  if (isTRUE(cfg$use_v4_prod_mult)) {
    cdir <- cfg$config_dir %||% "config"
    v4_csv <- file.path(cdir, "cem_productivity_multipliers_v4.csv")
    yc_csv <- file.path(cdir, "yc_plot_membership.csv")
    if (file.exists(v4_csv) && file.exists(yc_csv)) {
      v4_tab <- read.csv(v4_csv, stringsAsFactors = FALSE)
      v4_unt <- v4_tab[v4_tab$treatment == "untreated",
                        c("cell_key", "prod_mult")]
      pmem <- read.csv(yc_csv, stringsAsFactors = FALSE,
                        colClasses = c("PLT_CN" = "character"))
      v4_mult_lookup <- merge(pmem[, c("PLT_CN", "cell_key")], v4_unt,
                               by = "cell_key", all.x = TRUE)
      v4_mult_lookup$prod_mult[is.na(v4_mult_lookup$prod_mult)] <- 1.0
      strength <- if (!is.null(cfg$v4_prod_mult_strength))
        cfg$v4_prod_mult_strength else 1.0
      v4_mult_lookup$prod_mult_per_cycle <-
        v4_mult_lookup$prod_mult^(strength / N_CYCLES_TOTAL)
      cat(sprintf("  v4 productivity multiplier loaded: %d plots; per-cycle range [%.4f, %.4f] mean %.4f\n",
                   nrow(v4_mult_lookup),
                   min(v4_mult_lookup$prod_mult_per_cycle),
                   max(v4_mult_lookup$prod_mult_per_cycle),
                   mean(v4_mult_lookup$prod_mult_per_cycle)))
    } else {
      cat("  v4 productivity multiplier flag set but lookup CSVs missing; skipping\n")
    }
  }
  apply_v4_prod_mult <- function(df) {
    if (is.null(v4_mult_lookup)) return(df)
    df <- df |>
      dplyr::mutate(PLT_CN_chr = format(PLT_CN, scientific = FALSE, trim = TRUE)) |>
      dplyr::left_join(v4_mult_lookup[, c("PLT_CN", "prod_mult_per_cycle")],
                        by = c("PLT_CN_chr" = "PLT_CN")) |>
      dplyr::mutate(
        prod_mult_per_cycle = ifelse(is.na(prod_mult_per_cycle), 1.0,
                                       prod_mult_per_cycle),
        proj_BA       = proj_BA       * prod_mult_per_cycle,
        proj_volcfnet = proj_volcfnet * prod_mult_per_cycle,
        proj_volcsnet = if ("proj_volcsnet" %in% names(df))
                          proj_volcsnet * prod_mult_per_cycle else proj_volcsnet,
        proj_drybio   = proj_drybio   * prod_mult_per_cycle,
        proj_carbon   = proj_carbon   * prod_mult_per_cycle
      ) |>
      dplyr::select(-PLT_CN_chr, -prod_mult_per_cycle)
    df
  }

  apply_sdimax_cap <- function(df) {
    if (is.null(brms_lookup) && is.null(fortyp_state_lookup)) return(df)
    df <- df |>
      dplyr::mutate(PLT_CN_chr = format(PLT_CN, scientific = FALSE, trim = TRUE)) |>
      dplyr::left_join(as.data.frame(brms_lookup), by = c("PLT_CN_chr" = "PLT_CN")) |>
      dplyr::left_join(as.data.frame(fortyp_state_lookup), by = c("STATECD","FORTYPCD")) |>
      dplyr::mutate(
        sdimax_eng = dplyr::coalesce(
          # sdiGuard fix (20260608): accept plot/fortyp SDImax only within a sane
          # imperial band [150, 800] trees/acre; else fall through to the default.
          dplyr::if_else(dplyr::between(sdimax_eng_plot,   150, 800), sdimax_eng_plot,   NA_real_),
          dplyr::if_else(dplyr::between(sdimax_eng_fortyp, 150, 800), sdimax_eng_fortyp, NA_real_),
          GLOBAL_SDIMAX_DEFAULT_ENG),
        proj_sdi   = proj_tpa * (proj_qmd / 10)^REINEKE_EXP,
        sdi_ratio  = pmin(1, sdimax_eng / pmax(0.1, proj_sdi)),
        # Apply ratio to BA and biomass-related columns
        proj_BA       = proj_BA       * sdi_ratio,
        proj_volcfnet = proj_volcfnet * sdi_ratio,
        proj_volcsnet = if ("proj_volcsnet" %in% names(df)) proj_volcsnet * sdi_ratio else proj_volcsnet,
        proj_drybio   = proj_drybio   * sdi_ratio,
        proj_carbon   = proj_carbon   * sdi_ratio,
        # tpaSat fix (20260606): bind the SDImax cap on tree count too, so
        # proj_tpa stays on the Reineke line and TPA/BA/QMD stay consistent.
        # QMD is held; TPA and BA both scale by sdi_ratio.
        proj_tpa      = proj_tpa      * sdi_ratio,
        # qmdRecon fix (20260606): derive QMD from the capped BA and TPA so
        # BA = TPA * 0.005454 * QMD^2 holds exactly (closes the BA/QMD decoupling).
        proj_qmd      = dplyr::if_else(proj_tpa > 0,
                                       sqrt(proj_BA / (proj_tpa * 0.005454)),
                                       proj_qmd)
      ) |>
      dplyr::select(-PLT_CN_chr, -sdimax_eng_plot, -sdimax_eng_fortyp,
                    -sdimax_eng, -proj_sdi, -sdi_ratio)
    df
  }

  # Combine (both branches reference T2_ columns, which remain intact).
  # Add pre_* aliases for the subject-side pre-projection values so the
  # cycle_summary growth calc can subtract pre_ from T2_ uniformly across
  # harvested and non-harvested rows.
  all_projected <- bind_rows(
    not_harvested |> mutate(
      pre_volcfnet  = volcfnet,
      pre_volcsnet  = if ("volcsnet" %in% names(not_harvested)) volcsnet else NA_real_,
      pre_BA        = BA,
      pre_drybio_ag = drybio_ag,
      pre_carbon_ag = carbon_ag,
      pre_tpa_live  = tpa_live,
      pre_qmd       = qmd,
      # Age-class saturation (Wear 2019): unity for stands <=60 yr, decays
      # linearly to zero at terminal_age (120). Used to attenuate both donor
      # growth-rate departures and the climate multiplier in mature stands.
      .sat_age     = sat_for_age(STDAGE, .row_term(STDORGCD), .row_gstart(STDORGCD)),  # R-plantTerm
      # Growth rates from donor (T2 / T1), capped to [0.5, 2.0] per 5yr cycle
      # so extreme donor ratios do not dominate. Saturation ramps the
      # departure from 1.0 rather than the raw multiplier itself, so under
      # overmature conditions the effective rate collapses toward 1.0 (zero
      # growth) rather than toward 0 (stand removal).
      gr_BA        = 1 + (pmin(pmax(if_else(d_BA > 0,        T2_BA / d_BA, 1.0),        0.5), 2.0) - 1) * .sat_age,
      gr_volcfnet  = 1 + (pmin(pmax(if_else(d_volcfnet > 0,  T2_volcfnet / d_volcfnet,  1.0), 0.5), 2.0) - 1) * .sat_age,
      gr_volcsnet  = if ("d_volcsnet" %in% names(not_harvested) & "T2_volcsnet" %in% names(not_harvested))
                        1 + (pmin(pmax(if_else(d_volcsnet > 0, T2_volcsnet / d_volcsnet, 1.0), 0.5), 2.0) - 1) * .sat_age
                       else 1.0,
      gr_drybio    = 1 + (pmin(pmax(if_else(d_drybio_ag > 0, T2_drybio_ag / d_drybio_ag, 1.0), 0.5), 2.0) - 1) * .sat_age,
      gr_carbon    = 1 + (pmin(pmax(if_else(d_carbon_ag > 0, T2_carbon_ag / d_carbon_ag, 1.0), 0.5), 2.0) - 1) * .sat_age,
      gr_tpa       = 1 + (pmin(pmax(if_else(d_tpa_live > 0,  T2_tpa_live / d_tpa_live, 1.0),  0.5), 2.0) - 1) * .sat_age,
      gr_qmd       = pmin(pmax(if_else(d_qmd > 0,       T2_qmd / d_qmd, 1.0),       0.7), 1.5),
      # Climate multiplier similarly attenuated to avoid compounding in
      # mature stands under warming scenarios.
      .cm          = 1 + (climate_mult - 1) * .sat_age,
      .anchor_pc    = if (isTRUE(getOption("cem.asym_anchor", FALSE))) {   # R-asymAnchor
                        .ar <- (coalesce(asym_agb, donor_asym) / pmax(coalesce(donor_asym, asym_agb), 1e-6))^(as.numeric(getOption("cem.asym_anchor_strength", 1)) / max(cfg$n_cycles, 1L))
                        .ar[is.na(.ar)] <- 1; pmin(pmax(.ar, 0.90), 1.12)
                      } else 1,
      # Apply donor growth rate to subject's own level, times climate multiplier
      proj_BA       = BA * gr_BA * .cm * .anchor_pc,
      proj_volcfnet = volcfnet * gr_volcfnet * .cm * .anchor_pc,
      proj_volcsnet = if ("volcsnet" %in% names(not_harvested)) volcsnet * gr_volcsnet * .cm * .anchor_pc else NA_real_,
      proj_drybio   = drybio_ag * gr_drybio * .cm * .anchor_pc,
      proj_carbon   = carbon_ag * gr_carbon * .cm * .anchor_pc,
      proj_tpa      = tpa_live * gr_tpa,
      proj_qmd      = qmd * gr_qmd,
      harv_c_total = 0, harv_c_saw = 0, harv_c_pulp = 0, harv_c_residue = 0,   # R-hwpEmit
      cycle         = cycle_num,
      sim           = sim_id,
      was_harvested = FALSE,
      was_planted   = FALSE,
      was_unmatched = FALSE
    ) |> select(-.sat_age, -.cm, -.anchor_pc),
    harvested_plots |> mutate(
      # Harvested: growth rate applied, then reduced by harvest intensity.
      # Age setback differs by cut type (Wear 2019 Table 2):
      # - partial: effective stand age = STDAGE - 40 (regrowth envelope open)
      # - clearcut: effective stand age = 0 (stand fully reset; full growth
      #   envelope plus new-stand dynamics implicit in the ~95% intensity).
      # If the is_clearcut column is absent (Maine econ overlay disabled),
      # fall back to partial treatment for backward compatibility.
      .is_cc       = coalesce(is_clearcut, FALSE),
      .sat_age     = if_else(.is_cc, sat_for_age(0, .row_term(STDORGCD), .row_gstart(STDORGCD)), sat_for_age(pmax(0, STDAGE - 40), .row_term(STDORGCD), .row_gstart(STDORGCD))),  # R-plantTerm
      gr_BA        = 1 + (pmin(pmax(if_else(d_BA > 0,        T2_BA / d_BA,        1.0), 0.5), 2.0) - 1) * .sat_age,
      gr_volcfnet  = 1 + (pmin(pmax(if_else(d_volcfnet > 0,  T2_volcfnet / d_volcfnet,  1.0), 0.5), 2.0) - 1) * .sat_age,
      gr_volcsnet  = if ("d_volcsnet" %in% names(harvested_plots) & "T2_volcsnet" %in% names(harvested_plots))
                        1 + (pmin(pmax(if_else(d_volcsnet > 0, T2_volcsnet / d_volcsnet, 1.0), 0.5), 2.0) - 1) * .sat_age
                       else 1.0,
      gr_drybio    = 1 + (pmin(pmax(if_else(d_drybio_ag > 0, T2_drybio_ag / d_drybio_ag, 1.0), 0.5), 2.0) - 1) * .sat_age,
      gr_carbon    = 1 + (pmin(pmax(if_else(d_carbon_ag > 0, T2_carbon_ag / d_carbon_ag, 1.0), 0.5), 2.0) - 1) * .sat_age,
      gr_tpa       = 1 + (pmin(pmax(if_else(d_tpa_live > 0,  T2_tpa_live / d_tpa_live, 1.0),  0.5), 2.0) - 1) * .sat_age,
      gr_qmd       = pmin(pmax(if_else(d_qmd > 0,       T2_qmd / d_qmd, 1.0),       0.7), 1.5),
      .cm          = 1 + (climate_mult - 1) * .sat_age,
      .anchor_pc    = if (isTRUE(getOption("cem.asym_anchor", FALSE))) {   # R-asymAnchor
                        .ar <- (coalesce(asym_agb, donor_asym) / pmax(coalesce(donor_asym, asym_agb), 1e-6))^(as.numeric(getOption("cem.asym_anchor_strength", 1)) / max(cfg$n_cycles, 1L))
                        .ar[is.na(.ar)] <- 1; pmin(pmax(.ar, 0.90), 1.12)
                      } else 1,
      proj_BA       = BA * gr_BA * .cm * .anchor_pc * (1 - harvest_intensity),
      proj_volcfnet = volcfnet * gr_volcfnet * .cm * .anchor_pc * (1 - harvest_intensity),
      proj_volcsnet = if ("volcsnet" %in% names(harvested_plots)) volcsnet * gr_volcsnet * .cm * .anchor_pc * (1 - harvest_intensity) else NA_real_,
      proj_drybio   = drybio_ag * gr_drybio * .cm * .anchor_pc * (1 - harvest_intensity),
      proj_carbon   = carbon_ag * gr_carbon * .cm * .anchor_pc * (1 - harvest_intensity),
      proj_tpa      = tpa_live * gr_tpa * (1 - harvest_intensity * 0.7),
      proj_qmd      = qmd * gr_qmd * sqrt(1 - harvest_intensity * 0.3),
      harv_c_total   = carbon_ag * gr_carbon * .cm * harvest_intensity,                                          # R-hwpEmit
      harv_c_saw     = ifelse(coalesce(vol_removed_total, 0) > 0, harv_c_total * coalesce(vol_removed_sawtimber, 0) / vol_removed_total, 0),  # R-hwpEmit
      harv_c_pulp    = ifelse(coalesce(vol_removed_total, 0) > 0, harv_c_total * coalesce(vol_removed_pulpwood,  0) / vol_removed_total, 0),  # R-hwpEmit
      harv_c_residue = pmax(harv_c_total - harv_c_saw - harv_c_pulp, 0),                                          # R-hwpEmit
      cycle         = cycle_num,
      sim           = sim_id,
      was_harvested = TRUE,
      was_planted   = coalesce(planted, FALSE),
      was_unmatched = FALSE
    ) |> select(-.sat_age, -.cm, -.is_cc, -.anchor_pc),
    # Unmatched subjects: no growth / no change. Uses T1 (subject) values
    # as the projected values so downstream aggregation treats them as
    # steady-state. pre_* = T2_* = projected = subject values. Product
    # class volumes are also echoed into T2_vol_* so the cycle-to-cycle
    # transmute in project_multi_cycle still finds the inputs it needs.
    unmatched |> mutate(
      pre_volcfnet  = volcfnet,
      pre_volcsnet  = if ("volcsnet" %in% names(unmatched)) volcsnet else NA_real_,
      pre_BA        = BA,
      pre_drybio_ag = drybio_ag,
      pre_carbon_ag = carbon_ag,
      pre_tpa_live  = tpa_live,
      pre_qmd       = qmd,
      T2_BA         = BA,
      T2_volcfnet   = volcfnet,
      T2_volcsnet   = if ("volcsnet" %in% names(unmatched)) volcsnet else NA_real_,
      T2_drybio_ag  = drybio_ag,
      T2_carbon_ag  = carbon_ag,
      T2_tpa_live   = tpa_live,
      T2_qmd        = qmd,
      T2_vol_sawtimber_softwood = dplyr::coalesce(vol_sawtimber_softwood, 0),
      T2_vol_sawtimber_hardwood = dplyr::coalesce(vol_sawtimber_hardwood, 0),
      T2_vol_pulpwood_softwood  = dplyr::coalesce(vol_pulpwood_softwood,  0),
      T2_vol_pulpwood_hardwood  = dplyr::coalesce(vol_pulpwood_hardwood,  0),
      proj_BA       = BA,
      proj_volcfnet = volcfnet,
      proj_volcsnet = if ("volcsnet" %in% names(unmatched)) volcsnet else NA_real_,
      proj_drybio   = drybio_ag,
      proj_carbon   = carbon_ag,
      proj_tpa      = tpa_live,
      proj_qmd      = qmd,
      harv_c_total = 0, harv_c_saw = 0, harv_c_pulp = 0, harv_c_residue = 0,   # R-hwpEmit
      cycle         = cycle_num,
      sim           = sim_id,
      was_harvested = FALSE,
      was_planted   = FALSE,
      was_unmatched = TRUE
    )
  )

  # Apply v4 productivity multiplier (Phase 2) if enabled. Per-cycle scalar
  # from FIA empirical asymptote keyed by stratum cell. Applied BEFORE
  # SDImax cap so over-scaled strata still get bounded by carrying capacity.
  all_projected <- apply_v4_prod_mult(all_projected)

  # Apply BRMS SDImax cap (R5) if enabled. Caps proj_BA / proj_*_carbon /
  # proj_drybio / proj_volcfnet / proj_volcsnet to plot SDImax x Reineke.
  all_projected <- apply_sdimax_cap(all_projected)

  # Apply episodic disturbance module (R6) if enabled.
  all_projected <- apply_disturbance(all_projected, cycle_num, sim_id)

  # Apply species-specific climate response (R4) if enabled.
  all_projected <- apply_species_climate(all_projected, dT)

  # --- Step 8: Compute cycle summary statistics ------------------------------
  # Decomposition (#6): mean volume change = gross_growth - mortality - removals.
  # Gross growth: donor T2 - donor T1 on non-harvested, clipped to positive.
  # Harvest removals: sum of vol_removed_total from harvested_plots.
  # Mortality: net donor decline on non-harvested where T2 < T1 (proxy).
  cycle_summary <- all_projected |>
    summarise(
      cycle            = cycle_num,
      sim              = sim_id,
      scenario         = scenario$name,
      n_conditions     = n(),
      mean_ba          = mean(proj_BA, na.rm = TRUE),
      mean_vol         = mean(proj_volcfnet, na.rm = TRUE),
      mean_carbon      = mean(proj_carbon, na.rm = TRUE),
      total_tpa        = mean(proj_tpa, na.rm = TRUE),
      n_harvested      = sum(was_harvested),
      harvest_rate     = mean(was_harvested),
      n_planted        = sum(was_planted, na.rm = TRUE),
      plant_rate       = mean(was_planted, na.rm = TRUE),
      # Decomposition: growth / mortality / removals per cycle, all in per-plot
      # cuft units so they're comparable. gross_growth and mortality already
      # average across ALL plots (zero contribution from non-events). Removals
      # must do the same: sum the harvested volume and divide by total plot
      # count (not harvested-plot count), giving a per-plot mean where unharvested
      # plots contribute zero. This makes gr_ratio = growth_per_plot /
      # removals_per_plot, which is dimensionally consistent. Prior version
      # divided by harvested-plot count which inflated removals by 1/harvest_rate
      # (~10x for ME, ~9x for MN, ~6x for WA, ~5x for GA), producing gr_ratio
      # values ~1000x too small.
      gross_growth     = mean(pmax(coalesce(T2_volcfnet - pre_volcfnet, 0), 0), na.rm = TRUE),
      mortality        = mean(pmax(coalesce(pre_volcfnet - T2_volcfnet, 0), 0), na.rm = TRUE),
      harvest_removals = if (nrow(harvested_plots) > 0) {
                           sum(harvested_plots$vol_removed_total, na.rm = TRUE) / n()
                         } else 0,
      net_change       = gross_growth - mortality - harvest_removals,
      gr_ratio         = if (harvest_removals > 0) gross_growth / harvest_removals else Inf,
      # Track whether a climate RCP was applied
      climate_rcp      = if (!is.null(cfg$climate_rcp)) as.numeric(cfg$climate_rcp) else NA_real_
    )

  return(list(
    projected     = all_projected,
    cycle_summary = cycle_summary,
    cem_result    = cem_result,
    match_quality = cem_result$match_summary
  ))
}

# =============================================================================
# 2. Multi-Cycle Projection
# =============================================================================

#' Run projection over multiple cycles
#' @param data_list Output from prepare_fia_data()
#' @param scenario Scenario specification
#' @param cfg Configuration
#' @param sim_id Simulation replicate ID
#' @return List: all projected data, cycle summaries, final inventory
project_multi_cycle <- function(data_list, scenario, cfg = CONFIG, sim_id = 1) {

  subjects   <- data_list$subjects
  remeasured <- data_list$remeasured

  all_projected <- list()
  all_summaries <- list()
  current_subjects <- subjects

  for (cyc in seq_len(cfg$n_cycles)) {

    cat(sprintf("\n--- Cycle %d/%d (Scenario: %s, Sim: %d) ---\n",
                cyc, cfg$n_cycles, scenario$name, sim_id))

    # Update prices over time if price scenario requires it
    prices <- get_cycle_prices(cfg, cyc, scenario)

    # Update climate if dynamic
    climate_data <- NULL
    if (cfg$climate$use_climate) {
      target_year <- max(current_subjects$INVYR, na.rm = TRUE) +
                     cyc * cfg$cycle_length_yrs
      climate_data <- get_climate_for_year(cfg, target_year, scenario)
    }

    # Project one cycle
    result <- project_one_cycle(
      subjects     = current_subjects,
      remeasured   = remeasured,
      scenario     = scenario,
      prices       = prices,
      climate_data = climate_data,
      cfg          = cfg,
      cycle_num    = cyc,
      sim_id       = sim_id
    )

    all_projected[[cyc]] <- result$projected
    all_summaries[[cyc]] <- result$cycle_summary

    # Update subjects for next cycle: projected conditions become new subjects.
    # Rescale product-class volumes proportional to the projected total
    # volcfnet change so the harvest choice model has them available.
    .vol_scale <- ifelse(
      is.na(result$projected$T2_volcfnet) | result$projected$T2_volcfnet <= 0, 1,
      result$projected$proj_volcfnet / result$projected$T2_volcfnet
    )
    current_subjects <- result$projected |>
      mutate(.vol_scale = .vol_scale) |>
      transmute(
        STATECD, COUNTYCD, PLOT, CONDID,
        INVYR = INVYR + cfg$cycle_length_yrs,
        CONDPROP_UNADJ, CONDPROP_C,
        OWNGRPCD, FORTYPCD,
        STDORGCD = ifelse(was_planted, 1L, STDORGCD),
        SITECLCD, SLOPE, ASPECT, PHYSCLCD,
        STDAGE = STDAGE + cfg$cycle_length_yrs,
        BA = proj_BA,
        ba_live = proj_BA,
        tpa_live = proj_tpa,
        qmd = proj_qmd,
        volcfnet = proj_volcfnet,
        volcsnet = proj_volcsnet,
        drybio_ag = proj_drybio,
        carbon_ag = proj_carbon,
        vol_sawtimber_softwood = coalesce(T2_vol_sawtimber_softwood, 0) * .vol_scale,
        vol_sawtimber_hardwood = coalesce(T2_vol_sawtimber_hardwood, 0) * .vol_scale,
        vol_pulpwood_softwood  = coalesce(T2_vol_pulpwood_softwood,  0) * .vol_scale,
        vol_pulpwood_hardwood  = coalesce(T2_vol_pulpwood_hardwood,  0) * .vol_scale,
        n_species, dom_spcd, var_val,
        LAT, LON, ELEV, PLT_CN
      )
  }

  # Combine results across cycles
  all_projected_df <- bind_rows(all_projected)
  all_summaries_df <- bind_rows(all_summaries)

  return(list(
    projected    = all_projected_df,
    summaries    = all_summaries_df,
    final_inv    = current_subjects,
    scenario     = scenario
  ))
}

# =============================================================================
# 3. Monte Carlo Simulation Wrapper
# =============================================================================

#' Run Monte Carlo simulations across multiple scenarios
#' @param data_list Output from prepare_fia_data()
#' @param scenarios List of scenario specifications
#' @param cfg Configuration
#' @return List: all results by scenario, combined summaries
run_monte_carlo <- function(data_list, scenarios = NULL, cfg = CONFIG) {

  if (is.null(scenarios)) {
    scenarios <- standard_scenarios()
  }

  cat("=== Monte Carlo Projection ===\n")
  cat(sprintf("  Scenarios: %d | Simulations per scenario: %d | Cycles: %d\n",
              length(scenarios), cfg$n_simulations, cfg$n_cycles))

  all_results <- list()
  all_summaries <- list()

  for (s in seq_along(scenarios)) {
    scen <- scenarios[[s]]
    cat(sprintf("\n=== Scenario: %s (%d/%d) ===\n",
                scen$name, s, length(scenarios)))

    scenario_results <- list()
    scenario_summaries <- list()

    for (sim in seq_len(cfg$n_simulations)) {
      if (sim %% 10 == 0) {
        cat(sprintf("  Simulation %d/%d\n", sim, cfg$n_simulations))
      }

      # Bootstrap-per-sim (#9): if enabled, resample subjects with
      # replacement so each sim replicate sees a different plot sample.
      # Widens the CI ribbons to include sampling uncertainty, not just
      # CEM match-selection randomness.
      sim_data <- data_list
      if (isTRUE(cfg$bootstrap_plots)) {
        boot_frac <- cfg$bootstrap_frac %||% 1.0
        set.seed(cfg$seed + sim * 17L)
        n_sub <- nrow(data_list$subjects)
        sub_idx <- sample.int(n_sub, size = round(n_sub * boot_frac),
                              replace = FALSE)  # R-areafix: no-replace avoids duplicate collapse in matching
        sim_data$subjects <- data_list$subjects[sub_idx, , drop = FALSE]
        if (!is.null(data_list$remeasured)) {
          n_rem <- nrow(data_list$remeasured)
          rem_idx <- sample.int(n_rem, size = round(n_rem * boot_frac),
                                replace = TRUE)
          sim_data$remeasured <- data_list$remeasured[rem_idx, , drop = FALSE]
        }
      }

      result <- project_multi_cycle(
        sim_data, scen, cfg, sim_id = sim
      )

      scenario_results[[sim]] <- result$projected
      scenario_summaries[[sim]] <- result$summaries
    }

    all_results[[scen$name]] <- bind_rows(scenario_results)
    all_summaries[[scen$name]] <- bind_rows(scenario_summaries)
  }

  # Combine across scenarios
  combined_summaries <- bind_rows(all_summaries)

  # Compute confidence intervals across simulations
  ci_summaries <- combined_summaries |>
    group_by(scenario, cycle) |>
    summarise(
      across(
        c(mean_ba, mean_vol, mean_carbon, total_tpa,
          harvest_rate, plant_rate, gr_ratio),
        list(
          mean = ~ mean(., na.rm = TRUE),
          lo   = ~ quantile(., 0.025, na.rm = TRUE),
          hi   = ~ quantile(., 0.975, na.rm = TRUE)
        ),
        .names = "{.col}_{.fn}"
      ),
      n_sims = n(),
      .groups = "drop"
    )

  cat("\n=== Monte Carlo complete ===\n")

  return(list(
    all_results     = all_results,
    all_summaries   = combined_summaries,
    ci_summaries    = ci_summaries,
    scenarios       = scenarios,
    cfg             = cfg
  ))
}

# =============================================================================
# 4. Helper: Price Trajectory
# =============================================================================

#' Get prices for a specific projection cycle
#' @param cfg Configuration
#' @param cycle Cycle number
#' @param scenario Scenario specification
#' @return Price list
get_cycle_prices <- function(cfg, cycle, scenario) {

  prices <- cfg$harvest$base_prices

  # Apply scenario price multiplier
  mult <- scenario$price_mult %||% 1.0

  # Optional: time-varying price trajectory
  if (cfg$harvest$price_scenario == "increasing") {
    time_mult <- 1.0 + 0.02 * (cycle - 1) * cfg$cycle_length_yrs
  } else if (cfg$harvest$price_scenario == "decreasing") {
    time_mult <- 1.0 - 0.01 * (cycle - 1) * cfg$cycle_length_yrs
  } else {
    time_mult <- 1.0
  }

  total_mult <- mult * time_mult

  modify_prices(prices, total_mult)
}

#' Modify prices by a multiplier
#' @param prices Base price list
#' @param mult Multiplier
#' @return Modified price list
modify_prices <- function(prices, mult) {
  list(
    sawtimber = list(
      softwood = prices$sawtimber$softwood * mult,
      hardwood = prices$sawtimber$hardwood * mult
    ),
    pulpwood = list(
      softwood = prices$pulpwood$softwood * mult,
      hardwood = prices$pulpwood$hardwood * mult
    )
  )
}

# =============================================================================
# 5. Moving Window Estimation
# =============================================================================

#' Compute moving window estimates combining actual and projected data
#' @param actual Actual FIA estimates by year
#' @param projected Projected estimates by cycle
#' @param window_width Width of moving window (years)
#' @return Moving window estimates
compute_moving_window <- function(actual, projected, window_width = 3) {

  # Combine actual and projected into a single time series
  combined <- bind_rows(
    actual |> mutate(source = "actual"),
    projected |> mutate(source = "projected")
  ) |>
    arrange(year)

  # Apply moving window
  all_years <- sort(unique(combined$year))

  mw_estimates <- map_dfr(all_years, function(yr) {
    window_start <- yr - floor(window_width / 2)
    window_end   <- yr + floor(window_width / 2)

    window_data <- combined |>
      filter(year >= window_start, year <= window_end)

    if (nrow(window_data) == 0) return(NULL)

    window_data |>
      summarise(
        year           = yr,
        window_start   = window_start,
        window_end     = window_end,
        n_actual       = sum(source == "actual"),
        n_projected    = sum(source == "projected"),
        across(
          c(mean_ba, mean_vol, mean_carbon, total_tpa,
            harvest_rate, gr_ratio),
          ~ mean(., na.rm = TRUE)
        )
      )
  })

  return(mw_estimates)
}
