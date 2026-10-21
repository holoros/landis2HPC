# =============================================================================
# Title: Multi-scenario Comparison Figure for FIA CEM Projections (Maine)
# Author: A. Weiskittel
# Date: 2026-04-17
# Description: Combines CI tables from multiple CEM projection runs into a
#              single publication-ready figure showing MMT AGC, total volume,
#              merchantable volume, and relative density trajectories with
#              95 percent Monte Carlo uncertainty ribbons per scenario.
# Dependencies: tidyverse, ggplot2, ggtext, patchwork
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(ggplot2)
  library(ggtext)
  library(patchwork)
})

# --- Paths -------------------------------------------------------------------
STATE_EXPANSION_DIR <- "~/fia_cem_projections/output/state_mmt"
OUT_DIR             <- "~/fia_cem_projections/output/figures"
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# --- Theme and palette -------------------------------------------------------
theme_pub <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey90", linewidth = 0.25),
    axis.title       = element_text(size = 11),
    axis.text        = element_text(size = 9),
    legend.position  = "bottom",
    legend.title     = element_text(size = 10),
    legend.text      = element_text(size = 9),
    strip.text       = element_text(size = 10, face = "bold"),
    plot.title       = element_text(size = 12, face = "bold"),
    plot.subtitle    = element_text(size = 10, color = "grey30"),
    plot.caption     = element_text(size = 8, color = "grey40"),
    plot.margin      = margin(8, 8, 8, 8)
  )

scenario_colors <- c(
  "No_harvest"           = "#1B7C3D",
  "BAU"                  = "#2C3E50",
  "CC_proxy"             = "#E74C3C",
  "Harvest_m25_mill"     = "#3498DB",
  "Harvest_p25_pulp"     = "#F39C12",
  "Harvest_p50_biomass"  = "#8E44AD"
)

scenario_labels <- c(
  "No_harvest"          = "No harvest (Q = 0)",
  "BAU"                 = "Business as usual",
  "CC_proxy"            = "Climate change (disturbance proxy)",
  "Harvest_m25_mill"    = "Mill closure (\u221225% harvest)",
  "Harvest_p25_pulp"    = "Pulp recovery (+25% harvest)",
  "Harvest_p50_biomass" = "Biomass surge (+50% harvest)"
)

# Order scenarios from lowest to highest harvest pressure for consistent
# legend ordering across panels.
scenario_order <- c("No_harvest", "Harvest_m25_mill", "BAU",
                    "CC_proxy", "Harvest_p25_pulp", "Harvest_p50_biomass")

# --- Read CI outputs ---------------------------------------------------------

#' Read all *_ci.csv files in the state_mmt directory, tagging each with
#' the originating scenario set (derived from the file stem).
#' For each scenario, keep the run whose file stem "matches" the scenario.
#' This deduplicates BAU (which appears in many runs) to a single current-era
#' curve (from bau_v4) and keeps the 1999-baseline BAU separately.
select_scenario_runs <- function(ci_df) {
  priority_for <- function(scenario, run) {
    s <- tolower(scenario); r <- tolower(run)
    if (grepl("1999", r))              return(1L)  # always keep 1999 baseline
    if (s == "bau"        && grepl("^bau_v",  r)) return(1L)
    if (s == "cc_proxy"   && grepl("climate", r)) return(1L)
    if (grepl("^harvest", s) && grepl("harvest", r)) return(1L)
    if (s == "no_harvest"    && grepl("harvest", r)) return(1L)
    3L
  }
  ci_df |>
    rowwise() |>
    mutate(.prio = priority_for(scenario, run)) |>
    ungroup() |>
    group_by(scenario, era = if_else(grepl("1999", run), "1999", "current"), cycle) |>
    filter(.prio == min(.prio)) |>
    slice(1) |>
    ungroup() |>
    select(-.prio, -era)
}

load_ci <- function(dir = STATE_EXPANSION_DIR) {
  files <- list.files(dir, pattern = "_ci\\.csv$", full.names = TRUE)
  if (length(files) == 0) stop("No *_ci.csv files in ", dir)
  map_dfr(files, function(f) {
    stem <- sub("_ci\\.csv$", "", basename(f))
    stem <- sub("^state_metrics_", "", stem)
    stem <- sub("^state_mmt_",     "", stem)
    df <- read_csv(f, show_col_types = FALSE)
    df |> mutate(run = stem)
  })
}

# --- Build a single-metric panel ---------------------------------------------

