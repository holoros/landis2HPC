# =============================================================================
# Title: Economic Harvest Choice Model
# Author: A. Weiskittel
# Date: 2026-03-19
# Description: Implements the harvest choice logit model from Wear & Coulston
#              (2025, Forest Policy & Economics 178:103542). Models the
#              probability of harvest as a function of timber value, site
#              conditions, and ownership. Also estimates harvest intensity
#              and removal volumes.
# References:
#   Wear & Coulston (2025) Eqs. 1-6
#   Polyakov et al. (2010)
# Dependencies: 00_config.R, 01_data_prep.R
# =============================================================================

library(tidyverse)

# =============================================================================
# 1. Harvest Choice Model Coefficients
# =============================================================================

#' Default harvest choice model coefficients by region and ownership
#' From Wear & Coulston (2025) Tables 1 and 2
#' Model: Pr(h=1) = logit(intercept + beta*dVAL + gamma*var_val +
#'                         delta*slope + zeta*commercial + eta*planted)
get_default_harvest_coefficients <- function() {

  # Eastern regions (Table 1 from Wear & Coulston 2025)
  east <- tribble(
    ~region,       ~owner,     ~origin,   ~intercept, ~dval,   ~var_val, ~slope,   ~commercial, ~softshare,
    "Southeast",   "not_comm", "planted", -1.6551,    0.0018,  0.0000,   -0.0273,  NA,          NA,
    "Southeast",   "not_comm", "not",     -3.1530,    0.0006,  0.0000,   -0.9788,  NA,          NA,
    "Southeast",   "comm",     "planted", -0.4205,    0.0022,  0.0000,   -0.4777,  NA,          NA,
    "Southeast",   "comm",     "not",     -1.7671,    0.0005,  0.0000,   -0.9622,  NA,          NA,
    "South_Central","not_comm","planted", -0.5269,    0.0015,  0.0000,   -1.2541,  NA,          NA,
    "South_Central","not_comm","not",     -1.5456,    0.0006,  0.0000,   -0.1272,  NA,          NA,
    "South_Central","comm",    "planted", -0.7031,    0.0025,  0.4517,   -0.6251,  NA,          NA,
    "South_Central","comm",    "not",     -1.5711,    0.0008,  0.0000,   -0.5294,  NA,          NA,
    "Northeast",   "public",   "all",     -19.7336,   0.0026,  0.0000,   -1.5440,  NA,          -0.4488,
    "Northeast",   "otherpr",  "all",     -1.7846,    0.0017,  0.0000,   -0.4024,  NA,           0.0362,
    "Northeast",   "comm",     "all",     -1.5762,    0.0033,  0.0000,   -0.5855,  NA,          -0.2252,
    "North_Central","public",  "all",     -3.1664,    0.0015,  0.0000,   -0.2935,  NA,           0.2703,
    "North_Central","otherpr", "all",     -2.5115,    0.0023,  0.0000,   -0.5452,  NA,           0.6674,
    "North_Central","comm",    "all",     -17.8416,   0.0018,  0.0000,   -0.5245,  NA,           0.0692
  )

  # Western regions (Table 2)
  west <- tribble(
    ~region,          ~owner,    ~origin, ~intercept, ~dval,   ~var_val, ~slope,   ~commercial, ~planted,
    "Rockies_North",  "private", "all",   -2.4540,    0.0002,  0.0000,   -0.5267,  NA,           0.6700,
    "Rockies_North",  "public",  "all",   -3.4596,    0.0003,  0.0000,   -1.3216,  NA,           NA,
    "Rockies_South",  "private", "all",   -3.7930,    0.0008,  NA,       NA,       NA,           NA,
    "Rockies_South",  "public",  "all",   -2.8705,    0.0001,  NA,       -2.1545,  NA,           NA,
    "Pacific_NW",     "public",  "all",   -2.9211,    0.0001,  0.0000,   -0.7307,  NA,           0.9137,
    "Pacific_NW",     "private", "all",   -4.1572,    0.0004,  0.0000,   -0.1063,  NA,          -0.4562,
    "Pacific_Coast",  "public",  "all",   -2.2533,    0.0000,  NA,       -0.8818,  NA,           NA,
    "Pacific_Coast",  "private", "all",   -2.1305,    0.0001,  0.0000,   NA,       NA,           NA,
    "Plains",         "public",  "all",   -19.4865,   NA,      NA,       -2.5028,  NA,           NA,
    "Plains",         "private", "all",   -4.3209,    0.0012,  NA,       -0.9596,  NA,           NA
  )

  return(list(east = east, west = west))
}

