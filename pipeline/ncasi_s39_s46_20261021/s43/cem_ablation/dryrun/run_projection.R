# =============================================================================
# Title: FIA Plot Matching Projection System -- Main Entry Point
# Author: A. Weiskittel
# Date: 2026-03-19
# Description: Main script to run state-level forest inventory projections
#              using CEM plot matching (Van Deusen & Roesch 2013) combined
#              with economic harvest choice and tree planting models
#              (Wear & Coulston 2025). Supports scenario analysis for
#              climate, prices, harvesting, disturbances, and landowner
#              behavior.
#
# Usage:
#   1. Edit 00_config.R for your state and settings
#   2. Run this script: source("run_projection.R")
#   3. Results saved to output/ directory
#
# HPC Usage (OSC or similar):
#   Rscript run_projection.R --state ME --n_sims 1000 --cores 16
#
# References:
#   Van Deusen, P.C. & Roesch, F.A. (2013). Trends and projections from
#     annual forest inventory plots and coarsened exact matching. MCFNS
#     5(2):126-134.
#   Wear, D.N. & Coulston, J.W. (2025). A comparative analysis of timber
#     harvesting, timber supply, and tree planting across ownerships and
#     regions of the United States. Forest Policy & Economics 178:103542.
# =============================================================================

# --- Setup -------------------------------------------------------------------
library(here)
set_here <- function() {
  if (requireNamespace("here", quietly = TRUE)) {
    return(invisible())
  }
}

# Source all modules
source_modules <- function(project_dir = ".") {
  module_files <- list.files(
    file.path(project_dir, "R"),
    pattern = "^\\d{2}_.*\\.R$",
    full.names = TRUE
  )
  for (f in sort(module_files)) {
    cat(sprintf("  Loading: %s\n", basename(f)))
    source(f, local = FALSE)
  }
}