plot_metric <- function(df, metric, mean_col, lo_col, hi_col,
                        y_label, title_txt) {
  d <- df |> filter(!is.na(.data[[mean_col]]))
  if (nrow(d) == 0) {
    return(ggplot() + labs(title = title_txt, x = NULL, y = y_label) + theme_pub)
  }

  # Differentiate current-era vs historical baseline runs via linetype
  d <- d |>
    mutate(run_type = if_else(grepl("1999", run), "1999 baseline",
                               "Current-era start"))

  ggplot(d, aes(x = year,
                y = .data[[mean_col]],
                ymin = .data[[lo_col]],
                ymax = .data[[hi_col]],
                fill = scenario, color = scenario,
                linetype = run_type,
                group = interaction(scenario, run))) +
    geom_ribbon(alpha = 0.15, color = NA) +
    geom_line(linewidth = 0.7) +
    geom_point(size = 1.3) +
    scale_color_manual(values = scenario_colors, labels = scenario_labels,
                       name = "Scenario", na.value = "grey70") +
    scale_fill_manual(values  = scenario_colors, labels = scenario_labels,
                      name = "Scenario", na.value = "grey70") +
    scale_linetype_manual(values = c("Current-era start" = "solid",
                                     "1999 baseline"     = "22"),
                          name = "Run") +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 8)) +
    labs(x = NULL, y = y_label, title = title_txt) +
    theme_pub +
    theme(axis.title.y = element_markdown(),
          plot.title   = element_text(size = 11))
}

# --- Compose the multi-panel figure ------------------------------------------

