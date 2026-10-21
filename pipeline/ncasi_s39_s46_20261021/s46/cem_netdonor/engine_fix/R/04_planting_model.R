# =============================================================================
# Title: Tree Planting Probability Model
# Author: A. Weiskittel
# Date: 2026-03-19
# Description: Implements the tree-planting logistic model from Wear &
#              Coulston (2025, Table 3). Predicts probability of planting
#              following harvest as a function of previous planting status,
#              revenues, and site conditions.
# References:
#   Wear & Coulston (2025) Eq. 7, Table 3
# Dependencies: 00_config.R
# =============================================================================

library(tidyverse)

# =============================================================================
# 1. Planting Model Coefficients
# =============================================================================

#' Default planting model coefficients by region and ownership
#' From Wear & Coulston (2025) Table 3
#' Model: Pr(plant=1) = logit(alpha + beta1*planted_prev + beta2*REV_pulp
#'                             + beta3*REV_saw + delta*slope_dummy)
get_default_planting_coefficients <- function() {

  tribble(
    ~region,         ~owner,          ~intercept, ~planted_prev, ~rev_sawtimber, ~rev_pulpwood, ~slope_dummy,
    "Southeast",     "other_private", -1.9175,     0.9397,       0.0001,         0.0007,        -1.1991,
    "Southeast",     "commercial",    -2.1686,     1.4296,       0.0000,         0.0016,        -2.1242,
    "South_Central", "commercial",    -2.2270,     1.7500,       0.0001,         0.0033,        -1.3109,
    "South_Central", "other_private", -4.0452,     2.6245,       0.0001,         0.0018,        -0.6934,
    "Northeast",     "private",       -7.5636,     8.4280,      -0.0003,         0.0671,        -5.0689,
    "North_Central", "private",       -5.2160,     7.8224,       0.0006,         0.0012,       -76.7128,
    "North_Central", "public",        -3.6793,     8.9212,      -0.0019,         0.0081,         2.1365,
    "Rockies_North", "private",      -22.1588,     NA,           0.0007,         0.0191,        -1.5981,
    "Pacific_NW",    "private",       -2.8472,     0.1923,       0.0002,        -0.0006,         1.3224
  )
}

# =============================================================================
# 2. Planting Probability Prediction
# =============================================================================

#' Predict probability of tree planting following harvest
#' @param cond_data Condition data for harvested plots
#' @param prices Timber prices (for revenue calculation)
#' @param cfg Configuration
#' @return Tibble with plant_prob column
predict_planting_probability <- function(cond_data, prices = NULL, cfg = CONFIG) {

  if (is.null(prices)) prices <- cfg$harvest$base_prices

  coefs <- get_default_planting_coefficients()

  region_map <- c(
    "NE" = "Northeast", "NC" = "North_Central",
    "SE" = "Southeast", "SC" = "South_Central",
    "PNW" = "Pacific_NW", "PC" = "Pacific_Coast",
    "PL" = "Plains", "RN" = "Rockies_North", "RS" = "Rockies_South"
  )
  region_name <- region_map[cfg$rpa_region]

  # Filter coefficients for region

  region_coefs <- coefs |> filter(region == region_name)

  if (nrow(region_coefs) == 0) {
    # No planting model available for this region
    cat(sprintf("  No planting model for region %s. Setting plant_prob = 0.\n",
                region_name))
    return(cond_data |> mutate(plant_prob = 0))
  }

  cond_data <- cond_data |>
    mutate(
      # Was the stand previously planted?
      planted_prev = as.integer(STDORGCD == 1),
      # Revenue variables (per acre, from harvest)
      rev_saw  = coalesce(rev_sawtimber, 0),
      rev_pulp = coalesce(rev_pulpwood, 0),
      # Slope dummy (1 if steep)
      slope_dum = as.integer(coalesce(SLOPE, 0) > 30),
      # Ownership mapping
      owner_plant = case_when(
        OWNGRPCD %in% c(1, 2, 3) ~ "public",
        OWNGRPCD == 4             ~ "other_private",
        TRUE                      ~ "commercial"
      )
    )

  # Apply model row by row
  cond_data <- cond_data |>
    rowwise() |>
    mutate(
      plant_prob = {
        mc <- region_coefs |>
          filter(
            (owner == owner_plant) |
            (owner == "private" & owner_plant %in% c("other_private", "commercial"))
          ) |>
          slice(1)

        if (nrow(mc) == 0) {
          0.05  # default low probability
        } else {
          xb <- mc$intercept +
                coalesce(mc$planted_prev, 0) * planted_prev +
                coalesce(mc$rev_sawtimber, 0) * rev_saw +
                coalesce(mc$rev_pulpwood, 0) * rev_pulp +
                coalesce(mc$slope_dummy, 0) * slope_dum

          exp(xb) / (1 + exp(xb))
        }
      }
    ) |>
    ungroup()

  return(cond_data)
}

# =============================================================================
# 3. Apply Planting Decision
# =============================================================================

#' Stochastically apply planting decisions to harvested plots
#' @param cond_data Harvested conditions with plant_prob
#' @param seed Random seed
#' @return Tibble with planted column and updated STDORGCD
apply_planting_decision <- function(cond_data, seed = 42) {

  set.seed(seed)

  cond_data |>
    mutate(
      # Draw random uniform for comparison with probability
      plant_draw = runif(n()),
      planted    = plant_draw < plant_prob,
      # Update stand origin code if planted
      STDORGCD_new = ifelse(planted, 1L, 0L)
    ) |>
    select(-plant_draw)
}

# =============================================================================
# 4. Planted Area Accounting
# =============================================================================

#' Compute planted area changes following harvest
#' Tracks gains (nonplanted -> planted) and losses (planted -> nonplanted)
#' @param pre_harvest Conditions before harvest (with STDORGCD)
#' @param post_plant Conditions after planting decision
#' @return Summary of planted area changes
compute_planted_area_change <- function(pre_harvest, post_plant) {

  changes <- post_plant |>
    mutate(
      was_planted = (STDORGCD == 1),
      now_planted = planted,
      gain = (!was_planted & now_planted),
      loss = (was_planted & !now_planted),
      net  = gain - loss
    )

  summary <- changes |>
    group_by(OWNGRPCD) |>
    summarise(
      n_harvested = n(),
      n_planted   = sum(now_planted),
      gains       = sum(gain),
      losses      = sum(loss),
      net_change  = sum(net),
      plant_rate  = mean(now_planted),
      .groups     = "drop"
    )

  return(summary)
}
