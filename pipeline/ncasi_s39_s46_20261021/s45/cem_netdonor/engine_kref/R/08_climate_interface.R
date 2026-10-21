# =============================================================================
# Title: Climate Data Interface
# Author: A. Weiskittel
# Date: 2026-03-19
# Description: Generic climate data interface with optional CMIP6/ClimateNA
#              integration. Provides climate variables for CEM matching and
#              disturbance probability adjustment.
# Dependencies: 00_config.R
# =============================================================================

library(tidyverse)

# =============================================================================
# 1. Generic Climate Data Interface
# =============================================================================

#' Read climate data from a generic CSV file
#' Expected columns: plot_id (or lat/lon), year, mat, map, cmd, dd5, ...
#' @param file_path Path to climate CSV
#' @return Tibble of climate records
read_climate_generic <- function(file_path) {

  if (is.null(file_path) || !file.exists(file_path)) {
    warning("Climate data file not found: ", file_path)
    return(NULL)
  }

  climate <- read_csv(file_path, show_col_types = FALSE)

  # Validate required columns
 required <- c("year")
  optional_id <- c("plot_id", "lat", "lon", "STATECD", "COUNTYCD", "PLOT")
  optional_vars <- c("mat", "map", "cmd", "dd5", "tmin_wt", "tmax_sm",
                      "precip_sm", "aet", "pet", "vpd")

  has_id <- any(optional_id %in% names(climate))
  if (!"year" %in% names(climate)) {
    stop("Climate file must contain 'year' column")
  }
  if (!has_id) {
    stop("Climate file must contain at least one of: ",
         paste(optional_id, collapse = ", "))
  }

  # Identify available climate variables
  available_vars <- intersect(optional_vars, names(climate))
  cat(sprintf("  Climate variables available: %s\n",
              paste(available_vars, collapse = ", ")))

  return(climate)
}

# =============================================================================
# 2. ClimateNA Integration
# =============================================================================

#' Download and format climate normals from ClimateNA
#' Requires ClimateNA to be installed locally or accessed via API
#' @param locations Tibble with lat, lon, elev columns
#' @param scenarios Character vector of climate scenarios
#' @param periods Character vector of time periods (e.g., "2025", "2055")
#' @param climatena_path Path to ClimateNA executable (if local)
#' @return Tibble of climate projections
get_climatena_projections <- function(locations, scenarios = "ssp245",
                                      periods = c("2025", "2055", "2085"),
                                      climatena_path = NULL) {

  cat("ClimateNA integration...\n")

  # Prepare input file for ClimateNA
  input <- locations |>
    transmute(
      ID1 = row_number(),
      ID2 = 1,
      lat = lat,
      long = lon,
      el = elev
    )

  # Write input file
  input_file <- tempfile(fileext = ".csv")
  write_csv(input, input_file)

  if (!is.null(climatena_path) && file.exists(climatena_path)) {
    # Run ClimateNA locally
    cat("  Running ClimateNA locally...\n")
    # This would invoke the ClimateNA executable
    # Placeholder for actual ClimateNA system call
    warning("Local ClimateNA execution not yet implemented. ",
            "Please use the generic interface with pre-processed data.")
    return(NULL)
  } else {
    cat("  ClimateNA not found. Use generic interface with pre-processed data.\n")
    cat("  To generate data:\n")
    cat("    1. Download ClimateNA from https://climatena.ca\n")
    cat("    2. Export plot locations with columns: ID1, ID2, lat, long, el\n")
    cat("    3. Run ClimateNA for desired scenarios and periods\n")
    cat("    4. Save output as CSV and set cfg$climate$data_file\n")
    return(NULL)
  }
}

# =============================================================================
# 3. MACA Downscaled CMIP6 Data
# =============================================================================

#' Fetch MACA downscaled climate data for plot locations
#' @param locations Tibble with lat, lon columns
#' @param variable Climate variable (e.g., "tasmax", "pr")
#' @param scenario SSP scenario
#' @param model GCM model name
#' @param years Year range
#' @return Tibble of climate values
fetch_maca_data <- function(locations, variable = "tasmax",
                            scenario = "ssp245", model = "CanESM5",
                            years = c(2025, 2070)) {

  # MACA data access via OPeNDAP or direct download
  # This is a placeholder for the actual data access implementation
  cat("  MACA data access requires the 'ncdf4' and 'terra' packages.\n")
  cat("  For production use, pre-download MACA data and use generic interface.\n")

  # Example URL pattern for MACA v2
  # base_url <- "http://thredds.northwestknowledge.net:8080/thredds/dodsC/"
  # file_pattern <- sprintf("agg_macav2metdata_%s_%s_r1i1p1f1_%s_CONUS_daily.nc",
  #                         variable, model, scenario)

  return(NULL)
}

# =============================================================================
# 4. Climate-Condition Matching
# =============================================================================

