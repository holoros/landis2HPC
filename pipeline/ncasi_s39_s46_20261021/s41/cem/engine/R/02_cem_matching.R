# =============================================================================
# Title: Coarsened Exact Matching (CEM) Engine
# Author: A. Weiskittel
# Date: 2026-03-19
# Description: Implements the 3-iteration CEM matching algorithm from
#              Van Deusen & Roesch (2013). Matches subject plot conditions
#              with remeasured donor conditions based on coarsened variables.
# Dependencies: 00_config.R, 01_data_prep.R
# =============================================================================

library(tidyverse)

# =============================================================================
# 1. Coarsening Functions
# =============================================================================

#' Coarsen a continuous variable into categories using breakpoints
#' @param x Numeric vector
#' @param breaks Breakpoints for binning
#' @return Integer category labels
coarsen_continuous <- function(x, breaks) {
  as.integer(cut(x, breaks = c(-Inf, breaks, Inf), labels = FALSE,
                 include.lowest = TRUE, right = FALSE))
}

#' Coarsen stand age following Van Deusen & Roesch (2013)
#' @param age Numeric vector of stand ages
#' @param breaks Breakpoints for age categories
#' @return Coarsened age class
coarsen_age <- function(age, breaks) {
  # Replace NA with 0 (unknown age treated as young)
  age <- replace_na(age, 0)
  as.integer(cut(age, breaks = breaks, labels = FALSE,
                 include.lowest = TRUE, right = FALSE))
}

#' Coarsen basal area following Van Deusen & Roesch (2013)
#' @param ba Numeric vector of basal area (ft2/ac)
#' @param method "fine" (20 ft2 increments), or use breaks
#' @param breaks Custom breakpoints (overrides method)
#' @return Coarsened BA class
coarsen_ba <- function(ba, method = "fine", breaks = NULL) {
  ba <- replace_na(ba, 0)
  if (!is.null(breaks)) {
    return(as.integer(cut(ba, breaks = breaks, labels = FALSE,
                          include.lowest = TRUE, right = FALSE)))
  }
  if (method == "fine") {
    return(round(ba / 20))
  }
  round(ba / 20)
}

#' Coarsen owner group code
#' @param owngrpcd Integer owner group codes (1-4)
#' @param level Coarsening level: 1 (no change), 2 (combine federal), 3 (drop)
#' @return Coarsened owner group
coarsen_owngrp <- function(owngrpcd, level = 1) {
  if (level == 1) {
    return(owngrpcd)
  } else if (level == 2) {
    # Combine National Forest (1) and Other Federal (2)
    return(ifelse(owngrpcd <= 2, 1L, owngrpcd - 1L))
  } else {
    # Level 3: drop ownership entirely
    return(rep(1L, length(owngrpcd)))
  }
}

#' Coarsen ecoregion (EPA L3 code)
#' Layer 7 patch (17 May 2026): add ecoregion as a CEM matching key.
#' Required to address donor pool composition mismatch documented in
#' CEM_3WAY_STRATIFICATION_20260517.md and MULTISTATE_DONOR_POOL_4PANEL_20260517.md.
#' @param l3code EPA L3 ecoregion code (integer or NA)
#' @param level Coarsening level: 1 (full L3), 2 (section), 3 (drop)
#' @param l3_to_section_lookup Optional data.table us_l3code -> section_code
#' @return Coarsened ecoregion key
coarsen_ecoregion <- function(l3code, level = 1, l3_to_section_lookup = NULL) {
  if (is.null(l3code)) return(character(0))
  n <- length(l3code)
  if (all(is.na(l3code))) return(rep("0", n))
  if (level == 1) {
    out <- as.character(as.integer(l3code))
    out[is.na(out)] <- "0"
    return(out)
  } else if (level == 2) {
    if (is.null(l3_to_section_lookup)) {
      fp <- file.path("config", "l3_to_section.csv")
      if (file.exists(fp)) {
        l3_to_section_lookup <- data.table::fread(fp, showProgress = FALSE)
      }
    }
    if (!is.null(l3_to_section_lookup)) {
      idx <- match(l3code, l3_to_section_lookup$us_l3code)
      out <- l3_to_section_lookup$section_code[idx]
      out[is.na(out)] <- "UNKNOWN_SECTION"
      return(as.character(out))
    } else {
      return(as.character(as.integer(l3code) %/% 10L))
    }
  } else {
    return(rep("0", n))
  }
}

