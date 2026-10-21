# =============================================================================
# Title: FIA Data Preparation Module
# Author: A. Weiskittel
# Date: 2026-03-19
# Description: Downloads, reads, and prepares FIA data for CEM plot matching.
#              Supports both rFIA package and direct CSV/SQLite access.
#              Builds the subject plot pool and remeasured donor plot pool.
# Dependencies: 00_config.R
# =============================================================================

# --- Libraries ---------------------------------------------------------------
library(tidyverse)
library(data.table)

# =============================================================================
# 1. FIA Data Access Functions
# =============================================================================

#' Download FIA data using rFIA
#' @param states Character vector of state abbreviations
#' @param data_dir Directory to store downloaded data
#' @return rFIA database object
download_fia_rfia <- function(states, data_dir) {
  if (!requireNamespace("rFIA", quietly = TRUE)) {
    stop("Package 'rFIA' is required. Install with: install.packages('rFIA')")
  }
  library(rFIA)

  tabs <- c("PLOT", "COND", "TREE", "TREE_GRM_COMPONENT",
            "TREE_GRM_MIDPT", "SUBP_COND_CHNG_MTRX")

  # FIADB is already staged on Cardinal scratch / $HOME/fia_data as ST_TABLE.csv.
  # Prefer reading those local files (readFIA) over re-downloading from the FIA
  # datamart, which is what caused the large TREE.zip download timeouts. Only the
  # genuinely missing states fall back to getFIA. readFIA returns the same
  # FIA.database structure as getFIA, so nothing downstream changes.
  options(timeout = max(3600L, getOption("timeout")))
  have_local <- function(s) all(file.exists(
    file.path(data_dir, paste0(s, "_", tabs, ".csv"))))
  staged  <- states[vapply(states, have_local, logical(1))]
  missing <- setdiff(states, staged)

  if (length(missing) == 0) {
    cat(sprintf("Reading staged FIA CSVs from %s for: %s\n",
                data_dir, paste(states, collapse = ", ")))
    db <- rFIA::readFIA(dir = data_dir, states = states, tables = tabs)
  } else {
    cat(sprintf("Downloading %d state(s) from FIA datamart: %s\n",
                length(missing), paste(missing, collapse = ", ")))
    if (length(staged) > 0)
      cat(sprintf("  (%d already staged locally: %s)\n",
                  length(staged), paste(staged, collapse = ", ")))
    db <- rFIA::getFIA(
      states  = states,
      dir     = data_dir,
      tables  = tabs,
      load    = TRUE
    )
  }

  return(db)
}

#' Read FIA data from local CSV or SQLite files
#' @param db_path Path to directory containing FIA CSV files or SQLite database
#' @param states Character vector of state abbreviations (for filtering)
#' @return List of data frames matching rFIA structure
read_fia_direct <- function(db_path, states = NULL) {

  # State FIPS codes for filtering
  state_fips <- tibble::tribble(
    ~abbr, ~fips,
    "ME", 23, "NH", 33, "VT", 50, "MA", 25, "CT", 9,
    "RI", 44, "NY", 36, "PA", 42, "NJ", 34, "MD", 24,
    "WV", 54, "VA", 51, "OH", 39, "MI", 26, "WI", 55,
    "MN", 27, "IA", 19, "MO", 29, "IN", 18, "IL", 17,
    "GA", 13, "FL", 12, "AL", 1, "MS", 28, "SC", 45,
    "NC", 37, "TN", 47, "KY", 21, "AR", 5, "LA", 22,
    "TX", 48, "OK", 40
  )

  if (!is.null(states)) {
    target_fips <- state_fips |>
      filter(abbr %in% states) |>
      pull(fips)
  }

  # Check if SQLite or CSV
  sqlite_file <- list.files(db_path, pattern = "\\.db$|\\.sqlite$", full.names = TRUE)

  if (length(sqlite_file) > 0) {
    cat("Reading from SQLite database...\n")
    con <- DBI::dbConnect(RSQLite::SQLite(), sqlite_file[1])
    on.exit(DBI::dbDisconnect(con))

    tables_needed <- c("PLOT", "COND", "TREE")
    db <- lapply(tables_needed, function(tbl) {
      df <- DBI::dbReadTable(con, tbl)
      if (!is.null(states)) df <- df[df$STATECD %in% target_fips, ]
      as_tibble(df)
    })
    names(db) <- tables_needed

  } else {
    cat("Reading from CSV files...\n")
    csv_files <- list.files(db_path, pattern = "\\.csv$", full.names = TRUE)

    db <- list()
    for (tbl_name in c("PLOT", "COND", "TREE")) {
      matching <- grep(tbl_name, csv_files, value = TRUE, ignore.case = TRUE)
      if (length(matching) > 0) {
        df <- data.table::fread(matching[1]) |> as_tibble()
        if (!is.null(states) && "STATECD" %in% names(df)) {
          df <- df |> filter(STATECD %in% target_fips)
        }
        db[[tbl_name]] <- df
      }
    }
  }

  return(db)
}

