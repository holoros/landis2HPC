# =============================================================================
# Title: Scenario Biasing for CEM Match Selection
# Author: A. Weiskittel
# Date: 2026-03-19
# Description: Implements the stochastic biasing method from Van Deusen &
#              Roesch (2013) for scenario generation. Controls the probability
#              of selecting event-impacted matches to deviate from BAU.
# References:
#   Van Deusen & Roesch (2013) Eqs. 1-5
# Dependencies: 00_config.R, 02_cem_matching.R
# =============================================================================

library(tidyverse)

# =============================================================================
# 1. Compute Biasing Parameter r
# =============================================================================

#' Compute the biasing parameter r for a given scenario multiplier Q
#' Van Deusen & Roesch (2013) Equation 5:
#' r(Q) = [(1 - ne/N * Q) * N/(N-ne)]^(-1/ne) - 1
#'
#' @param ne Number of event-impacted matches
#' @param N Total number of matches
#' @param Q Scenario multiplier (1.0 = BAU, 1.5 = +50% events, etc.)
#' @return Biasing parameter r (>= 0)
compute_r_value <- function(ne, N, Q) {

  if (ne == 0 || N == 0 || ne == N) return(0)

  # Equation 5 from Van Deusen & Roesch (2013)
  inner <- (1 - (ne / N) * Q) * (N / (N - ne))

  # Check validity: inner must be positive for real r

  if (inner <= 0) {
    # Q is too large for the available event proportion
    # Return a large r to maximize event selection
    return(10)
  }

  r <- inner^(-1 / ne) - 1

  # r should be non-negative
  return(max(r, 0))
}

#' Vectorized r computation for multiple subject-match groups
#' @param match_data Match pairs grouped by subject
#' @param event_col Name of the logical event column (e.g., "harvested")
#' @param Q Scenario multiplier
#' @return Tibble with r_value column added to each group
compute_r_values_grouped <- function(match_data, event_col = "harvested", Q = 1.0) {

  if (Q == 1.0) {
    return(match_data |> mutate(r_value = 0))
  }

  match_data |>
    group_by(subject_row) |>
    mutate(
      ne_group = sum(.data[[event_col]], na.rm = TRUE),
      N_group  = n(),
      r_value  = compute_r_value(ne_group, N_group, Q)
    ) |>
    ungroup() |>
    select(-ne_group, -N_group)
}

# =============================================================================
# 2. Biased Match Selection
# =============================================================================

#' Apply biased selection to CEM matches
#' Implements Van Deusen & Roesch (2013) Equation 1:
#' RV_i = {u1+r, u2+r, ..., u'1, u'2, ...}
#' Select the match with the largest RV value
#'
#' @param match_data CEM match pairs (from run_cem_matching)
#' @param event_col Name of the logical event column
#' @param Q Scenario multiplier
#' @param seed Random seed
#' @return Tibble with one selected match per subject
select_biased_matches <- function(match_data, event_col = "harvested",
                                  Q = 1.0, seed = 42) {
  set.seed(seed)

  if (Q == 1.0) {
    # BAU: simple random selection
    selected <- match_data |>
      group_by(subject_row) |>
      mutate(rv = runif(n())) |>
      slice_max(rv, n = 1, with_ties = FALSE) |>
      ungroup() |>
      select(-rv)
    return(selected)
  }

  # Compute per-group r values
  match_data <- compute_r_values_grouped(match_data, event_col, Q)

  # Apply biased random variates
  selected <- match_data |>
    group_by(subject_row) |>
    mutate(
      u = runif(n()),
      # Add r to event-impacted matches
      rv = ifelse(.data[[event_col]], u + r_value, u)
    ) |>
    slice_max(rv, n = 1, with_ties = FALSE) |>
    ungroup() |>
    select(-u, -rv, -r_value)

  return(selected)
}

# =============================================================================
# 3. Multi-Event Scenario Generation
# =============================================================================

#' Generate scenario with multiple event types biased simultaneously
#' @param match_data CEM match pairs
#' @param scenario_Q Named list of Q values for each event type
#'                   e.g., list(harvested = 1.5, has_fire = 2.0)
#' @param seed Random seed
#' @return Selected matches with combined biasing
select_multi_event_matches <- function(match_data, scenario_Q, seed = 42) {

  set.seed(seed)

  # Start with base random variates (R-prodW: optional productivity weighting)
  .use_pw <- isTRUE(getOption("cem.prod_weighting", FALSE)) &&
             all(c("asym_agb", "donor_asym") %in% names(match_data))
  .bw_pw <- as.numeric(getOption("cem.prod_bw", 50))
  match_data <- match_data |>
    mutate(rv = if (.use_pw) {
             w <- exp(-0.5 * ((donor_asym - asym_agb) / .bw_pw)^2)
             w[is.na(w)] <- 1
             runif(n())^(1 / pmax(w, 1e-6))
           } else runif(n()))

  # For each event type, compute r and add to rv

  for (event in names(scenario_Q)) {
    Q_val <- scenario_Q[[event]]

    if (Q_val != 1.0 && event %in% names(match_data)) {
      match_data <- match_data |>
        group_by(subject_row) |>
        mutate(
          ne_tmp = sum(.data[[event]], na.rm = TRUE),
          N_tmp  = n(),
          r_tmp  = map2_dbl(ne_tmp, N_tmp, ~ compute_r_value(.x, .y, Q_val)),
          rv = ifelse(.data[[event]], rv + r_tmp, rv)
        ) |>
        ungroup() |>
        select(-ne_tmp, -N_tmp, -r_tmp)
    }
  }

  # Select match with highest combined rv
  selected <- match_data |>
    group_by(subject_row) |>
    slice_max(rv, n = 1, with_ties = FALSE) |>
    ungroup() |>
    select(-rv)

  return(selected)
}