#' Join climate data to FIA plot conditions
#' @param cond_data Condition records with LAT, LON, INVYR
#' @param climate_data Climate tibble
#' @param cfg Configuration
#' @return Conditions with climate variables appended
join_climate_to_conditions <- function(cond_data, climate_data, cfg) {

  if (is.null(climate_data)) {
    cat("  No climate data available. Proceeding without climate matching.\n")
    return(cond_data)
  }

  # Determine join method based on available columns
  if ("plot_id" %in% names(climate_data) && "PLT_CN" %in% names(cond_data)) {
    # Direct plot ID join
    cond_data <- cond_data |>
      left_join(
        climate_data,
        by = c("PLT_CN" = "plot_id", "INVYR" = "year")
      )
  } else if (all(c("STATECD", "COUNTYCD", "PLOT") %in% names(climate_data))) {
    # Join by state/county/plot
    cond_data <- cond_data |>
      left_join(
        climate_data,
        by = c("STATECD", "COUNTYCD", "PLOT", "INVYR" = "year")
      )
  } else if (all(c("lat", "lon") %in% names(climate_data))) {
    # Nearest neighbor spatial join
    cat("  Performing spatial nearest-neighbor climate join...\n")
    cond_data <- nearest_neighbor_climate_join(cond_data, climate_data)
  }

  # Report coverage
  climate_vars <- intersect(cfg$climate$match_vars, names(cond_data))
  n_with_climate <- sum(complete.cases(cond_data[, climate_vars]))
  cat(sprintf("  Climate data joined: %d/%d conditions have climate (%.1f%%)\n",
              n_with_climate, nrow(cond_data),
              100 * n_with_climate / nrow(cond_data)))

  return(cond_data)
}

#' Spatial nearest-neighbor join for climate data
#' @param cond_data Conditions with LAT, LON
#' @param climate_data Climate data with lat, lon
#' @return Conditions with nearest climate values
nearest_neighbor_climate_join <- function(cond_data, climate_data) {

  if (!requireNamespace("sf", quietly = TRUE)) {
    warning("Package 'sf' required for spatial join. Using approximate matching.")
    # Fallback: round lat/lon and merge
    cond_data <- cond_data |>
      mutate(lat_r = round(LAT, 1), lon_r = round(LON, 1))
    climate_data <- climate_data |>
      mutate(lat_r = round(lat, 1), lon_r = round(lon, 1))
    return(
      cond_data |>
        left_join(climate_data, by = c("lat_r", "lon_r")) |>
        select(-lat_r, -lon_r)
    )
  }

  library(sf)

  # Convert to sf objects
  cond_sf <- st_as_sf(cond_data |> filter(!is.na(LAT), !is.na(LON)),
                       coords = c("LON", "LAT"), crs = 4326)
  clim_sf <- st_as_sf(climate_data |> filter(!is.na(lat), !is.na(lon)),
                       coords = c("lon", "lat"), crs = 4326)

  # Nearest neighbor join
  nn_idx <- st_nearest_feature(cond_sf, clim_sf)

  # Extract climate values
  climate_cols <- setdiff(names(climate_data), c("lat", "lon", "year"))
  for (col in climate_cols) {
    cond_data[[col]] <- NA
    cond_data[[col]][!is.na(cond_data$LAT)] <- climate_data[[col]][nn_idx]
  }

  return(cond_data)
}

# =============================================================================
# 5. Climate-Adjusted Disturbance Probabilities
# =============================================================================

#' Adjust disturbance probabilities based on climate change
#' @param base_rates Named list of base annual disturbance rates
#' @param delta_temp Temperature change from baseline (degrees C)
#' @param sensitivity Named list of sensitivity multipliers per degree
#' @return Adjusted disturbance rates
adjust_disturbance_rates <- function(base_rates, delta_temp,
                                      sensitivity = NULL) {

  if (is.null(sensitivity)) {
    sensitivity <- list(fire = 0.10, insect = 0.05, wind = 0.02)
  }

  adjusted <- base_rates
  for (dist_type in names(base_rates)) {
    if (dist_type %in% names(sensitivity)) {
      multiplier <- 1.0 + sensitivity[[dist_type]] * delta_temp
      adjusted[[dist_type]] <- base_rates[[dist_type]] * max(multiplier, 0)
    }
  }

  return(adjusted)
}

# =============================================================================
# 6. Get Climate for Projection Year
# =============================================================================

#' Retrieve or interpolate climate data for a target projection year
#' @param cfg Configuration
#' @param target_year Target year for projection
#' @param scenario Scenario specification
#' @return Climate data tibble
get_climate_for_year <- function(cfg, target_year, scenario = NULL) {

  if (!cfg$climate$use_climate) return(NULL)

  climate_data <- read_climate_generic(cfg$climate$data_file)
  if (is.null(climate_data)) return(NULL)

  # Filter or interpolate to target year
  available_years <- unique(climate_data$year)

  if (target_year %in% available_years) {
    return(climate_data |> filter(year == target_year))
  }

  # Interpolate between nearest available years
  lower_year <- max(available_years[available_years <= target_year],
                    na.rm = TRUE)
  upper_year <- min(available_years[available_years >= target_year],
                    na.rm = TRUE)

  if (is.infinite(lower_year) || is.infinite(upper_year)) {
    # Use nearest available
    nearest <- available_years[which.min(abs(available_years - target_year))]
    return(climate_data |> filter(year == nearest))
  }

  # Linear interpolation
  weight <- (target_year - lower_year) / (upper_year - lower_year)
  climate_vars <- intersect(cfg$climate$match_vars, names(climate_data))

  lower_data <- climate_data |> filter(year == lower_year)
  upper_data <- climate_data |> filter(year == upper_year)

  interpolated <- lower_data
  for (v in climate_vars) {
    if (v %in% names(interpolated) && v %in% names(upper_data)) {
      interpolated[[v]] <- lower_data[[v]] * (1 - weight) +
                           upper_data[[v]] * weight
    }
  }
  interpolated$year <- target_year

  return(interpolated)
}