#' Coarsen site class code
#' @param siteclcd Integer site productivity class (1-7)
#' @param breaks Optional breakpoints for custom coarsening
#' @return Coarsened site class
coarsen_sitecl <- function(siteclcd, breaks = NULL) {
  if (is.null(breaks)) return(siteclcd)
  as.integer(cut(siteclcd, breaks = breaks, labels = FALSE,
                 include.lowest = TRUE, right = FALSE))
}

#' Coarsen condition proportion following Van Deusen & Roesch (2013)
#' @param condprop Numeric condition proportion (0-1)
#' @return Integer category 0-4
coarsen_condprop <- function(condprop) {
  round(round(condprop * 100) / 25)
}

# =============================================================================
# 2. Apply Coarsening to a Dataset
# =============================================================================

#' Apply full coarsening scheme to a dataset
#' @param data Tibble with FIA condition variables
#' @param iteration CEM iteration (1, 2, or 3)
#' @param cfg Configuration list
#' @return Data with coarsened matching key columns appended
apply_coarsening <- function(data, iteration = 1, cfg) {

  cem_cfg <- cfg$cem

  if (iteration == 1) {
    data <- data |>
      mutate(
        cem_condprop  = coarsen_condprop(CONDPROP_UNADJ),
        cem_owngrp    = OWNGRPCD,
        cem_fortyp    = FORTYPCD,
        cem_ecoregion = coarsen_ecoregion(if ("us_l3code" %in% names(data)) us_l3code else STATECD, level = 1),
        cem_stdorg    = STDORGCD,
        cem_sitecl   = SITECLCD,
        cem_age      = coarsen_age(STDAGE, cem_cfg$iter1$stdage_breaks),
        cem_ba       = coarsen_ba(BA, method = "fine")
      )

  } else if (iteration == 2) {
    data <- data |>
      mutate(
        cem_condprop  = coarsen_condprop(CONDPROP_UNADJ),
        cem_owngrp    = coarsen_owngrp(OWNGRPCD, level = 2),
        cem_fortyp    = FORTYPCD,
        cem_ecoregion = coarsen_ecoregion(if ("us_l3code" %in% names(data)) us_l3code else STATECD, level = 2),
        cem_stdorg    = STDORGCD,
        cem_sitecl   = coarsen_sitecl(SITECLCD, cem_cfg$iter2$siteclcd_breaks),
        cem_age      = coarsen_age(STDAGE, cem_cfg$iter2$stdage_breaks),
        cem_ba       = coarsen_ba(BA, breaks = cem_cfg$iter2$ba_breaks)
      )

  } else if (iteration == 3) {
    data <- data |>
      mutate(
        cem_condprop  = coarsen_condprop(CONDPROP_UNADJ),
        cem_owngrp    = 1L,
        cem_fortyp    = FORTYPCD,
        cem_ecoregion = "0",
        cem_stdorg    = STDORGCD,
        cem_sitecl   = coarsen_sitecl(SITECLCD, cem_cfg$iter3$siteclcd_breaks),
        cem_age      = coarsen_age(STDAGE, cem_cfg$iter3$stdage_breaks),
        cem_ba       = coarsen_ba(BA, breaks = cem_cfg$iter3$ba_breaks)
      )
  }

  # Optionally add productivity (asymptotic AGB / BGI) coarsening (R-prod)
  if (isTRUE(cfg$cem$use_productivity) && "asym_agb" %in% names(data)) {
    pb <- if (iteration == 1) cfg$cem$iter1$asym_breaks
          else if (iteration == 2) cfg$cem$iter2$asym_breaks
          else cfg$cem$iter3$asym_breaks
    data$cem_prod <- if (is.null(pb)) "0" else as.character(coarsen_continuous(data$asym_agb, pb))
  }

  # Optionally add climate coarsening
  if (cfg$climate$use_climate && "mat" %in% names(data)) {
    data <- data |>
      mutate(
        cem_mat = coarsen_continuous(mat, cfg$climate$mat_breaks),
        cem_map = coarsen_continuous(map, cfg$climate$map_breaks)
      )
  }

  return(data)
}