# =============================================================================
# 4. Scenario Definition Helper
# =============================================================================

#' Create a named scenario specification
#' @param name Scenario name
#' @param harvest_Q Q for harvest events (default 1.0 = BAU)
#' @param fire_Q Q for fire events
#' @param insect_Q Q for insect events
#' @param wind_Q Q for wind events
#' @param price_mult Price multiplier (1.0 = base prices)
#' @param climate_scenario Climate scenario name (e.g., "ssp245")
#' @return Scenario specification list
define_scenario <- function(name,
                            harvest_Q = 1.0,
                            fire_Q = 1.0,
                            insect_Q = 1.0,
                            wind_Q = 1.0,
                            price_mult = 1.0,
                            climate_scenario = "current",
                            conversion_rate = NULL,
                            afforest_rate = NULL) {
  list(
    name     = name,
    Q_values = list(
      harvested  = harvest_Q,
      has_fire   = fire_Q,
      has_insect = insect_Q,
      has_wind   = wind_Q
    ),
    price_mult        = price_mult,
    climate_scenario  = climate_scenario,
    conversion_rate   = conversion_rate,
    afforest_rate     = afforest_rate
  )
}

#' Create standard scenario set for analysis
#' @return List of scenario specifications
standard_scenarios <- function() {
  list(
    define_scenario("BAU",          harvest_Q = 1.0),
    define_scenario("Harvest_m50",  harvest_Q = 0.5),
    define_scenario("Harvest_p50",  harvest_Q = 1.5),
    define_scenario("Harvest_p100", harvest_Q = 2.0),
    define_scenario("High_fire",    fire_Q = 2.0),
    define_scenario("High_insect",  insect_Q = 2.0),
    define_scenario("High_price",   harvest_Q = 1.0, price_mult = 1.5),
    define_scenario("Low_price",    harvest_Q = 1.0, price_mult = 0.5)
  )
}

# --- Maine focused scenario sets --------------------------------------------

#' BAU only (reference run)
bau_only_scenarios <- function() {
  list(
    define_scenario("BAU", harvest_Q = 1.0)
  )
}

#' Maine relevant harvest variants
#' No harvest (Q=0) plus BAU plus three industry narratives.
maine_harvest_scenarios <- function() {
  list(
    define_scenario("No_harvest",           harvest_Q = 0.00),
    define_scenario("Harvest_m25_mill",     harvest_Q = 0.75),
    define_scenario("BAU",                  harvest_Q = 1.00),
    define_scenario("Harvest_p25_pulp",     harvest_Q = 1.25),
    define_scenario("Harvest_p50_biomass",  harvest_Q = 1.50)
  )
}

#' Climate change via disturbance proxy
#' Elevated fire and insect disturbance represent projected climate stress
#' without requiring spatial climate matching. Scaled approximately to
#' 3 C warming using the config disturbance sensitivity multipliers.
climate_proxy_scenarios <- function() {
  list(
    define_scenario("BAU",      harvest_Q = 1.0),
    define_scenario("CC_proxy", fire_Q = 1.5, insect_Q = 1.75, wind_Q = 1.1,
                    climate_scenario = "proxy_3C")
  )
}

#' Climate change with full spatial climate matching
#' Requires climate_combined_{state}.csv to be present. Run after the climate
#' download script has completed.
climate_matching_scenarios <- function() {
  list(
    define_scenario("BAU",        harvest_Q = 1.0, climate_scenario = "current"),
    define_scenario("CC_ssp245",  harvest_Q = 1.0, fire_Q = 1.3, insect_Q = 1.4,
                    climate_scenario = "ssp245"),
    define_scenario("CC_ssp585",  harvest_Q = 1.0, fire_Q = 1.7, insect_Q = 2.0,
                    climate_scenario = "ssp585")
  )
}

#' Dispatcher: pick a scenario set by name
#' @param name One of "standard", "bau", "harvest", "climate_proxy",
#'   "climate_matching"

#' Maine policy shock scenarios: BAU vs high price (+50%) vs low price (-50%)
#' Tests sensitivity of Maine forest carbon to stumpage market conditions.
maine_policy_scenarios <- function() {
  list(
    define_scenario("BAU",          harvest_Q = 1.0, price_mult = 1.0),
    define_scenario("Price_shock",  harvest_Q = 1.0, price_mult = 1.5),
    define_scenario("Price_crash",  harvest_Q = 1.0, price_mult = 0.5)
  )
}

