# =============================================================================
# Title: Timber Supply Estimation Module
# Author: A. Weiskittel
# Date: 2026-03-19
# Description: Estimates regional timber supply curves using Monte Carlo
#              simulations of harvest choices applied to current inventory.
#              Follows Wear & Coulston (2025) Section 2.3 and Eq. 9-10.
# References:
#   Wear & Coulston (2025) Eqs. 9-10
#   Polyakov et al. (2010)
# Dependencies: 03_harvest_choice.R, 06_projection_engine.R
# =============================================================================

library(tidyverse)

# =============================================================================
# 1. Supply Curve Estimation
# =============================================================================

#' Estimate timber supply at a given price level
#' Q(p)_m = sum_i { Pr(h=1|p) * R_m,i }
#' Wear & Coulston (2025) Equation 9
#'
#' @param cond_data Inventory conditions with harvest covariates
#' @param prices Price vector
#' @param cfg Configuration
#' @return Total supply by product class
estimate_supply_at_price <- function(cond_data, prices, cfg) {

  # Predict harvest probability at this price level
  cond_econ <- predict_harvest_probability(cond_data, prices = prices, cfg = cfg)

  # Predict harvest intensity for each condition
  cond_econ <- predict_harvest_intensity(cond_econ, cfg$rpa_region)

  # Estimate removals
  cond_econ <- estimate_removals(cond_econ, prices)

  # Supply = sum of Pr(harvest) * removals
  supply <- cond_econ |>
    summarise(
      supply_sawtimber = sum(coalesce(harvest_prob_adj, harvest_prob) *
                             vol_removed_sawtimber, na.rm = TRUE),
      supply_pulpwood  = sum(coalesce(harvest_prob_adj, harvest_prob) *
                             vol_removed_pulpwood, na.rm = TRUE),
      supply_total     = supply_sawtimber + supply_pulpwood,
      n_conditions     = n(),
      expected_harvests = sum(coalesce(harvest_prob_adj, harvest_prob), na.rm = TRUE)
    )

  return(supply)
}

#' Generate supply curve by varying prices
#' @param cond_data Inventory conditions
#' @param price_range Price multiplier range (e.g., seq(0.5, 2.0, by = 0.1))
#' @param cfg Configuration
#' @param n_mc Number of Monte Carlo replicates per price point
#' @return Tibble with price level and supply quantities
generate_supply_curve <- function(cond_data, price_range = seq(0.5, 2.0, by = 0.1),
                                  cfg = CONFIG, n_mc = 100) {

  cat("Generating supply curve...\n")
  base_prices <- cfg$harvest$base_prices

  results <- map_dfr(price_range, function(p_mult) {
    prices <- modify_prices(base_prices, p_mult)

    # Monte Carlo replicates for variance estimation
    mc_results <- map_dfr(seq_len(n_mc), function(mc) {
      set.seed(cfg$seed + mc)
      supply <- estimate_supply_at_price(cond_data, prices, cfg)
      supply |> mutate(mc_rep = mc)
    })

    mc_results |>
      summarise(
        price_index       = p_mult,
        supply_mean       = mean(supply_total),
        supply_se         = sd(supply_total) / sqrt(n()),
        supply_lo         = quantile(supply_total, 0.025),
        supply_hi         = quantile(supply_total, 0.975),
        saw_supply_mean   = mean(supply_sawtimber),
        pulp_supply_mean  = mean(supply_pulpwood),
        expected_harvests = mean(expected_harvests)
      )
  })

  cat(sprintf("  Supply curve: %d price points x %d MC reps\n",
              length(price_range), n_mc))

  return(results)
}

# =============================================================================
# 2. Supply Elasticity Estimation
# =============================================================================

#' Estimate price elasticity of supply from supply curve
#' Following Wear & Coulston (2025) Table 4 and Eq. 10:
#' ln(Q_m,k) = alpha + sum_j { beta_j * ln(p_j) }
#'
#' @param supply_curve Output from generate_supply_curve()
#' @return List with short-run and long-run elasticity estimates
estimate_supply_elasticity <- function(supply_curve) {

  # Fit log-log model: ln(supply) = alpha + beta * ln(price)
  supply_positive <- supply_curve |>
    filter(supply_mean > 0, price_index > 0)

  if (nrow(supply_positive) < 3) {
    warning("Insufficient data points for elasticity estimation")
    return(list(short_run = NA, long_run = NA))
  }

  fit <- lm(log(supply_mean) ~ log(price_index), data = supply_positive)

  short_run_elasticity <- coef(fit)["log(price_index)"]
  se_elasticity <- summary(fit)$coefficients["log(price_index)", "Std. Error"]

  # Long-run elasticity (approximate: short_run * adjustment factor)
  # In practice, this comes from inter-period supply shifts
  long_run_elasticity <- short_run_elasticity * 2.0  # rough multiplier

  cat(sprintf("  Short-run elasticity: %.4f (SE: %.4f)\n",
              short_run_elasticity, se_elasticity))
  cat(sprintf("  Long-run elasticity (approx): %.4f\n", long_run_elasticity))

  return(list(
    short_run = tibble(
      elasticity = short_run_elasticity,
      se         = se_elasticity,
      r_squared  = summary(fit)$r.squared
    ),
    long_run = tibble(
      elasticity = long_run_elasticity,
      se         = se_elasticity * 2.0
    ),
    model = fit
  ))
}

# =============================================================================
# 3. Long-Run Supply Projections
# =============================================================================

#' Project timber supply over time using the full FDM framework
#' @param mc_results Output from run_monte_carlo()
#' @param price_trajectory Named list of prices by cycle
#' @return Supply trajectory by cycle, scenario, and simulation
project_supply_trajectory <- function(mc_results, price_trajectory = NULL) {

  summaries <- mc_results$all_summaries

  # Extract supply-relevant metrics by scenario and cycle
  supply_trajectory <- summaries |>
    group_by(scenario, cycle) |>
    summarise(
      mean_removals    = mean(harvest_removals, na.rm = TRUE),
      mean_growth      = mean(gross_growth, na.rm = TRUE),
      mean_gr_ratio    = mean(gr_ratio, na.rm = TRUE),
      mean_harvest_pct = mean(harvest_rate, na.rm = TRUE),
      mean_ba          = mean(mean_ba, na.rm = TRUE),
      mean_vol         = mean(mean_vol, na.rm = TRUE),
      mean_carbon      = mean(mean_carbon, na.rm = TRUE),
      lo_vol           = quantile(mean_vol, 0.025, na.rm = TRUE),
      hi_vol           = quantile(mean_vol, 0.975, na.rm = TRUE),
      .groups          = "drop"
    )

  return(supply_trajectory)
}

# =============================================================================
# 4. Regional Supply Comparison
# =============================================================================

#' Compare supply across states or regions
#' @param state_results Named list of MC results by state
#' @return Comparison table
compare_regional_supply <- function(state_results) {

  comparison <- map_dfr(names(state_results), function(st) {
    res <- state_results[[st]]
    res$ci_summaries |>
      mutate(state = st)
  })

  return(comparison)
}