# =============================================================================
# 3. Core CEM Matching Algorithm
# =============================================================================

#' Build CEM matching key from coarsened variables
#' @param data Dataset with cem_ columns
#' @param use_climate Whether to include climate in the key
#' @return Character vector of matching keys
build_cem_key <- function(data, use_climate = FALSE) {

  key_cols <- c("cem_condprop", "cem_owngrp", "cem_fortyp", "cem_ecoregion",
                "cem_stdorg", "cem_sitecl", "cem_age", "cem_ba")
  if ("cem_prod" %in% names(data)) key_cols <- c(key_cols, "cem_prod")

  if (use_climate && "cem_mat" %in% names(data)) {
    key_cols <- c(key_cols, "cem_mat", "cem_map")
  }

  # Build composite key by pasting coarsened values
  data |>
    unite("cem_key", all_of(key_cols), sep = "_", remove = FALSE) |>
    pull(cem_key)
}

#' Perform one iteration of CEM matching
#' @param subjects Subject plot conditions (awaiting projection)
#' @param donors Remeasured plot conditions (time 1 data)
#' @param iteration CEM iteration number (1, 2, or 3)
#' @param cfg Configuration list
#' @return List with: matched (subject-donor pairs), unmatched (subjects)
cem_match_iteration <- function(subjects, donors, iteration, cfg) {

  use_climate <- cfg$climate$use_climate

  # Apply coarsening to both datasets
  subj_c <- apply_coarsening(subjects, iteration, cfg)
  don_c  <- apply_coarsening(donors, iteration, cfg)

  # Build matching keys
  subj_c$cem_key <- build_cem_key(subj_c, use_climate)
  don_c$cem_key  <- build_cem_key(don_c, use_climate)

  # Find matches: subjects matched to donors with the same key
  donor_keys <- don_c |>
    mutate(donor_row = row_number()) |>
    select(cem_key, donor_row) |>
    distinct()

  # For each subject, find all matching donors
  matched_pairs <- subj_c |>
    mutate(subject_row = row_number()) |>
    inner_join(
      {  # R-prodW: carry donor asymptotic AGB for soft productivity weighting
        .dk <- don_c |> mutate(donor_idx = row_number())
        if ("asym_agb" %in% names(.dk))
          dplyr::select(.dk, cem_key, donor_idx, donor_asym = asym_agb)
        else dplyr::select(.dk, cem_key, donor_idx)
      },
      by = "cem_key",
      relationship = "many-to-many"
    )

  # Identify matched and unmatched subjects
  matched_subject_rows <- unique(matched_pairs$subject_row)
  unmatched_subjects <- subj_c |>
    mutate(subject_row = row_number()) |>
    filter(!(subject_row %in% matched_subject_rows)) |>
    select(-subject_row, -starts_with("cem_"))

  matched_subjects <- subj_c |>
    mutate(subject_row = row_number()) |>
    filter(subject_row %in% matched_subject_rows) |>
    select(-subject_row, -starts_with("cem_"))

  cat(sprintf("  Iteration %d: %d/%d subjects matched (%.1f%%)\n",
              iteration,
              length(matched_subject_rows),
              nrow(subjects),
              100 * length(matched_subject_rows) / nrow(subjects)))

  return(list(
    matched_pairs    = matched_pairs,
    matched_subjects = matched_subjects,
    unmatched        = unmatched_subjects,
    donor_data       = don_c
  ))
}

# =============================================================================
# 4. Full 3-Iteration CEM Pipeline
# =============================================================================