#' Maine land use change scenarios: BAU plus development pressure plus
#' afforestation. Modeled as additive shifts to forest area each cycle.
#' Forest-to-development conversion baseline 5,295 ac/yr (2023 SAR).
#' Reforestation/afforestation scenarios test policy levers for new forest.
#' Note: these scenarios are interpreted at the state-expansion stage in
#' 10_state_expansion.R via the conversion_rate and afforest_rate fields,
#' rather than per-plot in 06_projection_engine.R.
maine_land_use_scenarios <- function() {
  list(
    define_scenario("BAU",          harvest_Q = 1.0, conversion_rate = 5295, afforest_rate = 0),
    define_scenario("Develop2x",    harvest_Q = 1.0, conversion_rate = 10590, afforest_rate = 0),
    define_scenario("Reforest25k",  harvest_Q = 1.0, conversion_rate = 5295, afforest_rate = 25000),
    define_scenario("Reforest50k",  harvest_Q = 1.0, conversion_rate = 5295, afforest_rate = 50000),
    define_scenario("LowDev_HiRefor", harvest_Q = 1.0, conversion_rate = 2500, afforest_rate = 50000)
  )
}

#' @return List of scenarios
get_scenario_set <- function(name = "standard") {
  set_name <- tolower(as.character(name))
  switch(set_name,
    "standard"         = standard_scenarios(),
    "bau"              = bau_only_scenarios(),
    "harvest"          = maine_harvest_scenarios(),
    "climate_proxy"    = climate_proxy_scenarios(),
    "climate_matching" = climate_matching_scenarios(),
    "maine_policy"     = maine_policy_scenarios(),
    "maine_land_use"   = maine_land_use_scenarios(),
    stop(sprintf(
      "Unknown scenario set '%s'. Options: standard, bau, harvest, climate_proxy, climate_matching, maine_policy, maine_land_use",
      name))
  )
}

# =============================================================================
# 5. Wrapper: Apply Scenario Bias (called from 02_cem_matching.R)
# =============================================================================

#' Apply scenario biasing to CEM matches
#' @param matches CEM match pairs
#' @param bias_params Scenario specification (from define_scenario)
#' @param seed Random seed
#' @return Selected matches biased according to scenario
apply_scenario_bias <- function(matches, bias_params, seed = 42) {

  # R-prodW: soft productivity-weighted donor draw (Efraimidis-Spirakis key
  # rv = u^(1/w), w = exp(-0.5*((donor_asym - asym_agb)/bw)^2)). When disabled
  # or columns absent, falls back to the original uniform draw.
  use_pw <- isTRUE(getOption("cem.prod_weighting", FALSE)) &&
            all(c("asym_agb", "donor_asym") %in% names(matches))
  bw_pw <- as.numeric(getOption("cem.prod_bw", 50))

  if (is.null(bias_params) || all(unlist(bias_params$Q_values) == 1.0)) {
    # BAU scenario: random (optionally productivity-weighted) selection
    # s46 determinism fix (Track K amendment v6 K2, v7 K3): seed this draw site from the
    # seed argument the engine already passes (cfg$seed + cycle_num * 1000 + sim_id), which
    # the original BAU branch ignored, and sort candidates before the unchanged random draw.
    set.seed(seed)
    return(
      matches |>
        arrange(subject_row, donor_idx, dplyr::across(dplyr::any_of("cem_iteration"))) |>
        group_by(subject_row) |>
        mutate(rv = if (use_pw) {
                 w <- exp(-0.5 * ((donor_asym - asym_agb) / bw_pw)^2)
                 w[is.na(w)] <- 1
                 runif(n())^(1 / pmax(w, 1e-6))
               } else runif(n())) |>
        slice_max(rv, n = 1, with_ties = FALSE) |>
        ungroup() |>
        select(-rv)
    )
  }

  # Use multi-event selection
  select_multi_event_matches(matches, bias_params$Q_values, seed)
}

# =============================================================================
# 6. Diagnostic: Verify Scenario Achieves Target Q
# =============================================================================

#' Check achieved event frequency relative to target Q
#' @param selected Selected match records
#' @param all_matches All available matches (pre-selection)
#' @param event_col Event column name
#' @param target_Q Target Q value
#' @return Summary tibble
verify_scenario_achievement <- function(selected, all_matches,
                                         event_col = "harvested",
                                         target_Q = 1.0) {

  # BAU rate (proportion of events in full match pool)
  bau_rate <- mean(all_matches[[event_col]], na.rm = TRUE)

  # Achieved rate
  achieved_rate <- mean(selected[[event_col]], na.rm = TRUE)

  # Achieved Q
  achieved_Q <- if (bau_rate > 0) achieved_rate / bau_rate else NA_real_

  tibble(
    event         = event_col,
    target_Q      = target_Q,
    bau_rate      = bau_rate,
    achieved_rate = achieved_rate,
    achieved_Q    = achieved_Q,
    pct_error     = if (!is.na(achieved_Q)) {
                      100 * (achieved_Q - target_Q) / target_Q
                    } else NA_real_
  )
}