# =============================================================================
# 2. Revenue and Value Calculations
# =============================================================================

#' Compute harvest revenue for a plot condition (Wear & Coulston eq. 5)
#' REV = p' * R(z) = b0 + b1*p*v(Z) + c'*Z + mu
#' @param cond_data Tibble of condition-level data
#' @param prices List with sawtimber and pulpwood prices by wood type
#' @return Tibble with revenue estimates appended
compute_harvest_revenue <- function(cond_data, prices) {

  # Layer 4 fix (15 May 2026): vol_sawtimber_* and vol_pulpwood_* columns are
  # in CUFT per acre (R/01_data_prep.R line ~178 builds them via TPA_UNADJ *
  # VOLCFNET summed by product/wood_type). Prices in R/00_config.R are
  # documented as $/MBF for sawtimber and $/cord for pulpwood. The prior
  # version multiplied cuft/ac directly by $/MBF and $/cord, inflating
  # revenue by approximately 200x for sawtimber and 80x for pulpwood. This
  # propagated to dVAL via predict_harvest_probability line 257 (dVAL =
  # REV_harvest as a Wear 2025 proxy) and saturated the logit term, producing
  # the 83 percent cycle 1 BAU harvest rate observed in the Layer 2/3 smokes.
  # Adding the cuft to MBF and cuft to cord conversions restores per acre
  # dollar magnitude in the right ballpark for Maine stumpage.
  MBF_per_CUFT  <- 1 / 200    # ~1 MBF per 200 cuft of net merchantable volume
  CORD_per_CUFT <- 1 / 80     # ~1 cord per 80 cuft of solid pulpwood volume

  cond_data |>
    mutate(
      # Revenue from sawtimber: cuft/ac * (1 MBF / 200 cuft) * $/MBF = $/ac
      rev_sawtimber = coalesce(vol_sawtimber_softwood, 0) * MBF_per_CUFT *
                        prices$sawtimber$softwood +
                      coalesce(vol_sawtimber_hardwood, 0) * MBF_per_CUFT *
                        prices$sawtimber$hardwood,
      # Revenue from pulpwood: cuft/ac * (1 cord / 80 cuft) * $/cord = $/ac
      rev_pulpwood  = coalesce(vol_pulpwood_softwood, 0) * CORD_per_CUFT *
                        prices$pulpwood$softwood +
                      coalesce(vol_pulpwood_hardwood, 0) * CORD_per_CUFT *
                        prices$pulpwood$hardwood,
      # Total harvest revenue (per acre, dollars)
      REV_harvest = rev_sawtimber + rev_pulpwood
    )
}

#' Compute expected ending inventory value (Wear & Coulston eq. 6)
#' EV = p' * v_{t+n,j}(z) = a0 + a1*p*v_j(Z) + d'*Z + epsilon
#' @param cond_data Condition data with T1 and T2 measurements
#' @param prices Price vector
#' @param harvested Logical vector indicating harvest
#' @return Expected ending values for harvest and no-harvest options
compute_ending_value <- function(cond_data, prices, harvested) {

  cond_data |>
    mutate(
      # Ending value is volume at time 2 * prices, per acre.
      # Layer 3 fix (15 May 2026): T2_volcfnet is already cuft/ac from
      # R/01_data_prep.R aggregation sum(TPA_UNADJ * VOLCFNET). The prior
      # version multiplied by tpa_live again, double counting the per acre
      # conversion. This inflated EV by ~tpa_live factor (~400 to 600x),
      # which propagated to dVAL and saturated the Wear 2025 logit, producing
      # the 83 percent cycle 1 harvest rate observed in the Layer 2 10 sim
      # smoke. Removing * tpa_live restores per acre dVAL magnitude.
      EV = coalesce(T2_volcfnet, volcfnet) * (
        prices$sawtimber$softwood * 0.5 + prices$pulpwood$softwood * 0.5
      )
    )
}

#' Compute differential value (dVAL) for harvest choice model
#' dVAL = |REV + (1+d)^-n * (EV_harvest - delta*EV_noharvest)|
#' Following Wear & Coulston (2025) eq. 3'
#' @param rev_harvest Revenue from harvest
#' @param ev_harvest Expected ending value if harvested
#' @param ev_noharvest Expected ending value if not harvested
#' @param discount_rate Annual discount rate
#' @param remper Remeasurement period (years)
#' @return Differential value
compute_dval <- function(rev_harvest, ev_harvest, ev_noharvest,
                         discount_rate = 0.04, remper = 5) {

  delta <- (1 + discount_rate)^(-remper)
  abs(rev_harvest + delta * (ev_harvest - ev_noharvest))
}

