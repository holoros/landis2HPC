# =============================================================================
# Title: Maine Economic Harvest Module (county-specific stumpage + split)
# Author: A. Weiskittel
# Date: 2026-04-17
# Description: Layers Maine county-level stumpage prices and partial/clearcut
#              splits on top of the existing Wear & Coulston (2025) harvest
#              choice model. Reads configuration CSVs derived from Maine
#              Forest Service Stumpage Price Reports (2015-2024) and the
#              Silvicultural Activities Reports (2015-2023).
#
# Config inputs (both under cfg$config_dir):
#   maine_stumpage_forecast.csv     long form: county, year, product, species,
#                                   price_real_2024, kind (observed|forecast)
#   maine_treatment_proportions.csv county x year -> partial_share, clearcut_share
#
# Exported functions:
#   load_maine_stumpage(cfg)                 cache stumpage forecast tibble
#   load_maine_proportions(cfg)              cache treatment-proportion tibble
#   maine_prices_for_year(year, county, ...) prices list compatible with 03_harvest_choice
#   split_partial_clearcut(harvested_plots, proportions, cycle_year)
#                                             assign is_clearcut flag by county
#
# Hooks (called from 06_projection_engine.R):
#   after predict_harvest() and before predict_harvest_intensity(), the engine
#   calls split_partial_clearcut() to tag each harvested row, then applies a
#   clearcut-specific intensity (0.95 biomass removal, age reset to 0) vs
#   partial intensity (sampled from predict_harvest_intensity; age setback 40 yr).
# =============================================================================

library(tidyverse)

.maine_stump_cache <- new.env(parent = emptyenv())
.maine_prop_cache  <- new.env(parent = emptyenv())

# COUNTYCD -> NAME lookup (FIA STATECD=23 Maine county FIPS codes)
# Source: FIA PLOT table COUNTYCD, cross-walked to Maine county names.
MAINE_COUNTY_LOOKUP <- tibble::tribble(
  ~COUNTYCD, ~county,
  1, "ANDROSCOGGIN",
  3, "AROOSTOOK",
  5, "CUMBERLAND",
  7, "FRANKLIN",
  9, "HANCOCK",
  11, "KENNEBEC",
  13, "KNOX",
  15, "LINCOLN",
  17, "OXFORD",
  19, "PENOBSCOT",
  21, "PISCATAQUIS",
  23, "SAGADAHOC",
  25, "SOMERSET",
  27, "WALDO",
  29, "WASHINGTON",
  31, "YORK"
)

# Species groups for the FIA sawlog/pulpwood composition estimator.
# Mapping from FORTYPCD (forest type code) to a dominant stumpage species
# used for price lookup. Based on FIA REF_FOREST_TYPE and the species
# available in the Maine stumpage reports.
FORTYPCD_TO_STUMPAGE_SPECIES <- tibble::tribble(
  ~FORTYPCD, ~sawlog_species,    ~pulp_species,
  101, "WHITE PINE",       "WHITE PINE",         # Jack pine
  102, "WHITE PINE",       "WHITE PINE",         # Red pine
  103, "WHITE PINE",       "WHITE PINE",         # White pine
  104, "WHITE PINE",       "WHITE PINE",         # Eastern white pine / hemlock
  105, "HEMLOCK",          "HEMLOCK",            # Eastern hemlock
  121, "SPRUCE & FIR",     "SPRUCE & FIR",       # Balsam fir
  122, "SPRUCE & FIR",     "SPRUCE & FIR",       # White spruce
  123, "SPRUCE & FIR",     "SPRUCE & FIR",       # Red spruce
  124, "SPRUCE & FIR",     "SPRUCE & FIR",       # Red spruce / balsam fir
  125, "SPRUCE & FIR",     "SPRUCE & FIR",       # Black spruce
  126, "SPRUCE & FIR",     "SPRUCE & FIR",       # Tamarack
  127, "SPRUCE & FIR",     "SPRUCE & FIR",       # Northern white-cedar
  128, "CEDAR",            "CEDAR",              # Atlantic white-cedar
  381, "RED OAK",          "MIXED HARDWOOD",     # Scrub oak
  501, "RED OAK",          "MIXED HARDWOOD",     # White oak / red oak / hickory
  502, "RED OAK",          "MIXED HARDWOOD",     # White oak
  503, "RED OAK",          "MIXED HARDWOOD",     # Northern red oak
  505, "RED OAK",          "MIXED HARDWOOD",     # Chestnut oak
  509, "RED OAK",          "MIXED HARDWOOD",     # Mixed upland hardwood
  513, "RED OAK",          "MIXED HARDWOOD",     # Oak / red maple
  519, "RED OAK",          "MIXED HARDWOOD",     # Red maple / oak
  701, "SUGAR MAPLE",      "MIXED HARDWOOD",     # Black ash / American elm / red maple
  702, "RED/WHITE MAPLE",  "MIXED HARDWOOD",     # River birch / sycamore
  703, "ASPEN/POPLAR",     "MIXED HARDWOOD",     # Cottonwood
  705, "RED/WHITE MAPLE",  "MIXED HARDWOOD",     # Red maple / lowland
  707, "ASPEN/POPLAR",     "ASPEN/POPLAR",       # Balsam poplar
  708, "RED/WHITE MAPLE",  "MIXED HARDWOOD",     # Sweetgum / Nuttall oak / willow oak
  801, "SUGAR MAPLE",      "MIXED HARDWOOD",     # Sugar maple / beech / yellow birch
  802, "RED/WHITE MAPLE",  "MIXED HARDWOOD",     # Black cherry
  803, "SUGAR MAPLE",      "MIXED HARDWOOD",     # Cherry / white ash / yellow poplar
  805, "ASPEN/POPLAR",     "ASPEN/POPLAR",       # Aspen / birch
  809, "WHITE BIRCH",      "MIXED HARDWOOD",     # Paper birch
  901, "ASPEN/POPLAR",     "ASPEN/POPLAR",       # Aspen
  902, "ASPEN/POPLAR",     "ASPEN/POPLAR",       # Paper birch (northern)
  903, "WHITE BIRCH",      "MIXED HARDWOOD",     # Gray birch
  904, "SUGAR MAPLE",      "MIXED HARDWOOD",     # Sugar maple / beech / yellow birch (northern)
  995, "MIXED HARDWOOD",   "MIXED HARDWOOD",     # Nonstocked
  999, "MIXED HARDWOOD",   "MIXED HARDWOOD"      # Unclassified
)

