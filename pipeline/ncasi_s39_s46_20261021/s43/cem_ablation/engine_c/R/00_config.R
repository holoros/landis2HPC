# =============================================================================
# Title: FIA Plot Matching Configuration
# Author: A. Weiskittel
# Date: 2026-03-19
# Description: Central configuration for the FIA CEM plot matching and
#              projection system. All user-adjustable parameters live here.
# References:
#   Van Deusen & Roesch (2013) MCFNS 5(2):126-134
#   Wear & Coulston (2025) Forest Policy & Economics 178:103542
# =============================================================================

# --- Project paths -----------------------------------------------------------

CONFIG <- list(

  # Root directories
  project_dir   = here::here(),
  data_dir      = here::here("data"),
  output_dir    = here::here("output"),
  config_dir    = here::here("config"),

  # --- FIA data access -------------------------------------------------------
  # Options: "rfia" (uses rFIA package), "direct" (reads CSV/SQLite files)
  fia_access    = "rfia",

  # For direct access: path to FIA database files (CSV or SQLite)
  fia_db_path   = NULL,  # e.g., "/path/to/FIA_data/"

  # --- State and region settings ---------------------------------------------
  # Primary state for analysis
  target_state  = "ME",

  # Additional states for donor plot pool (neighbors or ecologically similar)
  donor_states  = c("ME", "NH", "VT", "NY", "MA", "CT", "RI"),

  # RPA subregion mapping (from Wear & Coulston 2025, Fig. 1)
  # NE = Northeast, NC = North-Central, SE = Southeast, SC = South-Central,

  # PC = Pacific Coast, PNW = Pacific Northwest, PL = Plains,
  # RN = Rockies North, RS = Rockies South
  rpa_region    = "NE",

  # --- Projection settings ---------------------------------------------------
  # Number of projection cycles (each cycle = remeasurement interval)
  n_cycles         = 3,

  # Nominal cycle length in years (5 for eastern FIA, 10 for western)
  cycle_length_yrs = 5,

  # Moving window width for trend estimation (years)
  moving_window    = 3,

  # Number of Monte Carlo realizations for stochastic projections
  n_simulations    = 100,

  # Random seed for reproducibility
  seed             = 42,

  # --- CEM matching parameters -----------------------------------------------
  cem = list(
    use_productivity = FALSE,
    # Variables used in matching (in order of importance)
    match_vars = c("CONDPROP_C", "OWNGRPCD", "FORTYPCD", "STDORGCD",
                   "SITECLCD", "STDAGE_C", "BA_C"),

    # Iteration 1: Fine coarsening
    iter1 = list(
      condprop_breaks = c(0, 0.25, 0.50, 0.75, 1.0),
      asym_breaks     = c(180, 200, 220, 250),
      stdage_breaks   = c(0, 10, 20, 30, 40, 60, 80, Inf),
      ba_breaks       = seq(0, 300, by = 20),
      siteclcd_coarsen = FALSE,
      owngrpcd_coarsen = FALSE
    ),

    # Iteration 2: Medium coarsening (for unmatched from iter 1)
    iter2 = list(
      stdage_breaks   = c(0, 30, 80, Inf),
      ba_breaks       = c(0, 30, 120, Inf),
      siteclcd_breaks = c(0, 2, 5, Inf),
      asym_breaks     = c(200, 240),
      owngrpcd_map    = list(
        "Federal"   = c(1, 2),
        "State_loc" = c(3),
        "Private"   = c(4)
      )
    ),

    # Iteration 3: Coarse matching (last resort)
    iter3 = list(
      stdage_breaks   = c(0, 40, Inf),
      ba_breaks       = c(0, 50, Inf),
      asym_breaks     = c(210),
      siteclcd_breaks = c(0, 3, Inf),
      drop_owngrpcd   = TRUE
    )
  ),

  # --- Harvest choice model (Wear & Coulston 2025) ---------------------------
  harvest = list(
    # Whether to use economic harvest choice model vs. simple CEM biasing
    use_economic_model = TRUE,

    # Discount rate for present value calculations
    discount_rate = 0.04,

    # Ownership categories: "commercial", "family", "other_private", "public"
    # Coefficients loaded from config/harvest_coefficients.csv
    coeff_file = "config/harvest_coefficients.csv",

    # Price scenario: "constant", "increasing", "decreasing", "custom"
    price_scenario = "constant",

    # Base prices ($/MBF for sawtimber, $/cord for pulpwood) by species group
    # These are defaults; override with custom price file
    base_prices = list(
      sawtimber = list(
        softwood = 250,   # $/MBF
        hardwood = 350    # $/MBF
      ),
      pulpwood = list(
        softwood = 12,    # $/cord
        hardwood = 10     # $/cord
      )
    )
  ),

  # --- Scenario biasing (Van Deusen & Roesch 2013) ---------------------------
  scenarios = list(
    # Q values for harvest scenario biasing
    # Q = 1.0: BAU, Q = 1.5: +50% harvest, Q = 0.5: -50% harvest
    harvest_Q = c(0.5, 1.0, 1.5, 2.0),

    # Named event types that can be biased
    event_types = c("harvest", "fire", "insect", "wind", "land_use_change"),

    # Default Q values per event type (BAU = 1.0)
    default_Q = list(
      harvest         = 1.0,
      fire            = 1.0,
      insect          = 1.0,
      wind            = 1.0,
      land_use_change = 1.0
    )
  ),

  # --- Tree planting model (Wear & Coulston 2025) ----------------------------
  planting = list(
    # Whether to model planting decisions
    model_planting = TRUE,

    # Coefficients loaded from config/planting_coefficients.csv
    coeff_file = "config/planting_coefficients.csv"
  ),

  # --- Climate integration ---------------------------------------------------
  climate = list(
    # Whether to incorporate climate in matching/projection
    use_climate = FALSE,

    # Climate data source: "generic", "climatena", "worldclim", "maca"
    source = "generic",

    # Path to climate data file (CSV with plot_id, year, temp, precip, etc.)
    # If NULL, auto-detects from data_dir/climate/climate_combined_{state}.csv
    data_file = NULL,

    # Auto-detect climate file from download script output
    auto_detect = TRUE,

    # SSP scenario for CMIP6 projections
    ssp = "ssp245",

    # GCM models to average over (if using CMIP6)
    gcm_models = c("CanESM5", "MIROC6", "MPI-ESM1-2-HR", "UKESM1-0-LL"),

    # Climate variables to use in matching
    match_vars = c("mat", "map", "cmd"),

    # Coarsening for climate variables
    mat_breaks = c(-Inf, 4, 6, 8, 10, Inf),      # mean annual temp (C)
    map_breaks = c(-Inf, 800, 1000, 1200, Inf)    # mean annual precip (mm)
  ),

  # --- Landowner behavior module ---------------------------------------------
  landowner = list(
    # Ownership groups for differential behavior
    groups = c("public", "family", "commercial", "other_private"),

    # Relative harvest propensity multipliers (1.0 = baseline)
    harvest_propensity = list(
      public         = 0.5,
      family         = 1.0,
      commercial     = 1.5,
      other_private  = 1.2
    )
  ),

  # --- Natural disturbance settings ------------------------------------------
  disturbance = list(
    # Whether to model disturbance probability changes over time
    dynamic_disturbance = FALSE,

    # Base annual probabilities (from FIA observations)
    base_rates = list(
      fire   = 0.001,
      insect = 0.005,
      wind   = 0.002
    ),

    # Climate sensitivity multipliers (change in probability per degree C warming)
    climate_sensitivity = list(
      fire   = 0.10,  # 10% increase per degree C
      insect = 0.05,  # 5% increase per degree C
      wind   = 0.02   # 2% increase per degree C
    )
  ),

  # --- Output and reporting --------------------------------------------------
  reporting = list(
    # Variables to summarize in output
    summary_vars = c("VOLCFNET", "DRYBIO_AG", "CARBON_AG", "BA",
                     "TPA_UNADJ", "REMPER"),

    # Aggregation levels for reporting
    group_by = c("STATECD", "OWNGRPCD", "FORTYPGRPCD"),

    # Whether to generate figures automatically
    auto_figures = TRUE,

    # Figure format
    fig_format = "png",
    fig_dpi    = 300
  )
)

# --- Helper: print configuration summary ------------------------------------
print_config <- function(cfg = CONFIG) {
  cat("=== FIA Plot Matching Configuration ===\n")
  cat(sprintf("  Target state: %s\n", cfg$target_state))
  cat(sprintf("  Donor states: %s\n", paste(cfg$donor_states, collapse = ", ")))
  cat(sprintf("  RPA region: %s\n", cfg$rpa_region))
  cat(sprintf("  Projection cycles: %d x %d years\n",
              cfg$n_cycles, cfg$cycle_length_yrs))
  cat(sprintf("  Simulations: %d\n", cfg$n_simulations))
  cat(sprintf("  FIA access: %s\n", cfg$fia_access))
  cat(sprintf("  Economic harvest model: %s\n",
              ifelse(cfg$harvest$use_economic_model, "yes", "no")))
  cat(sprintf("  Climate integration: %s\n",
              ifelse(cfg$climate$use_climate, "yes", "no")))
  cat(sprintf("  Planting model: %s\n",
              ifelse(cfg$planting$model_planting, "yes", "no")))
  cat("=======================================\n")
}