# =============================================================================
# 3. Harvest Probability Model
# =============================================================================

#' Predict harvest probability using the logistic choice model
#' Pr(h=1) = exp(f(z,p,v)) / (1 + exp(f(z,p,v)))
#' f = intercept + beta*dVAL + gamma*var_val + delta*slope + ...
#' @param cond_data Condition data with covariates
#' @param coefficients Model coefficients for the region/ownership
#' @param prices Timber prices
#' @param cfg Configuration
#' @return Tibble with harvest_prob column appended
predict_harvest_probability <- function(cond_data, coefficients = NULL,
                                        prices = NULL, cfg = CONFIG) {

  if (is.null(prices)) prices <- cfg$harvest$base_prices
  if (is.null(coefficients)) {
    coefficients <- get_default_harvest_coefficients()
  }

  # ---- Optional per-county harvest logit offset (R12) -------------------
  # Reads config/maine_county_harvest_logit_offset.csv when
  # cfg$harvest$use_county_harvest is TRUE. Adds a STATECD x COUNTYCD
  # additive term to the W&C 2025 logit intercept calibrated against
  # SAR by-county harvest rates.
  county_offset_lookup <- NULL
  if (isTRUE(cfg$harvest$use_county_harvest %||% FALSE)) {
    co_csv <- cfg$harvest$county_offset_csv %||%
              file.path(cfg$paths$config_dir %||% "config",
                        "maine_county_harvest_logit_offset.csv")
    if (file.exists(co_csv)) {
      county_offset_lookup <- read.csv(co_csv, stringsAsFactors = FALSE) |>
        as_tibble() |>
        select(STATECD, COUNTYCD, county_offset = beta_county_capped)
      cat(sprintf("  Per-county harvest offset enabled: %d county rows\n",
                  nrow(county_offset_lookup)))
    } else {
      warning(sprintf("use_county_harvest TRUE but %s not found", co_csv))
    }
  }

  # ---- Optional HCB landowner stratification (R14) ----------------------
  # When cfg$harvest$use_owner_stratification is TRUE, joins each plot's
  # Harris-Caputo-Butler owner class (from fia_plots_with_owner.csv) and
  # applies owner-class harvest probability multipliers from
  # owner_class_legend.csv. Multipliers are calibrated against Maine
  # SAR by-owner harvest behavior:
  #   Class 3 (NIPF / family forest)             multiplier 0.5
  #   Class 4 (Corporate / industrial)           multiplier 1.5
  #   Class 5 (Tribal)                           multiplier 0.2
  #   Class 6 (Federal)                          multiplier 0.2
  #   Class 7 (State / Public Reserved)          multiplier 0.5
  #   Class 8 (Local / town forest)              multiplier 0.3
  owner_lookup <- NULL
  owner_mult_lookup <- NULL
  if (isTRUE(cfg$harvest$use_owner_stratification %||% FALSE)) {
    cfg_dir <- cfg$paths$config_dir %||% "config"
    owner_csv  <- file.path(cfg_dir, "fia_plots_with_owner.csv")
    legend_csv <- file.path(cfg_dir, "owner_class_legend.csv")
    if (file.exists(owner_csv) && file.exists(legend_csv)) {
      owner_lookup <- read.csv(owner_csv, stringsAsFactors = FALSE) |>
        as_tibble() |>
        select(STATECD, COUNTYCD, PLOT, hcb_class) |>
        distinct()
      legend <- read.csv(legend_csv, stringsAsFactors = FALSE) |>
        as_tibble()
      # Default behavioural multipliers if legend doesn't carry them
      if (!"harvest_mult" %in% names(legend)) {
        legend$harvest_mult <- c(
          1.0, 0.0, 0.0,    # 0 unknown (no scaling), 1 nonforest, 2 water
          0.5, 1.5, 0.2, 0.2, 0.5, 0.3   # 3 NIPF, 4 Corp, 5 Trib, 6 Fed, 7 State, 8 Local
        )[match(legend$hcb_class, 0:8)]
      }
      owner_mult_lookup <- legend |>
        select(hcb_class, owner_harvest_mult = harvest_mult)
      cat(sprintf("  HCB landowner stratification enabled: %d plot-owner rows; %d class multipliers\n",
                  nrow(owner_lookup), nrow(owner_mult_lookup)))
    } else {
      warning(sprintf("use_owner_stratification TRUE but %s or %s missing",
                      owner_csv, legend_csv))
    }
  }

  # Select appropriate coefficients based on region
  region <- cfg$rpa_region
  region_map <- c(
    "NE" = "Northeast", "NC" = "North_Central",
    "SE" = "Southeast", "SC" = "South_Central",
    "PNW" = "Pacific_NW", "PC" = "Pacific_Coast",
    "PL" = "Plains", "RN" = "Rockies_North", "RS" = "Rockies_South"
  )
  region_name <- region_map[region]

  # Determine if East or West
  east_regions <- c("Northeast", "North_Central", "Southeast", "South_Central")
  if (region_name %in% east_regions) {
    coefs <- coefficients$east |> filter(region == region_name)
  } else {
    coefs <- coefficients$west |> filter(region == region_name)
  }

  # Compute revenues first
  cond_data <- compute_harvest_revenue(cond_data, prices)

  # Map ownership to coefficient categories
  cond_data <- cond_data |>
    mutate(
      owner_cat = case_when(
        OWNGRPCD == 1 ~ "public",
        OWNGRPCD == 2 ~ "public",
        OWNGRPCD == 3 ~ "public",
        OWNGRPCD == 4 ~ "otherpr",   # default private
        TRUE          ~ "otherpr"
      ),
      # Compute dVAL (simplified: using revenue as proxy)
      dVAL = REV_harvest,
      # Variance in value across species classes
      var_val_use = coalesce(var_val, 0),
      # Slope (proxy: use SLOPE from condition data if available)
      slope_val = coalesce(SLOPE, 0),
      # Commercial dummy
      is_commercial = as.integer(owner_cat == "comm"),
      # Planted dummy
      is_planted = as.integer(STDORGCD == 1),
      # Softwood share
      sw_share = coalesce(vol_sawtimber_softwood + vol_pulpwood_softwood, 0) /
                 pmax(coalesce(REV_harvest, 1), 1)
    )

  # Merge per-county logit offset (R12). NA where no match (offset 0).
  if (!is.null(county_offset_lookup) && all(c("STATECD", "COUNTYCD") %in% names(cond_data))) {
    cond_data <- cond_data |>
      left_join(county_offset_lookup, by = c("STATECD", "COUNTYCD")) |>
      mutate(county_offset = coalesce(county_offset, 0))
  } else {
    cond_data <- cond_data |> mutate(county_offset = 0)
  }

  # Merge HCB owner class (R14). NA hcb_class -> Class 3 (NIPF default).
  if (!is.null(owner_lookup) && all(c("STATECD", "COUNTYCD", "PLOT") %in% names(cond_data))) {
    cond_data <- cond_data |>
      left_join(owner_lookup, by = c("STATECD", "COUNTYCD", "PLOT")) |>
      mutate(hcb_class = coalesce(hcb_class, 3L)) |>     # default NIPF
      left_join(owner_mult_lookup, by = "hcb_class") |>
      mutate(owner_harvest_mult = coalesce(owner_harvest_mult, 1.0))
  } else {
    cond_data <- cond_data |> mutate(owner_harvest_mult = 1.0,
                                     hcb_class = NA_integer_)
  }

  # Apply logistic model
  # For each condition, find matching coefficients and compute probability
  cond_data <- cond_data |>
    rowwise() |>
    mutate(
      harvest_prob = {
        # Find best matching coefficient row
        matching_coefs <- coefs |>
          filter(
            (owner == owner_cat) |
            (owner == "not_comm" & owner_cat != "comm") |
            (owner == "private" & owner_cat %in% c("otherpr", "comm"))
          )

        if (nrow(matching_coefs) == 0) {
          # Fallback: use first available
          matching_coefs <- coefs |> slice(1)
        }

        # Use first match
        mc <- matching_coefs |> slice(1)

        # Linear predictor (W&C 2025) plus optional county offset (R12)
        xb <- mc$intercept +
              coalesce(county_offset, 0) +
              coalesce(mc$dval, 0) * dVAL +
              coalesce(mc$var_val, 0) * var_val_use +
              coalesce(mc$slope, 0) * slope_val

        # Add optional terms
        if ("softshare" %in% names(mc) && !is.na(mc$softshare)) {
          xb <- xb + mc$softshare * sw_share
        }

        # Logistic transform
        exp(xb) / (1 + exp(xb))
      }
    ) |>
    ungroup()

  # Apply HCB owner-class multiplier (R14) before existing landowner logic.
  # Capped at 1.0 to remain a valid probability.
  cond_data <- cond_data |>
    mutate(harvest_prob = pmin(harvest_prob *
                               coalesce(owner_harvest_mult, 1.0), 1.0))

  # Apply landowner behavior multipliers
  if (!is.null(cfg$landowner$harvest_propensity)) {
    cond_data <- cond_data |>
      mutate(
        owner_label = case_when(
          OWNGRPCD %in% c(1, 2, 3) ~ "public",
          OWNGRPCD == 4             ~ "family",
          TRUE                      ~ "other_private"
        ),
        propensity_mult = map_dbl(owner_label, ~ {
          cfg$landowner$harvest_propensity[[.x]] %||% 1.0
        }),
        # Adjust probability (cap at 1.0)
        harvest_prob_adj = pmin(harvest_prob * propensity_mult, 1.0)
      )
  }

  return(cond_data)
}