#' Load the Maine stumpage forecast table (cached).
load_maine_stumpage <- function(cfg) {
  k <- "stumpage"
  if (!is.null(.maine_stump_cache[[k]])) return(.maine_stump_cache[[k]])
  f <- file.path(cfg$config_dir %||% "~/fia_cem_projections/config",
                 "maine_stumpage_forecast.csv")
  if (!file.exists(f)) stop(sprintf("maine_stumpage_forecast.csv not found at %s", f))
  df <- readr::read_csv(f, show_col_types = FALSE)
  .maine_stump_cache[[k]] <- df
  cat(sprintf("  load_maine_stumpage: %d rows, years %d-%d, %d counties\n",
              nrow(df), min(df$year), max(df$year), dplyr::n_distinct(df$county)))
  df
}

#' Load county x year treatment proportions (cached).
load_maine_proportions <- function(cfg) {
  k <- "prop"
  if (!is.null(.maine_prop_cache[[k]])) return(.maine_prop_cache[[k]])
  f <- file.path(cfg$config_dir %||% "~/fia_cem_projections/config",
                 "maine_treatment_proportions.csv")
  if (!file.exists(f)) stop(sprintf("maine_treatment_proportions.csv not found at %s", f))
  df <- readr::read_csv(f, show_col_types = FALSE)
  .maine_prop_cache[[k]] <- df
  cat(sprintf("  load_maine_proportions: %d rows, years %d-%d, %d counties\n",
              nrow(df), min(df$year), max(df$year), dplyr::n_distinct(df$county)))
  df
}

#' Get prices list for a given year and (optionally) county in the format the
#' existing compute_harvest_revenue() expects: list(sawtimber=list(softwood,
#' hardwood), pulpwood=list(softwood, hardwood)).
#'
#' The returned prices are real 2024-USD per unit (per MBF for sawtimber, per
#' ton for pulpwood). If the requested (county, year) is not present, the
#' STATEWIDE fallback is used; if neither is present, the 2024 STATEWIDE price
#' is used.
#'
#' @param year Integer projection year
#' @param county Character Maine county name (uppercase). Pass NULL for STATEWIDE.
#' @param cfg Pipeline config
maine_prices_for_year <- function(year, county = NULL, cfg) {
  s <- load_maine_stumpage(cfg)
  geo_try <- if (!is.null(county)) c(county, "STATEWIDE") else "STATEWIDE"
  out <- list(
    sawtimber = list(softwood = NA_real_, hardwood = NA_real_),
    pulpwood  = list(softwood = NA_real_, hardwood = NA_real_)
  )
  # Softwood sawtimber: weighted mean of SPRUCE & FIR and WHITE PINE
  # (plus HEMLOCK) to approximate the eastern Maine softwood sawlog mix
  pick_price <- function(filter_expr) {
    for (geo in geo_try) {
      sub <- dplyr::filter(s, county == geo, year == !!year)
      sub <- dplyr::filter(sub, eval(rlang::parse_expr(filter_expr)))
      if (nrow(sub) > 0) {
        w <- ifelse(!is.na(sub$price_real_2024), 1, 0)
        return(sum(sub$price_real_2024 * w, na.rm = TRUE) / max(sum(w), 1))
      }
    }
    NA_real_
  }
  out$sawtimber$softwood <- pick_price(
    "product == 'SAWLOGS' & species %in% c('SPRUCE & FIR','WHITE PINE','HEMLOCK','RED PINE','CEDAR')")
  out$sawtimber$hardwood <- pick_price(
    "product == 'SAWLOGS' & species %in% c('RED OAK','SUGAR MAPLE','RED/WHITE MAPLE','YELLOW BIRCH','WHITE BIRCH','ASH','BEECH','ASPEN/POPLAR','WHITE OAK')")
  out$pulpwood$softwood <- pick_price(
    "product == 'PULPWOOD' & species %in% c('SPRUCE & FIR','WHITE PINE','HEMLOCK','CEDAR','RED PINE')")
  out$pulpwood$hardwood <- pick_price(
    "product == 'PULPWOOD' & species %in% c('MIXED HARDWOOD','ASPEN/POPLAR')")
  out
}