build_figure <- function(ci_df,
                         observed_df = NULL,
                         anchor_to_observed = TRUE,
                         anchor_year = NULL,
                         out_prefix = file.path(OUT_DIR, "fig_maine_scenarios")) {

  # Separate observed values from projected scenarios
  if (is.null(observed_df) && "OBSERVED" %in% ci_df$scenario) {
    observed_df <- ci_df |> filter(scenario == "OBSERVED")
    ci_df       <- ci_df |> filter(scenario != "OBSERVED")
  }

  # Keep only scenarios we have colors for; tag unknowns as "Other"
  ci_df <- ci_df |>
    mutate(scenario = if_else(scenario %in% names(scenario_colors),
                              scenario, "Other"))

  # NOTE: ci_df should be pre-deduplicated by the caller. See
  # select_scenario_runs() for the standard selection logic.

  # COMMON STARTING POINT: for each scenario-run, rescale the projected
  # trajectory so its first cycle equals the observed current-era anchor.
  # Then prepend a cycle-0 anchor row so all scenarios visibly start at the
  # same MMT AGC (the actual FIA 2024 state total).
  if (isTRUE(anchor_to_observed) && !is.null(observed_df) && nrow(observed_df) > 0) {
    anchor_yr <- anchor_year %||% observed_df$year[1]
    obs_agc   <- observed_df$mmt_agc_mean[1]
    obs_bio   <- observed_df$mmt_biomass_mean[1]
    obs_vol   <- observed_df$total_vol_mcf_mean[1]
    obs_merch <- observed_df$merch_vol_mcf_mean[1]

    # Compute per-run scale factors from the first cycle's projected mean
    scales <- ci_df |>
      group_by(scenario, run) |>
      arrange(cycle) |>
      slice_head(n = 1) |>
      ungroup() |>
      transmute(
        scenario, run,
        scale_agc   = obs_agc   / mmt_agc_mean,
        scale_bio   = obs_bio   / mmt_biomass_mean,
        scale_vol   = obs_vol   / total_vol_mcf_mean,
        scale_merch = obs_merch / merch_vol_mcf_mean
      ) |>
      mutate(across(starts_with("scale_"),
                    ~ ifelse(is.finite(.) & . > 0, ., 1)))

    ci_df <- ci_df |>
      left_join(scales, by = c("scenario","run")) |>
      mutate(
        across(c(mmt_agc_mean, mmt_agc_lo, mmt_agc_hi),                        ~ . * scale_agc),
        across(c(mmt_biomass_mean, mmt_biomass_lo, mmt_biomass_hi),            ~ . * scale_bio),
        across(c(total_vol_mcf_mean, total_vol_mcf_lo, total_vol_mcf_hi),      ~ . * scale_vol),
        across(c(merch_vol_mcf_mean, merch_vol_mcf_lo, merch_vol_mcf_hi),      ~ . * scale_merch)
      ) |>
      select(-starts_with("scale_"))

    # Prepend cycle-0 anchor rows (one per scenario-run)
    anchor_rows <- ci_df |>
      distinct(scenario, run) |>
      mutate(cycle = 0L, year = anchor_yr,
             mmt_agc_mean       = obs_agc,
             mmt_agc_lo         = obs_agc,
             mmt_agc_hi         = obs_agc,
             mmt_biomass_mean   = obs_bio,
             mmt_biomass_lo     = obs_bio,
             mmt_biomass_hi     = obs_bio,
             total_vol_mcf_mean = obs_vol,
             total_vol_mcf_lo   = obs_vol,
             total_vol_mcf_hi   = obs_vol,
             merch_vol_mcf_mean = obs_merch,
             merch_vol_mcf_lo   = obs_merch,
             merch_vol_mcf_hi   = obs_merch)
    for (col in setdiff(names(ci_df), names(anchor_rows))) {
      anchor_rows[[col]] <- NA
    }
    ci_df <- bind_rows(anchor_rows, ci_df) |>
      arrange(scenario, run, cycle)
  }

  add_reference <- function(p, obs_df, metric_col) {
    if (is.null(obs_df) || nrow(obs_df) == 0) return(p)
    val <- obs_df[[paste0(metric_col, "_mean")]][1]
    yr  <- obs_df$year[1]
    if (is.na(val)) return(p)
    p +
      geom_hline(yintercept = val, linetype = "dotted",
                 color = "grey30", linewidth = 0.45) +
      annotate("text", x = yr, y = val,
               label = sprintf("FIA obs (%d) = %.0f", yr, val),
               hjust = 0.5, vjust = -0.35, size = 2.6, color = "grey25")
  }

  p_agc <- plot_metric(
    ci_df, "mmt_agc", "mmt_agc_mean", "mmt_agc_lo", "mmt_agc_hi",
    y_label = "Aboveground C (MMT)",
    title_txt = "A) Aboveground carbon"
  ) |> add_reference(observed_df, "mmt_agc")

  p_totvol <- plot_metric(
    ci_df, "total_vol_mcf", "total_vol_mcf_mean",
    "total_vol_mcf_lo", "total_vol_mcf_hi",
    y_label = "Total volume (10<sup>6</sup> ft<sup>3</sup>)",
    title_txt = "B) Total volume (net cubic)"
  ) |> add_reference(observed_df, "total_vol_mcf")

  p_merch <- plot_metric(
    ci_df, "merch_vol_mcf", "merch_vol_mcf_mean",
    "merch_vol_mcf_lo", "merch_vol_mcf_hi",
    y_label = "Merchantable volume (10<sup>6</sup> ft<sup>3</sup>)",
    title_txt = "C) Merchantable volume (sawlog)"
  ) |> add_reference(observed_df, "merch_vol_mcf")

  p_rd <- plot_metric(
    ci_df, "rd_mean_wtd", "rd_mean_wtd_mean",
    "rd_mean_wtd_lo", "rd_mean_wtd_hi",
    y_label = "Relative density (SDI / SDI<sub>max</sub>)",
    title_txt = "D) Area-weighted relative density"
  )

  combined <- (p_agc + p_totvol) / (p_merch + p_rd) +
    plot_layout(guides = "collect") +
    plot_annotation(
      title    = "Maine forest trajectories under alternative scenarios",
      subtitle = "FIA CEM plot-matching projections, ribbons = 95% Monte Carlo intervals",
      caption  = paste(
        "State expansion uses FIA EXPNS from POP_STRATUM.",
        "SDImax from Woodall & Weiskittel (2021).",
        "RD = SDI / SDImax, area-weighted across condition-plots.",
        sep = "\n")
    ) &
    theme(legend.position = "bottom")

  # Wider canvas so panel titles and legend fit all 5 scenarios
  ggsave(paste0(out_prefix, ".png"), combined,
         width = 28, height = 19, units = "cm",
         dpi = 300, bg = "white")
  ggsave(paste0(out_prefix, ".pdf"), combined,
         width = 28, height = 19, units = "cm")
  cat(sprintf("Wrote %s.png and %s.pdf\n", out_prefix, out_prefix))
  invisible(combined)
}

# --- CLI entry (guarded by sentinel so run_projection.R's source loop won't trigger it) ---
if (!interactive() && identical(Sys.getenv("RUN_COMPARE_FIGURE"), "TRUE")) {
  args <- commandArgs(trailingOnly = TRUE)
  indir  <- if (length(args) >= 1) args[1] else STATE_EXPANSION_DIR
  outdir <- if (length(args) >= 2) args[2] else OUT_DIR
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

  ci <- load_ci(indir)
  cat(sprintf("Loaded %d rows across %d runs and %d scenarios\n",
              nrow(ci), length(unique(ci$run)), length(unique(ci$scenario))))
  build_figure(ci, out_prefix = file.path(outdir, "fig_maine_scenarios"))
}