# =============================================================================
# 4. Harvest Intensity Model
# =============================================================================

#' Predict harvest intensity (proportion of volume removed)
#' Based on Wear & Coulston (2025) Fig. 5 distributions
#' @param cond_data Condition data for harvested plots
#' @param region RPA region code
#' @return Tibble with harvest_intensity column
predict_harvest_intensity <- function(cond_data, region = "NE") {

  # Region-specific mean harvest intensities by ownership
  # From Wear & Coulston (2025) Fig. 5 summary
  intensity_params <- tribble(
    ~region, ~owner,       ~mean_intensity, ~sd_intensity,
    "NE",    "public",     0.35,            0.20,
    "NE",    "family",     0.45,            0.25,
    "NE",    "commercial", 0.55,            0.25,
    "NC",    "public",     0.40,            0.20,
    "NC",    "family",     0.50,            0.25,
    "NC",    "commercial", 0.60,            0.25,
    "SE",    "public",     0.55,            0.25,
    "SE",    "family",     0.65,            0.20,
    "SE",    "commercial", 0.85,            0.15,
    "SC",    "public",     0.55,            0.25,
    "SC",    "family",     0.65,            0.20,
    "SC",    "commercial", 0.85,            0.15,
    "PNW",   "public",     0.57,            0.25,
    "PNW",   "family",     0.55,            0.30,
    "PNW",   "commercial", 0.95,            0.10
  )

  cond_data |>
    mutate(
      owner_broad = case_when(
        OWNGRPCD %in% c(1, 2, 3) ~ "public",
        OWNGRPCD == 4             ~ "family",
        TRUE                      ~ "commercial"
      )
    ) |>
    left_join(
      intensity_params |> filter(region == !!region),
      by = c("owner_broad" = "owner")
    ) |>
    mutate(
      # Draw intensity from truncated normal distribution
      mean_intensity = coalesce(mean_intensity, 0.50),
      sd_intensity   = coalesce(sd_intensity, 0.25),
      harvest_intensity = pmin(pmax(
        rnorm(n(), mean_intensity, sd_intensity), 0.05), 1.0)
    )
}