# --- Command line argument parsing (for HPC) ---------------------------------
parse_cli_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  parsed <- list()

  if (length(args) > 0) {
    i <- 1
    while (i <= length(args)) {
      if (args[i] == "--state" && i < length(args)) {
        parsed$state <- args[i + 1]; i <- i + 2
      } else if (args[i] == "--n_sims" && i < length(args)) {
        parsed$n_sims <- as.integer(args[i + 1]); i <- i + 2
      } else if (args[i] == "--cores" && i < length(args)) {
        parsed$cores <- as.integer(args[i + 1]); i <- i + 2
      } else if (args[i] == "--cycles" && i < length(args)) {
        parsed$cycles <- as.integer(args[i + 1]); i <- i + 2
      } else if (args[i] == "--output" && i < length(args)) {
        parsed$output <- args[i + 1]; i <- i + 2
      } else if (args[i] == "--config" && i < length(args)) {
        parsed$config_file <- args[i + 1]; i <- i + 2
      } else if (args[i] == "--no_econ") {
        parsed$no_econ <- TRUE; i <- i + 1
      } else if (args[i] == "--climate_file" && i < length(args)) {
        parsed$climate_file <- args[i + 1]; i <- i + 2
      } else if (args[i] == "--scenario_set" && i < length(args)) {
        parsed$scenario_set <- args[i + 1]; i <- i + 2
      } else if (args[i] == "--tag" && i < length(args)) {
        parsed$tag <- args[i + 1]; i <- i + 2
      } else if (args[i] == "--baseline_year" && i < length(args)) {
        parsed$baseline_year <- as.integer(args[i + 1]); i <- i + 2
      } else if (args[i] == "--baseline_window" && i < length(args)) {
        parsed$baseline_window <- as.integer(args[i + 1]); i <- i + 2
      } else if (args[i] == "--save_per_plot") {
        parsed$save_per_plot <- TRUE; i <- i + 1
      } else if (args[i] == "--skip_supply") {
        parsed$skip_supply <- TRUE; i <- i + 1
      } else if (args[i] == "--skip_report_figs") {
        parsed$skip_report_figs <- TRUE; i <- i + 1
      } else if (args[i] == "--untreated_only") {
        parsed$untreated_only <- TRUE; i <- i + 1
      } else if (args[i] == "--untreated_donors") {
        parsed$untreated_donors <- TRUE; i <- i + 1
      } else if (args[i] == "--conus_donors") {
        parsed$conus_donors <- TRUE; i <- i + 1
      } else if (args[i] == "--no_harvest_all") {
        parsed$no_harvest_all <- TRUE; i <- i + 1
      } else if (args[i] == "--fixed_harvest_rate" && i < length(args)) {
        parsed$fixed_harvest_rate <- as.numeric(args[i + 1]); i <- i + 2
      } else if (args[i] == "--fixed_harvest_intensity" && i < length(args)) {
        parsed$fixed_harvest_intensity <- as.numeric(args[i + 1]); i <- i + 2
      } else if (args[i] == "--climate_rcp" && i < length(args)) {
        parsed$climate_rcp <- as.numeric(args[i + 1]); i <- i + 2
      } else if (args[i] == "--bootstrap_plots") {
        parsed$bootstrap_plots <- TRUE; i <- i + 1
      } else if (args[i] == "--bootstrap_frac" && i < length(args)) {
        parsed$bootstrap_frac <- as.numeric(args[i + 1]); i <- i + 2
      } else if (args[i] == "--use_maine_econ") {
        parsed$use_maine_econ <- TRUE; i <- i + 1
      } else if (args[i] == "--include_remeasured") {
        parsed$include_remeasured <- TRUE; i <- i + 1
      } else if (args[i] == "--use_brms_sdimax") {
        parsed$use_brms_sdimax <- TRUE; i <- i + 1
      } else if (args[i] == "--use_decoupled_climate") {
        parsed$use_decoupled_climate <- TRUE; i <- i + 1
      } else if (args[i] == "--co2_effect_mult" && i < length(args)) {
        parsed$co2_effect_mult <- as.numeric(args[i + 1]); i <- i + 2
      } else if (args[i] == "--use_disturbance") {
        parsed$use_disturbance <- TRUE; i <- i + 1
      } else if (args[i] == "--insect_amp_mult" && i < length(args)) {
        parsed$insect_amp_mult <- as.numeric(args[i + 1]); i <- i + 2
      } else if (args[i] == "--wind_amp_mult" && i < length(args)) {
        parsed$wind_amp_mult <- as.numeric(args[i + 1]); i <- i + 2
      } else if (args[i] == "--fire_amp_mult" && i < length(args)) {
        parsed$fire_amp_mult <- as.numeric(args[i + 1]); i <- i + 2
      } else if (args[i] == "--use_species_climate") {
        parsed$use_species_climate <- TRUE; i <- i + 1
      } else if (args[i] == "--use_potter_vcc") {
        parsed$use_potter_vcc <- TRUE; i <- i + 1
      } else if (args[i] == "--use_county_harvest") {
        parsed$use_county_harvest <- TRUE; i <- i + 1
      } else if (args[i] == "--use_owner_stratification") {
        parsed$use_owner_stratification <- TRUE; i <- i + 1
      } else if (args[i] == "--use_owner_balanced") {
        parsed$use_owner_balanced <- TRUE; i <- i + 1
      } else if (args[i] == "--use_productivity") {
        parsed$use_productivity <- TRUE; i <- i + 1
      } else if (args[i] == "--use_prod_weighting") {  # R-prodW
        parsed$use_prod_weighting <- TRUE; i <- i + 1
      } else if (args[i] == "--use_asym_anchor") {     # R-asymAnchor
        parsed$use_asym_anchor <- TRUE; i <- i + 1
      } else if (args[i] == "--asym_anchor_strength") {# R-asymAnchor
        parsed$asym_anchor_strength <- as.numeric(args[i + 1]); i <- i + 2
      } else if (args[i] == "--prod_weight_bw") {      # R-prodW
        parsed$prod_weight_bw <- as.numeric(args[i + 1]); i <- i + 2
      } else if (args[i] == "--plantation_terminal_age") {  # R-plantTerm
        parsed$plantation_terminal_age <- as.numeric(args[i + 1]); i <- i + 2
      } else if (args[i] == "--plantation_growth_start") {  # R-plantTerm
        parsed$plantation_growth_start <- as.numeric(args[i + 1]); i <- i + 2
      } else if (args[i] == "--use_v4_prod_mult") {
        parsed$use_v4_prod_mult <- TRUE; i <- i + 1
      } else if (args[i] == "--v4_prod_mult_strength") {
        parsed$v4_prod_mult_strength <- as.numeric(args[i + 1]); i <- i + 2
      } else {
        i <- i + 1
      }
    }
  }

  return(parsed)
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main <- function() {

  cat("\n")
  cat("================================================================\n")
  cat("  FIA Plot Matching Projection System\n")
  cat("  Van Deusen & Roesch (2013) + Wear & Coulston (2025)\n")
  cat("================================================================\n\n")

  # Determine project directory
  project_dir <- tryCatch(here::here(), error = function(e) getwd())

  # Load modules
  cat("Loading modules...\n")
  source_modules(project_dir)

  # Parse CLI args and override config
  cli_args <- parse_cli_args()

  if (!is.null(cli_args$state)) {
    CONFIG$target_state <- cli_args$state
    # Update donor states based on region
    if (isTRUE(cli_args$conus_donors)) {
      # CONUS-wide ecoregion-membership donor pool. Donors drawn from all
      # available FIA states; the Layer 7b cem_ecoregion matching key
      # restricts actual matches to same-ecoregion donors. This addresses the
      # finding (L7B_HINDCAST_RESULTS_20260520.md) that bias-driving subject
      # cells have no ecologically-matched donors in the neighbor cohort.
      CONFIG$donor_states <- get_all_available_states()
      cat("CONUS-wide donor pool enabled: ",
          length(CONFIG$donor_states), " states\n")
    } else {
      CONFIG$donor_states <- get_donor_states(cli_args$state)
    }
  }
  if (!is.null(cli_args$n_sims))    CONFIG$n_simulations <- cli_args$n_sims
  if (!is.null(cli_args$cycles))    CONFIG$n_cycles <- cli_args$cycles
  if (!is.null(cli_args$output))    CONFIG$output_dir <- cli_args$output
  if (!is.null(cli_args$no_econ))   CONFIG$harvest$use_economic_model <- FALSE
  if (isTRUE(cli_args$use_productivity)) CONFIG$cem$use_productivity <- TRUE
  if (!is.null(cli_args$plantation_terminal_age)) {  # R-plantTerm
    CONFIG$plantation_terminal_age <- cli_args$plantation_terminal_age
    if (!is.null(cli_args$plantation_growth_start)) CONFIG$plantation_growth_start <- cli_args$plantation_growth_start
    cat(sprintf("Plantation rotation age enabled: planted stands (STDORGCD=1) terminal age=%.0f, growth_start=%.0f\n",
                CONFIG$plantation_terminal_age, CONFIG$plantation_growth_start %||% 15))
  }
  if (isTRUE(cli_args$use_asym_anchor)) {  # R-asymAnchor
    CONFIG$cem$use_prod_weighting <- isTRUE(CONFIG$cem$use_prod_weighting)  # asym anchor needs donor_asym attached
    CONFIG$use_asym_anchor <- TRUE
    .astr <- if (!is.null(cli_args$asym_anchor_strength)) cli_args$asym_anchor_strength else 1.0
    options(cem.asym_anchor = TRUE, cem.asym_anchor_strength = .astr,
            cem.prod_weighting = isTRUE(getOption("cem.prod_weighting", FALSE)))
    cat(sprintf("Per-plot FIA asymptote anchor enabled (strength=%.2f)\n", .astr))
  }
  if (isTRUE(cli_args$use_prod_weighting)) {  # R-prodW
    CONFIG$cem$use_prod_weighting <- TRUE
    CONFIG$cem$prod_weight_bw <- if (!is.null(cli_args$prod_weight_bw)) cli_args$prod_weight_bw else 50
    options(cem.prod_weighting = TRUE, cem.prod_bw = CONFIG$cem$prod_weight_bw)
    cat(sprintf("Productivity-weighted donor draw enabled (bandwidth=%.0f Mg/ha asymptotic AGB)\n",
                CONFIG$cem$prod_weight_bw))
  }
  if (!is.null(cli_args$climate_file)) {
    CONFIG$climate$use_climate <- TRUE
    CONFIG$climate$data_file <- cli_args$climate_file
  }
  if (!is.null(cli_args$baseline_year)) {
    CONFIG$baseline_year <- cli_args$baseline_year
    CONFIG$baseline_window <- cli_args$baseline_window %||% 5L
    cat(sprintf("Baseline year set to %d (window +/- %d years)\n",
                CONFIG$baseline_year, CONFIG$baseline_window))
  }
  if (isTRUE(cli_args$save_per_plot)) {
    CONFIG$save_per_plot <- TRUE
    cat("Per-plot projection saving enabled\n")
  }
  if (isTRUE(cli_args$untreated_only)) {
    CONFIG$untreated_only <- TRUE
    cat("Untreated-only filter enabled (TRTCD1/2/3 == 0 across all years)\n")
  }
  if (isTRUE(cli_args$untreated_donors)) {
    CONFIG$untreated_donors <- TRUE
    cat("Untreated-donor filter enabled (only non-harvested/disturbed donors)\n")
  }
  if (isTRUE(cli_args$no_harvest_all)) {
    CONFIG$force_no_harvest <- TRUE
    cat("No-harvest override enabled (final_harvest = FALSE for all conditions)\n")
  }
  if (!is.null(cli_args$fixed_harvest_rate)) {
    CONFIG$fixed_harvest_rate <- cli_args$fixed_harvest_rate
    cat(sprintf("Fixed harvest rate = %.3f (fraction of area per cycle)\n",
                cli_args$fixed_harvest_rate))
  }
  if (!is.null(cli_args$fixed_harvest_intensity)) {
    CONFIG$fixed_harvest_intensity <- cli_args$fixed_harvest_intensity
    cat(sprintf("Fixed harvest intensity = %.3f (biomass fraction removed)\n",
                cli_args$fixed_harvest_intensity))
  }
  if (!is.null(cli_args$climate_rcp)) {
    CONFIG$climate_rcp <- cli_args$climate_rcp
    cat(sprintf("Climate RCP %.1f enabled (HadGEM2-AO Maine time-varying multipliers)\n",
                cli_args$climate_rcp))
  }
  if (isTRUE(cli_args$bootstrap_plots)) {
    CONFIG$bootstrap_plots <- TRUE
    CONFIG$bootstrap_frac  <- cli_args$bootstrap_frac %||% 1.0
    cat(sprintf("Bootstrap-per-sim enabled (frac = %.2f)\n",
                CONFIG$bootstrap_frac))
  }
  if (isTRUE(cli_args$use_maine_econ)) {
    CONFIG$use_maine_econ <- TRUE
    cat("Maine economic harvest overlay enabled (county stumpage + partial/clearcut split)\n")
  }
  if (isTRUE(cli_args$include_remeasured)) {
    CONFIG$include_remeasured <- TRUE
    cat("Subject pool expanded: include_remeasured=TRUE (R1 refinement)\n")
  }
  if (isTRUE(cli_args$use_brms_sdimax)) {
    CONFIG$use_brms_sdimax <- TRUE
    cat("BRMS SDImax cap enabled: Reineke self-thinning per plot (R5)\n")
  }
  if (isTRUE(cli_args$use_decoupled_climate)) {
    CONFIG$use_decoupled_climate <- TRUE
    cat("Decoupled climate enabled: separate temperature and CO2 multipliers (R8)\n")
  }
  if (!is.null(cli_args$co2_effect_mult)) {
    CONFIG$co2_effect_mult <- cli_args$co2_effect_mult
    cat(sprintf("CO2 effect multiplier set to %.3f per doubling\n",
                CONFIG$co2_effect_mult))
  }
  if (isTRUE(cli_args$use_disturbance)) {
    CONFIG$use_disturbance <- TRUE
    cat("Episodic disturbance module enabled (SBW + wind + fire) (R6)\n")
  }
  if (isTRUE(cli_args$use_species_climate)) {
    CONFIG$use_species_climate <- TRUE
    cat("Species-specific climate response enabled (D'Amato 2011 + Iverson 2008) (R4)\n")
  }
  if (isTRUE(cli_args$use_potter_vcc)) {
    CONFIG$use_potter_vcc <- TRUE
    cat("Potter 2017 CAPTURE VCC enabled (SPCD-resolved climate sensitivity) (R4-VCC)\n")
  }
  if (isTRUE(cli_args$use_county_harvest)) {
    CONFIG$harvest$use_county_harvest <- TRUE
    cat("Per-county harvest logit offset enabled (R12; SAR-calibrated)\n")
  }
  if (isTRUE(cli_args$use_owner_stratification)) {
    CONFIG$harvest$use_owner_stratification <- TRUE
    cat("HCB landowner stratification enabled (R14; Harris-Caputo-Butler 2025 raster)\n")
  }
  if (isTRUE(cli_args$use_owner_balanced)) {
    CONFIG$harvest$use_owner_balanced <- TRUE
    cat("R14-bal: forest-area mass-balance rescale enabled (preserve statewide harvest)\n")
  }
  if (isTRUE(cli_args$use_v4_prod_mult)) {
    CONFIG$use_v4_prod_mult <- TRUE
    CONFIG$v4_prod_mult_strength <- if (!is.null(cli_args$v4_prod_mult_strength))
      cli_args$v4_prod_mult_strength else 1.0
    cat(sprintf("v4 productivity multiplier enabled (FIA empirical asymptote, strength=%.2f)\n",
                CONFIG$v4_prod_mult_strength))
  }
  for (nm in c("insect_amp_mult", "wind_amp_mult", "fire_amp_mult")) {
    if (!is.null(cli_args[[nm]])) CONFIG[[nm]] <- cli_args[[nm]]
  }

  # Auto-detect climate data from download script
  if (is.null(CONFIG$climate$data_file) && isTRUE(CONFIG$climate$auto_detect)) {
    fia_dir <- Sys.getenv("FIA_DATA_DIR",
                           unset = file.path(Sys.getenv("HOME"), "fia_data"))
    auto_clim <- file.path(fia_dir, "climate",
                           paste0("climate_combined_", CONFIG$target_state, ".csv"))
    if (file.exists(auto_clim)) {
      cat(sprintf("Auto-detected climate data: %s\n", auto_clim))
      CONFIG$climate$use_climate <- TRUE
      CONFIG$climate$data_file <- auto_clim
    }
  }

  # Auto-detect pre-downloaded FIA RDS from download script
  fia_dir <- Sys.getenv("FIA_DATA_DIR",
                         unset = file.path(Sys.getenv("HOME"), "fia_data"))
  rds_file <- file.path(fia_dir,
                         paste0("fia_db_", CONFIG$target_state, ".rds"))
  if (file.exists(rds_file) && CONFIG$fia_access == "rfia") {
    cat(sprintf("Auto-detected pre-downloaded FIA data: %s\n", rds_file))
    CONFIG$fia_access <- "rds"
    CONFIG$fia_rds_path <- rds_file
  }

  # Print configuration
  print_config(CONFIG)

  # =========================================================================
  # Step 0: Create output directory EARLY so partial results survive
  # a wall-time kill during later steps.
  # =========================================================================
  scen_set_name <- if (!is.null(cli_args$scenario_set)) cli_args$scenario_set else "standard"
  run_tag <- if (!is.null(cli_args$tag)) paste0("_", cli_args$tag) else paste0("_", scen_set_name)
  output_dir <- file.path(CONFIG$output_dir,
                           paste0(CONFIG$target_state, "_",
                                  format(Sys.Date(), "%Y%m%d"),
                                  run_tag))
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  cat(sprintf("Output directory: %s\n", output_dir))

  # =========================================================================
  # Step 1: Prepare FIA data
  # =========================================================================
  cat("\n--- STEP 1: Data Preparation ---\n")
  data_list <- prepare_fia_data(CONFIG)

  # =========================================================================
  # Step 2: Define scenarios
  # =========================================================================
  cat("\n--- STEP 2: Scenario Definition ---\n")
  scenarios <- get_scenario_set(scen_set_name)
  cat(sprintf("  Scenario set: %s\n", scen_set_name))
  cat(sprintf("  Defined %d scenarios: %s\n",
              length(scenarios),
              paste(sapply(scenarios, `[[`, "name"), collapse = ", ")))

  # =========================================================================
  # Step 3: Run Monte Carlo projections
  # =========================================================================
  cat("\n--- STEP 3: Monte Carlo Projections ---\n")
  mc_results <- run_monte_carlo(data_list, scenarios, CONFIG)

  # --- Save raw MC outputs IMMEDIATELY (crash-safe checkpoint) ------------
  cat("\n  Checkpointing Monte Carlo outputs...\n")
  tryCatch(
    write_csv(mc_results$all_summaries,
              file.path(output_dir, "raw_mc_summaries.csv")),
    error = function(e) message("  warn: could not write raw_mc_summaries: ", e$message)
  )
  tryCatch(
    write_csv(mc_results$ci_summaries,
              file.path(output_dir, "ci_summaries.csv")),
    error = function(e) message("  warn: could not write ci_summaries: ", e$message)
  )

  # Save per-plot projections RIGHT AWAY for state-level expansion
  if (isTRUE(CONFIG$save_per_plot)) {
    cat("  Saving per-plot projections for state expansion...\n")
    keep_cols <- c("scenario", "sim", "cycle", "STATECD", "COUNTYCD",
                   "PLOT", "CONDID", "PLT_CN", "CONDPROP_UNADJ", "INVYR",
                   "OWNGRPCD", "FORTYPCD", "STDORGCD", "SITECLCD", "STDAGE",
                   "dom_spcd",
                   "proj_BA", "proj_volcfnet", "proj_volcsnet",
                   "proj_drybio", "proj_carbon",
                   "proj_tpa", "proj_qmd", "tpa_live", "qmd",
                   "was_harvested", "was_planted", "was_unmatched",
                   "is_clearcut", "harvest_intensity",
                   "harv_c_total", "harv_c_saw", "harv_c_pulp", "harv_c_residue",  # R-hwpEmit

                   "was_disturbed_sbw", "was_disturbed_wind", "was_disturbed_fire",
                   "LAT", "LON")
    per_plot <- lapply(names(mc_results$all_results), function(scen_nm) {
      df <- mc_results$all_results[[scen_nm]]
      cols <- intersect(keep_cols, names(df))
      df |> select(all_of(cols)) |> mutate(scenario = scen_nm, .before = 1)
    })
    per_plot_df <- bind_rows(per_plot)
    saveRDS(per_plot_df, file.path(output_dir, "per_plot_projections.rds"),
            compress = "xz")
    cat(sprintf("    Wrote %d rows to per_plot_projections.rds\n", nrow(per_plot_df)))
  }

  # =========================================================================
  # Step 4: Estimate timber supply curves (optional, skippable)
  # =========================================================================
  supply_curve <- NULL
  elasticity   <- NULL
  if (!isTRUE(cli_args$skip_supply)) {
    cat("\n--- STEP 4: Timber Supply Estimation ---\n")
    tryCatch({
      supply_curve <- generate_supply_curve(
        data_list$subjects,
        price_range = seq(0.5, 2.0, by = 0.1),
        cfg = CONFIG,
        n_mc = min(CONFIG$n_simulations, 50)
      )
      elasticity <- estimate_supply_elasticity(supply_curve)
      write_csv(supply_curve, file.path(output_dir, "supply_curve.csv"))
      p_supply <- plot_supply_curve(supply_curve)
      ggsave(file.path(output_dir, "fig_supply_curve.png"),
             p_supply, width = 17.5, height = 12, units = "cm",
             dpi = CONFIG$reporting$fig_dpi, bg = "white")
      supply_traj <- project_supply_trajectory(mc_results)
      write_csv(supply_traj, file.path(output_dir, "supply_trajectory.csv"))
    }, error = function(e) {
      message("  Supply curve step failed: ", e$message,
              " - continuing to report generation")
    })
  } else {
    cat("\n--- STEP 4: Timber Supply Estimation SKIPPED (--skip_supply) ---\n")
  }

  # =========================================================================
  # Step 5: Generate report
  # =========================================================================
  cat("\n--- STEP 5: Report Generation ---\n")
  tryCatch(
    generate_report(mc_results, output_dir, CONFIG),
    error = function(e) message("  Report generation failed: ", e$message)
  )

  # =========================================================================
  # Done
  # =========================================================================
  cat("\n")
  cat("================================================================\n")
  cat(sprintf("  Projection complete for %s\n", CONFIG$target_state))
  cat(sprintf("  Results saved to: %s\n", output_dir))
  cat(sprintf("  Scenarios: %d | Simulations: %d | Cycles: %d\n",
              length(scenarios), CONFIG$n_simulations, CONFIG$n_cycles))
  cat("================================================================\n\n")

  # Return results invisibly for interactive use
  invisible(list(
    mc_results   = mc_results,
    supply_curve = supply_curve,
    elasticity   = elasticity,
    data_list    = data_list,
    config       = CONFIG
  ))
}