# =============================================================================
# 2. Build Plot Condition Records
# =============================================================================

#' Extract and prepare plot-condition records for matching
#' @param db FIA database (rFIA object or list of data frames)
#' @param cfg Configuration list
#' @return Tibble of plot-condition records with matching variables
build_condition_records <- function(db, cfg) {

  # Extract the tables we need
  if (inherits(db, "FIA.Database")) {
    plot_tbl <- db$PLOT
    cond_tbl <- db$COND
    tree_tbl <- db$TREE
  } else {
    plot_tbl <- db[["PLOT"]]
    cond_tbl <- db[["COND"]]
    tree_tbl <- db[["TREE"]]
  }

  # Join PLOT and COND tables
  cond_records <- cond_tbl |>
    inner_join(
      plot_tbl |>
        select(CN, STATECD, COUNTYCD, PLOT, INVYR, MEASYEAR,
               CYCLE, SUBCYCLE, DESIGNCD, PLOT_STATUS_CD,
               LAT, LON, ELEV),
      by = c("PLT_CN" = "CN"),
      suffix = c("", ".plot")
    ) |>
    filter(
      COND_STATUS_CD == 1,          # Forested conditions only
      RESERVCD == 0,                 # Non-reserved
      SITECLCD > 0 & SITECLCD <= 7  # Valid site class
    )

  # Compute condition-level summaries from tree data
  cond_tree_summary <- tree_tbl |>
    filter(STATUSCD == 1, DIA >= 1.0) |>  # Live trees >= 1 inch
    group_by(PLT_CN, CONDID) |>
    summarise(
      ba_live      = sum(TPA_UNADJ * 0.005454 * DIA^2, na.rm = TRUE),
      tpa_live     = sum(TPA_UNADJ, na.rm = TRUE),
      # Per-acre totals: TPA_UNADJ is trees/acre, multiplying by tree-level
      # VOLCFNET (total net cubic foot volume), VOLCSNET (merchantable sawlog
      # volume), DRYBIO_AG, CARBON_AG, and summing gives ft3/acre and lb/acre.
      volcfnet     = sum(TPA_UNADJ * VOLCFNET,  na.rm = TRUE),
      volcsnet     = sum(TPA_UNADJ * coalesce(VOLCSNET, 0), na.rm = TRUE),
      drybio_ag    = sum(TPA_UNADJ * DRYBIO_AG, na.rm = TRUE),
      carbon_ag    = sum(TPA_UNADJ * CARBON_AG, na.rm = TRUE),
      qmd          = sqrt(ba_live / tpa_live / 0.005454),
      n_species    = n_distinct(SPCD),
      dom_spcd     = if (all(is.na(TPA_UNADJ)) || length(SPCD) == 0) NA_integer_ else SPCD[which.max(ifelse(is.na(TPA_UNADJ * 0.005454 * DIA^2), -Inf, TPA_UNADJ * 0.005454 * DIA^2))],
      mean_dia     = weighted.mean(DIA, TPA_UNADJ, na.rm = TRUE),
      .groups      = "drop"
    )

  # Compute value-related metrics for harvest choice model
  # Revenue proxy: volume * price index by species group
  cond_value <- tree_tbl |>
    filter(STATUSCD == 1, DIA >= 5.0) |>
    mutate(
      # Broad product class based on diameter
      product = case_when(
        DIA >= 11.0 ~ "sawtimber",
        DIA >= 5.0  ~ "pulpwood",
        TRUE        ~ "none"
      ),
      # Softwood vs hardwood
      wood_type = ifelse(SPGRPCD <= 24, "softwood", "hardwood"),
      # Individual tree volume contribution
      tree_vol = TPA_UNADJ * VOLCFNET
    ) |>
    group_by(PLT_CN, CONDID, product, wood_type) |>
    summarise(
      vol_per_ac = sum(tree_vol, na.rm = TRUE),
      .groups = "drop"
    ) |>
    pivot_wider(
      names_from  = c(product, wood_type),
      values_from = vol_per_ac,
      values_fill = 0,
      names_prefix = "vol_"
    )

  # Compute variance in value across species (var_val from Wear & Coulston)
  cond_var_val <- tree_tbl |>
    filter(STATUSCD == 1, DIA >= 5.0) |>
    group_by(PLT_CN, CONDID) |>
    summarise(
      # Variance of log(volume) across species as proxy for value diversity
      var_val = var(log1p(VOLCFNET * TPA_UNADJ), na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(var_val = replace_na(var_val, 0))

  # Merge everything
  cond_full <- cond_records |>
    left_join(cond_tree_summary, by = c("PLT_CN", "CONDID")) |>
    left_join(cond_value, by = c("PLT_CN", "CONDID")) |>
    left_join(cond_var_val, by = c("PLT_CN", "CONDID")) |>
    mutate(
      # Compute condition proportion category (Van Deusen eq)
      CONDPROP_C = round(round(CONDPROP_UNADJ * 100) / 25),
      # Ensure BA is available
      BA = coalesce(ba_live, BALIVE),
      # Stand age with fallback
      STDAGE = coalesce(STDAGE, 0L)
    )

  # Join us_l3code from HCB x L3 crosswalk for CEM ecoregion stratification
  # (Layer 7+7b patch). Safe no-op if the crosswalk CSV is missing:
  # R/02_cem_matching.R falls back to STATECD when us_l3code is absent.
  #
  # PLT_CN type discipline: the FIA RDS stores PLT_CN as int64 / double, but
  # the crosswalk CSV reads PLT_CN as character. To avoid the downstream
  # type-mismatch crash in flag_events() (which joins T2_PLT_CN back to the
  # raw COND table), we use a temp .PLT_CN_chr column for the join only and
  # leave cond_full$PLT_CN in its original type.
  hcb_l3_path <- file.path(cfg$paths$config_dir %||% cfg$config_dir %||% "config",
                            "fia_plots_hcb_l3.csv")
  if (file.exists(hcb_l3_path)) {
    hcb_l3 <- suppressWarnings(
      readr::read_csv(hcb_l3_path,
                       col_types = readr::cols(PLT_CN = readr::col_character(),
                                                us_l3code = readr::col_integer(),
                                                .default = readr::col_guess()),
                       show_col_types = FALSE)
    ) |>
      dplyr::select(PLT_CN, us_l3code, us_l3name) |>
      dplyr::distinct(PLT_CN, .keep_all = TRUE)
    cond_full <- cond_full |>
      dplyr::mutate(.PLT_CN_chr = format(as.numeric(PLT_CN),
                                          scientific = FALSE, trim = TRUE)) |>
      dplyr::left_join(hcb_l3, by = c(".PLT_CN_chr" = "PLT_CN")) |>
      dplyr::select(-.PLT_CN_chr)
    cat(sprintf("  us_l3code joined from %s: %d of %d cond rows matched (%.1f%%)\n",
                hcb_l3_path,
                sum(!is.na(cond_full$us_l3code)),
                nrow(cond_full),
                100 * mean(!is.na(cond_full$us_l3code))))
  } else {
    cat(sprintf("  us_l3code crosswalk not at %s; CEM will fall back to STATECD\n",
                hcb_l3_path))
  }

  # Join per-plot productivity (asymptotic AGB / BGI) for CEM productivity
  # stratification (R-prod). Safe no-op if the lookup CSV is missing.
  asym_path <- file.path(cfg$paths$config_dir %||% cfg$config_dir %||% "config",
                         "asym_agb_by_pltcn.csv")
  if (file.exists(asym_path)) {
    asym_lk <- suppressWarnings(
      readr::read_csv(asym_path,
                       col_types = readr::cols(PLT_CN = readr::col_character(),
                                                asym_agb = readr::col_double()),
                       show_col_types = FALSE)
    ) |>
      dplyr::distinct(PLT_CN, .keep_all = TRUE)
    cond_full <- cond_full |>
      dplyr::mutate(.PLT_CN_chr = format(as.numeric(PLT_CN),
                                          scientific = FALSE, trim = TRUE)) |>
      dplyr::left_join(asym_lk, by = c(".PLT_CN_chr" = "PLT_CN")) |>
      dplyr::select(-.PLT_CN_chr)
    cat(sprintf("  asym_agb joined from %s: %d of %d cond rows matched (%.1f%%)\n",
                asym_path, sum(!is.na(cond_full$asym_agb)), nrow(cond_full),
                100 * mean(!is.na(cond_full$asym_agb))))
  } else {
    cat(sprintf("  asym_agb lookup not at %s; CEM productivity key disabled\n", asym_path))
  }

  return(cond_full)
}

# =============================================================================
# 3. Identify Remeasured Plot Pairs
# =============================================================================

#' Identify remeasured plot-condition pairs (time 1 and time 2)
#' @param cond_records Full condition records
#' @return Tibble with PREV_ columns for time 1 and current columns for time 2
identify_remeasured_pairs <- function(cond_records) {

  # Find plots that have been measured at least twice
  plot_invyrs <- cond_records |>
    group_by(STATECD, COUNTYCD, PLOT, CONDID) |>
    summarise(
      n_meas = n_distinct(INVYR),
      invyrs = list(sort(unique(INVYR))),
      .groups = "drop"
    ) |>
    filter(n_meas >= 2)

  # Build pairs: for each plot-condition with multiple measurements,

  # pair consecutive measurements as time1 / time2
  pairs <- plot_invyrs |>
    mutate(
      pairs = map(invyrs, function(yrs) {
        tibble(
          invyr_t1 = yrs[-length(yrs)],
          invyr_t2 = yrs[-1]
        )
      })
    ) |>
    select(-invyrs, -n_meas) |>
    unnest(pairs)

  # Join time 1 measurements
  t1 <- cond_records |>
    select(STATECD, COUNTYCD, PLOT, CONDID, INVYR, CONDPROP_UNADJ, SLOPE, ASPECT, PHYSCLCD,
           CONDPROP_C, OWNGRPCD, FORTYPCD, STDORGCD,
           SITECLCD, STDAGE, BA, ba_live, tpa_live, qmd,
           volcfnet, volcsnet, drybio_ag, carbon_ag, n_species,
           dom_spcd, var_val, starts_with("vol_"),
           LAT, LON, ELEV, PLT_CN,
           # Pass-through ecoregion key for CEM Layer 7 stratification.
           # any_of() so missing column is a soft no-op (falls back to STATECD).
           any_of(c("us_l3code", "us_l3name", "asym_agb")))

  t2 <- t1  # same structure for time 2

  remeasured <- pairs |>
    inner_join(t1, by = c("STATECD", "COUNTYCD", "PLOT", "CONDID",
                          "invyr_t1" = "INVYR"),
               suffix = c("", "")) |>
    rename_with(~ paste0("T1_", .), .cols = setdiff(names(t1),
                c("STATECD", "COUNTYCD", "PLOT", "CONDID", "INVYR")))

  remeasured <- remeasured |>
    inner_join(t2, by = c("STATECD", "COUNTYCD", "PLOT", "CONDID",
                          "invyr_t2" = "INVYR"),
               suffix = c("", "")) |>
    rename_with(~ paste0("T2_", .),
                .cols = intersect(names(t2),
                  setdiff(names(t2), c("STATECD", "COUNTYCD", "PLOT", "CONDID", "INVYR"))))

  # Compute remeasurement interval and whether harvest occurred
  remeasured <- remeasured |>
    mutate(
      remper        = invyr_t2 - invyr_t1,
      harvested     = (!is.na(T2_BA) & !is.na(T1_BA) & T2_BA < T1_BA * 0.7) |
                      FALSE,  # Will be refined with actual TRTCD
      ba_change     = T2_BA - T1_BA,
      vol_change    = T2_volcfnet - T1_volcfnet
    )

  cat(sprintf("  Found %d remeasured plot-condition pairs\n", nrow(remeasured)))
  cat(sprintf("  Remeasurement periods: %d to %d years (median: %d)\n",
              min(remeasured$remper), max(remeasured$remper),
              median(remeasured$remper)))

  return(remeasured)
}

# =============================================================================
# 4. Identify Subject Plots (awaiting remeasurement)
# =============================================================================

#' Identify subject plots that need projection
#' @param cond_records Full condition records
#' @param remeasured Remeasured pairs (to exclude already-remeasured)
#' @return Tibble of subject plot conditions
identify_subject_plots <- function(cond_records, remeasured, cfg = NULL) {

  # --- Untreated-only filter (matches PERSEUS 1,233-plot subset) ----------
  # Keeps only plots where every COND record has TRTCD1 == 0 (no harvest
  # treatment observed in any year's panel). Mirrors the PERSEUS
  # "untreated 1999-2018 (all years TRTCD1 == 0)" subset.
  if (isTRUE(cfg$untreated_only)) {
    untreated <- cond_records |>
      group_by(STATECD, COUNTYCD, PLOT) |>
      summarise(all_untreated = all(coalesce(TRTCD1, 0L) == 0L &
                                    coalesce(TRTCD2, 0L) == 0L &
                                    coalesce(TRTCD3, 0L) == 0L),
                .groups = "drop") |>
      filter(all_untreated)
    pre_n <- length(unique(paste(cond_records$STATECD, cond_records$PLOT)))
    cond_records <- cond_records |>
      semi_join(untreated, by = c("STATECD","COUNTYCD","PLOT"))
    post_n <- length(unique(paste(cond_records$STATECD, cond_records$PLOT)))
    cat(sprintf("  Untreated-only filter: %d -> %d plots (TRTCD1/2/3 == 0 across all years)\n",
                pre_n, post_n))
  }

  # Decide anchor year (center of subject window):
  #   - cfg$baseline_year (if set) for historical starts like 1999
  #   - otherwise the latest available measurement year
  if (!is.null(cfg$baseline_year)) {
    anchor_year   <- as.integer(cfg$baseline_year)
    window_halfwd <- as.integer(cfg$baseline_window %||% 5L)
    win_lo <- anchor_year
    win_hi <- anchor_year + window_halfwd - 1L
    cat(sprintf("  Baseline mode: anchor = %d, window = [%d, %d]\n",
                anchor_year, win_lo, win_hi))

    # Earliest measurement per plot-condition that falls in the window
    anchor_records <- cond_records |>
      filter(INVYR >= win_lo, INVYR <= win_hi) |>
      group_by(STATECD, COUNTYCD, PLOT, CONDID) |>
      filter(INVYR == min(INVYR)) |>
      ungroup()

    # If --include_remeasured is set, expand subject pool to include all
    # plots that have ANY measurement at or before win_hi, using their
    # most-recent-at-or-before-win_hi measurement as the anchor. This
    # recovers all FIA plots active in the historical panel cycle, not
    # just those whose first measurement happened to fall in the window.
    if (isTRUE(cfg$include_remeasured)) {
      pre_n <- nrow(anchor_records)
      # FIA pre-annualized periodic-design plots (DESIGNCD == 101 in Maine,
      # other early codes elsewhere) use a different sampling design and
      # different EXPNS expansion factors. Exclude them from the expansion
      # extras to keep the subject pool comparable to the annualized cycle.
      annualized_designs <- c(1L, 115L, 116L, 117L, 230L, 240L, 501L, 502L)
      extras <- cond_records |>
        filter(INVYR <= win_hi,
               is.na(DESIGNCD) | DESIGNCD %in% annualized_designs) |>
        group_by(STATECD, COUNTYCD, PLOT, CONDID) |>
        filter(INVYR == max(INVYR)) |>
        ungroup() |>
        anti_join(anchor_records,
                  by = c("STATECD", "COUNTYCD", "PLOT", "CONDID"))
      anchor_records <- bind_rows(anchor_records, extras)
      cat(sprintf("  --include_remeasured (annualized only): subject pool %d -> %d (+%d)\n",
                  pre_n, nrow(anchor_records), nrow(extras)))
    }
  } else {
    # Default: most recent measurement per plot-condition
    most_recent <- cond_records |>
      group_by(STATECD, COUNTYCD, PLOT, CONDID) |>
      filter(INVYR == max(INVYR)) |>
      ungroup()
    latest_invyr   <- max(cond_records$INVYR, na.rm = TRUE)
    subject_window <- latest_invyr - 4
    anchor_records <- most_recent |> filter(INVYR >= subject_window)
    cat(sprintf("  Default mode: subject window = [%d, %d]\n",
                subject_window, latest_invyr))
  }

  subjects <- anchor_records |>
    select(STATECD, COUNTYCD, PLOT, CONDID, INVYR, CONDPROP_UNADJ, SLOPE, ASPECT, PHYSCLCD,
           CONDPROP_C, OWNGRPCD, FORTYPCD, STDORGCD,
           SITECLCD, STDAGE, BA, ba_live, tpa_live, qmd,
           volcfnet, volcsnet, drybio_ag, carbon_ag, n_species,
           dom_spcd, var_val, starts_with("vol_"),
           LAT, LON, ELEV, PLT_CN,
           # Pass-through ecoregion key for CEM Layer 7 stratification.
           any_of(c("us_l3code", "us_l3name", "asym_agb")))

  cat(sprintf("  Identified %d subject plot conditions for projection\n",
              nrow(subjects)))

  return(subjects)
}

# =============================================================================
# 5. Detect Harvest and Disturbance Events in Remeasured Data
# =============================================================================

#' Flag disturbance and treatment events on remeasured plots
#' @param remeasured Remeasured pair records
#' @param db Original FIA database for accessing COND treatment codes
#' @return Remeasured pairs with event flags
flag_events <- function(remeasured, db) {

  if (inherits(db, "FIA.Database")) {
    cond_tbl <- db$COND
  } else {
    cond_tbl <- db[["COND"]]
  }

  # Get treatment and disturbance codes for time 2 conditions
  event_info <- cond_tbl |>
    select(PLT_CN, CONDID, TRTCD1, TRTCD2, TRTCD3,
           DSTRBCD1, DSTRBCD2, DSTRBCD3) |>
    mutate(
      # Harvest: treatment codes 10, 20, 30 (cutting)
      has_harvest = (TRTCD1 %in% c(10, 20, 30)) |
                    (TRTCD2 %in% c(10, 20, 30)) |
                    (TRTCD3 %in% c(10, 20, 30)),
      # Fire: disturbance code 30
      has_fire    = (DSTRBCD1 == 30) | (DSTRBCD2 == 30) | (DSTRBCD3 == 30),
      # Insect: disturbance code 10-12
      has_insect  = (DSTRBCD1 %in% 10:12) | (DSTRBCD2 %in% 10:12) |
                    (DSTRBCD3 %in% 10:12),
      # Wind: disturbance code 50
      has_wind    = (DSTRBCD1 == 50) | (DSTRBCD2 == 50) | (DSTRBCD3 == 50)
    ) |>
    mutate(across(starts_with("has_"), ~ replace_na(., FALSE)))

  # Join event flags to remeasured pairs
  remeasured <- remeasured |>
    left_join(
      event_info |> select(PLT_CN, CONDID, starts_with("has_")),
      by = c("T2_PLT_CN" = "PLT_CN", "CONDID")
    ) |>
    mutate(across(starts_with("has_"), ~ replace_na(., FALSE)))

  # Refine harvest flag using both TRTCD and BA change
  remeasured <- remeasured |>
    mutate(
      harvested = has_harvest | (T2_BA < T1_BA * 0.6 & !has_fire & !has_wind)
    )

  n_harv <- sum(remeasured$harvested)
  n_fire <- sum(remeasured$has_fire)
  n_ins  <- sum(remeasured$has_insect)
  cat(sprintf("  Events flagged: %d harvests, %d fires, %d insect events\n",
              n_harv, n_fire, n_ins))

  return(remeasured)
}

# =============================================================================
# 6. Main Data Preparation Pipeline
# =============================================================================

#' Run the full data preparation pipeline
#' @param cfg Configuration list from 00_config.R
#' @return List with: subjects, remeasured, cond_records, raw_db
prepare_fia_data <- function(cfg) {

  cat("=== FIA Data Preparation ===\n")

  # Step 1: Load FIA data
  cat("Step 1: Loading FIA data...\n")
  if (cfg$fia_access == "rds" && !is.null(cfg$fia_rds_path)) {
    cat(sprintf("  Loading pre-downloaded RDS: %s\n", cfg$fia_rds_path))
    db <- readRDS(cfg$fia_rds_path)
  } else if (cfg$fia_access == "rfia") {
    db <- download_fia_rfia(cfg$donor_states, cfg$data_dir)
  } else {
    db <- read_fia_direct(cfg$fia_db_path, cfg$donor_states)
  }

  # Step 2: Build condition records
  cat("Step 2: Building condition records...\n")
  cond_records <- build_condition_records(db, cfg)
  cat(sprintf("  Total conditions: %d\n", nrow(cond_records)))

  # Step 3: Identify remeasured pairs
  cat("Step 3: Identifying remeasured pairs...\n")
  remeasured <- identify_remeasured_pairs(cond_records)

  # Step 4: Flag events
  cat("Step 4: Flagging disturbance and treatment events...\n")
  remeasured <- flag_events(remeasured, db)

  # Step 4a: Optionally filter DONOR pool to untreated pairs only. Subjects
  # can then be matched against a clean growth-signal donor pool (no harvest
  # or disturbance between T1 and T2), which is important when using the
  # growth-rate-based projection formula proj = subject * (T2/T1). This
  # flag operates independently of the subject-side --untreated_only filter.
  if (isTRUE(cfg$untreated_donors)) {
    pre_n <- nrow(remeasured)
    remeasured <- remeasured |>
      filter(coalesce(!harvested, TRUE),
             coalesce(!has_fire, TRUE),
             coalesce(!has_insect, TRUE),
             coalesce(!has_wind, TRUE))
    cat(sprintf("  Untreated-donor filter: %d -> %d remeasured pairs\n",
                pre_n, nrow(remeasured)))
  }

  # Step 5: Identify subject plots
  cat("Step 5: Identifying subject plots...\n")
  subjects <- identify_subject_plots(cond_records, remeasured, cfg)

  cat("=== Data preparation complete ===\n\n")

  return(list(
    subjects     = subjects,
    remeasured   = remeasured,
    cond_records = cond_records,
    raw_db       = db
  ))
}