#' Run the full 3-iteration CEM matching process
#' @param subjects Subject plot conditions
#' @param remeasured Remeasured plot-condition pairs with T1_ and T2_ columns
#' @param cfg Configuration list
#' @return List: all_matches (subject to donor mappings), match_summary
run_cem_matching <- function(subjects, remeasured, cfg) {

  cat("=== CEM Plot Matching ===\n")
  cat(sprintf("  Subjects: %d | Donors: %d\n",
              nrow(subjects), nrow(remeasured)))

  # Prepare donor data (time 1 measurements from remeasured plots)
  # We need to rename T1_ columns back to base names for matching
  donors <- remeasured |>
    select(STATECD, COUNTYCD, PLOT, CONDID,
           starts_with("T1_"), starts_with("T2_"),
           remper, harvested, starts_with("has_")) |>
    rename_with(~ str_remove(., "^T1_"),
                .cols = starts_with("T1_")) |>
    mutate(donor_id = row_number())

  # Robust productivity attach (R-prod): join per-plot asymptotic AGB onto BOTH
  # subjects and donors by PLT_CN so the cem_prod key is symmetric regardless of
  # how asym_agb propagated through the t1/t2/include_remeasured machinery.
  if (isTRUE(cfg$cem$use_productivity) || isTRUE(cfg$cem$use_prod_weighting)) {  # R-prodW
    .apath <- file.path(cfg$paths$config_dir %||% cfg$config_dir %||% "config",
                        "asym_agb_by_pltcn.csv")
    if (file.exists(.apath)) {
      .alk <- suppressWarnings(readr::read_csv(.apath,
               col_types = readr::cols(PLT_CN = readr::col_character(),
                                       asym_agb = readr::col_double()),
               show_col_types = FALSE)) |> dplyr::distinct(PLT_CN, .keep_all = TRUE)
      .attach <- function(df) {
        if (!"PLT_CN" %in% names(df)) return(df)
        df |>
          dplyr::select(-dplyr::any_of("asym_agb")) |>
          dplyr::mutate(.k = format(as.numeric(PLT_CN), scientific = FALSE, trim = TRUE)) |>
          dplyr::left_join(.alk, by = c(".k" = "PLT_CN")) |>
          dplyr::select(-.k)
      }
      subjects <- .attach(subjects); donors <- .attach(donors)
      cat(sprintf("  productivity attached: subj %.0f%%, donor %.0f%% non-NA asym_agb\n",
                  100*mean(!is.na(subjects$asym_agb)), 100*mean(!is.na(donors$asym_agb))))
    } else {
      cat("  productivity lookup missing; cem_prod disabled this run\n")
    }
  }

  # Also ensure subjects have CONDPROP_UNADJ for coarsening
  if (!"CONDPROP_UNADJ" %in% names(subjects) && "CONDPROP_C" %in% names(subjects)) {
    subjects <- subjects |>
      mutate(CONDPROP_UNADJ = CONDPROP_C * 0.25)
  }
  if (!"CONDPROP_UNADJ" %in% names(donors)) {
    donors <- donors |>
      mutate(CONDPROP_UNADJ = coalesce(CONDPROP_UNADJ, CONDPROP_C * 0.25))
  }

  all_match_pairs <- tibble()
  remaining <- subjects
  iteration_results <- list()

  # Iteration 1: Fine matching
  cat("\n--- Iteration 1 (fine) ---\n")
  iter1 <- cem_match_iteration(remaining, donors, 1, cfg)
  if (nrow(iter1$matched_pairs) > 0) {
    iter1$matched_pairs$cem_iteration <- 1L
    all_match_pairs <- bind_rows(all_match_pairs, iter1$matched_pairs)
  }
  remaining <- iter1$unmatched
  iteration_results[[1]] <- iter1

  # Iteration 2: Medium matching
  if (nrow(remaining) > 0) {
    cat("\n--- Iteration 2 (medium) ---\n")
    iter2 <- cem_match_iteration(remaining, donors, 2, cfg)
    if (nrow(iter2$matched_pairs) > 0) {
      iter2$matched_pairs$cem_iteration <- 2L
      all_match_pairs <- bind_rows(all_match_pairs, iter2$matched_pairs)
    }
    remaining <- iter2$unmatched
    iteration_results[[2]] <- iter2
  }

  # Iteration 3: Coarse matching
  if (nrow(remaining) > 0) {
    cat("\n--- Iteration 3 (coarse) ---\n")
    iter3 <- cem_match_iteration(remaining, donors, 3, cfg)
    if (nrow(iter3$matched_pairs) > 0) {
      iter3$matched_pairs$cem_iteration <- 3L
      all_match_pairs <- bind_rows(all_match_pairs, iter3$matched_pairs)
    }
    remaining <- iter3$unmatched
    iteration_results[[3]] <- iter3
  }

  # Thin-data guard: when every iteration yields zero matches (e.g. a sparse DE
  # Monte Carlo draw), the bind blocks above are all skipped and all_match_pairs
  # stays a columnless tibble(). That breaks count(), apply_scenario_bias(), and
  # the donor join downstream. cem_match_iteration builds matched_pairs via an
  # inner_join, so iter1$matched_pairs always carries the full schema even at 0
  # rows. Rebuild all_match_pairs as a typed 0-row tibble from it so every subject
  # simply carries forward as unmatched instead of crashing the array task.
  if (nrow(all_match_pairs) == 0) {
    all_match_pairs <- iter1$matched_pairs[0, , drop = FALSE]
    all_match_pairs$cem_iteration <- integer(0)
  }

  # Summary
  n_total <- nrow(subjects)
  n_matched <- n_total - nrow(remaining)
  n_unmatched <- nrow(remaining)

  cat(sprintf("\n=== CEM Matching Summary ===\n"))
  cat(sprintf("  Total subjects: %d\n", n_total))
  cat(sprintf("  Matched: %d (%.1f%%)\n", n_matched, 100 * n_matched / n_total))
  cat(sprintf("  Unmatched: %d (%.1f%%)\n", n_unmatched, 100 * n_unmatched / n_total))

  # Count matches per subject.
  # Guard: thin-data states (e.g. DE) can yield zero matches in some Monte Carlo
  # draws, leaving all_match_pairs an empty columnless tibble. count() then aborts
  # with "Must group by variables found in `.data`". Handle the empty case so the
  # draw returns a well formed zero-match result instead of crashing the array task.
  if (nrow(all_match_pairs) == 0) {
    matches_per_subject <- tibble(subject_row = integer(0), n_matches = integer(0))
    median_mps <- NA_real_
    cat("  Matches per subject: none, 0 matches this draw\n")
  } else {
    matches_per_subject <- all_match_pairs |>
      count(subject_row, name = "n_matches")
    median_mps <- as.numeric(median(matches_per_subject$n_matches))
    cat(sprintf("  Matches per subject: median = %.1f, range = [%d, %d]\n",
                median_mps,
                min(matches_per_subject$n_matches),
                max(matches_per_subject$n_matches)))
  }

  return(list(
    all_matches       = all_match_pairs,
    unmatched         = remaining,
    donors            = donors,
    iteration_results = iteration_results,
    match_summary     = tibble(
      n_subjects  = n_total,
      n_matched   = n_matched,
      n_unmatched = n_unmatched,
      pct_matched = 100 * n_matched / n_total,
      median_matches_per_subject = median_mps
    )
  ))
}

# =============================================================================
# 5. Select Single Match per Subject
# =============================================================================

#' Select one donor match per subject condition (BAU or biased)
#' @param cem_results Output from run_cem_matching()
#' @param bias_params Optional biasing parameters (see 05_scenario_biasing.R)
#' @param seed Random seed
#' @return Tibble with one row per subject, containing selected donor info
select_matches <- function(cem_results, bias_params = NULL, seed = 42) {

  set.seed(seed)

  matches <- cem_results$all_matches

  if (is.null(bias_params)) {
    # BAU: random uniform selection
    selected <- matches |>
      group_by(subject_row) |>
      mutate(rv = runif(n())) |>
      slice_max(rv, n = 1, with_ties = FALSE) |>
      ungroup() |>
      select(-rv)

  } else {
    # Biased selection (implemented in 05_scenario_biasing.R)
    selected <- apply_scenario_bias(matches, bias_params, seed)
  }

  return(selected)
}