# --- Helper: all available FIA states for CONUS-wide donor pool --------------
# Returns the set of states with COND/TREE/PLOT files in FIA_DATA_DIR. Used
# with --conus_donors so the donor pool spans CONUS and the cem_ecoregion
# matching key (Layer 7b) restricts matches to same-ecoregion donors.
get_all_available_states <- function() {
  data_dir <- Sys.getenv("FIA_DATA_DIR", unset = file.path(Sys.getenv("HOME"), "fia_data"))
  cond_files <- list.files(data_dir, pattern = "_COND\\.csv$")
  states <- unique(sub("_COND\\.csv$", "", cond_files))
  states <- states[nchar(states) == 2]  # two-letter postal codes only
  if (length(states) == 0) {
    warning("get_all_available_states found no _COND.csv files; falling back to single state")
  }
  states
}

# --- Helper: get neighboring/donor states by region --------------------------
get_donor_states <- function(state) {
  neighbors <- list(
    ME = c("ME", "NH", "VT", "NY", "MA", "CT", "RI"),
    NH = c("NH", "ME", "VT", "MA", "CT"),
    VT = c("VT", "NH", "NY", "MA", "ME"),
    NY = c("NY", "VT", "NJ", "PA", "CT", "MA"),
    PA = c("PA", "NY", "NJ", "MD", "WV", "OH"),
    WI = c("WI", "MN", "MI", "IA", "IL"),
    MN = c("MN", "WI", "MI", "IA"),
    MI = c("MI", "WI", "MN", "OH", "IN"),
    GA = c("GA", "FL", "SC", "NC", "TN", "AL"),
    NC = c("NC", "SC", "VA", "TN", "GA"),
    SC = c("SC", "NC", "GA"),
    VA = c("VA", "WV", "NC", "MD", "KY", "TN"),
    OR = c("OR", "WA", "CA", "ID"),
    WA = c("WA", "OR", "ID", "MT")
  )

  if (state %in% names(neighbors)) {
    return(neighbors[[state]])
  }

  # Default: return just the target state
  return(state)
}

# --- Run if executed as script -----------------------------------------------
if (!interactive() || identical(Sys.getenv("RUN_MAIN"), "TRUE")) {
  results <- main()
}