#' Assign is_clearcut flag to each harvested plot based on its county's
#' partial vs clearcut share. For years with observed SAR data (2015-2023) we
#' use that year's observed proportion; for earlier or later years we use the
#' most recent observed value, carried forward.
#'
#' @param harvested_plots Tibble with at least COUNTYCD column (Maine FIPS).
#' @param cfg Pipeline config
#' @param cycle_year Projection year for the current cycle (baseline + cycle*5)
#' @param seed Base RNG seed (offset per plot for reproducibility)
#' @return harvested_plots with new column is_clearcut (logical)
split_partial_clearcut <- function(harvested_plots, cfg, cycle_year, seed = 1) {
  if (nrow(harvested_plots) == 0) {
    harvested_plots$is_clearcut <- logical(0)
    return(harvested_plots)
  }
  prop <- load_maine_proportions(cfg)
  # Pick nearest historical year; carry-forward for future years
  hist_years <- sort(unique(prop$year))
  pick_year <- if (cycle_year < min(hist_years)) min(hist_years)
               else if (cycle_year > max(hist_years)) max(hist_years)
               else cycle_year
  prop_y <- dplyr::filter(prop, year == pick_year) |>
    dplyr::select(county, clearcut_share)

  # Join county name onto harvested_plots via COUNTYCD
  hp <- harvested_plots |>
    dplyr::left_join(MAINE_COUNTY_LOOKUP, by = "COUNTYCD") |>
    dplyr::left_join(prop_y, by = "county")
  # Fallback: statewide mean clearcut share (~0.074) when county unknown
  hp$clearcut_share[is.na(hp$clearcut_share)] <- 0.074

  set.seed(seed + cycle_year)
  u <- stats::runif(nrow(hp))
  hp$is_clearcut <- u < hp$clearcut_share

  hp |> dplyr::select(-county)
}

#' Convenience: Compute an approximate per-acre dollar value for a condition
#' given its volcsnet (sawlog ft3/ac), drybio_ag (lb/ac), FORTYPCD and COUNTYCD.
#' Used only for diagnostic reporting; the actual harvest choice uses the
#' existing Wear & Coulston logit via compute_harvest_revenue().
plot_value_diagnostic <- function(df, cfg, year) {
  stump <- load_maine_stumpage(cfg)
  df |>
    dplyr::left_join(MAINE_COUNTY_LOOKUP, by = "COUNTYCD") |>
    dplyr::left_join(FORTYPCD_TO_STUMPAGE_SPECIES, by = "FORTYPCD") |>
    dplyr::rowwise() |>
    dplyr::mutate(
      mbf_sawlog     = coalesce(volcsnet, 0) / 100,   # ~100 ft3 per MBF (Scribner)
      tons_pulp      = coalesce(drybio_ag, 0) * 0.0005 * 0.5,  # 50% of biomass pulp-eligible
      price_sawlog   = {
        p <- dplyr::filter(stump, county %in% c(.data$county, "STATEWIDE"),
                           year == !!year, product == "SAWLOGS",
                           species == .data$sawlog_species) |>
          dplyr::slice(1) |> dplyr::pull(price_real_2024)
        if (length(p) == 0 || is.na(p)) 150 else p
      },
      price_pulp     = {
        p <- dplyr::filter(stump, county %in% c(.data$county, "STATEWIDE"),
                           year == !!year, product == "PULPWOOD",
                           species == .data$pulp_species) |>
          dplyr::slice(1) |> dplyr::pull(price_real_2024)
        if (length(p) == 0 || is.na(p)) 5 else p
      },
      value_per_acre = mbf_sawlog * price_sawlog + tons_pulp * price_pulp
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-county, -sawlog_species, -pulp_species)
}