# =============================================================================
# 5. Removal Volume Estimation
# =============================================================================

#' Estimate removal volumes by product class (Wear & Coulston eq. 8)
#' R_m = b0 + b1*v + c'*Z + mu
#' @param cond_data Harvested condition data with intensity
#' @param prices Price vector
#' @return Tibble with sawtimber and pulpwood removal volumes
estimate_removals <- function(cond_data, prices = NULL) {

  cond_data |>
    mutate(
      # Total removal volume (cuft/acre): volcfnet is already per acre from
      # R/01_data_prep.R line 149 sum(TPA_UNADJ * VOLCFNET). The prior version
      # multiplied by tpa_live again, double counting the per acre conversion
      # and inflating vol_removed_total by ~tpa_live (~400 to 600x for ME).
      # Patch applied 13 May 2026 per docs/GR_RATIO_LAYER2_AUDIT.md.
      vol_removed_total = volcfnet * harvest_intensity,

      # Split into sawtimber and pulpwood based on standing inventory composition
      saw_fraction = coalesce(
        (vol_sawtimber_softwood + vol_sawtimber_hardwood) /
        pmax(volcfnet, 1), 0.3),

      vol_removed_sawtimber = vol_removed_total * saw_fraction,
      vol_removed_pulpwood  = vol_removed_total * (1 - saw_fraction),

      # Revenue from removals
      removal_revenue = coalesce(vol_removed_sawtimber, 0) *
                          coalesce(prices$sawtimber$softwood, 250) +
                        coalesce(vol_removed_pulpwood, 0) *
                          coalesce(prices$pulpwood$softwood, 12)
    )
}
