# =============================================================================
# Title: Summary Reporting and Visualization
# Author: A. Weiskittel
# Date: 2026-03-19
# Description: Generates summary tables, figures, and reports from projection
#              results. Publication-ready ggplot2 figures following
#              Weiskittel lab standards.
# Dependencies: 00_config.R, 06_projection_engine.R
# =============================================================================

library(tidyverse)
library(ggplot2)
library(patchwork)

# --- Publication theme -------------------------------------------------------
theme_pub <- theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    axis.title       = element_text(size = 12),
    axis.text        = element_text(size = 10),
    legend.position  = "bottom",
    legend.title     = element_text(size = 10),
    legend.text      = element_text(size = 9),
    strip.text       = element_text(size = 11, face = "bold"),
    plot.title       = element_text(size = 14, face = "bold"),
    plot.margin      = margin(10, 10, 10, 10)
  )

# Scenario colors
scenario_colors <- c(
  "BAU"           = "#009E73",
  "Harvest_m50"   = "#56B4E9",
  "Harvest_p50"   = "#E69F00",
  "Harvest_p100"  = "#D55E00",
  "High_fire"     = "#CC79A7",
  "High_insect"   = "#0072B2",
  "High_price"    = "#F0E442",
  "Low_price"     = "#999999"
)

# =============================================================================
# 1. Growth/Removals Ratio Table (Van Deusen Table 2 format)
# =============================================================================

#' Generate G/R ratio table across scenarios
#' @param mc_results Output from run_monte_carlo()
#' @param cfg Configuration
#' @return Formatted tibble
table_gr_ratios <- function(mc_results, cfg = CONFIG) {

  mc_results$ci_summaries |>
    select(scenario, cycle, gr_ratio_mean, gr_ratio_lo, gr_ratio_hi) |>
    mutate(
      year = max(0) + cycle * cfg$cycle_length_yrs,  # approximate projection year
      gr_formatted = sprintf("%.3f (%.3f, %.3f)",
                             gr_ratio_mean, gr_ratio_lo, gr_ratio_hi)
    ) |>
    select(scenario, cycle, year, gr_formatted) |>
    pivot_wider(names_from = scenario, values_from = gr_formatted)
}

# =============================================================================
# 2. Inventory Summary Table
# =============================================================================

#' Generate inventory summary across projection cycles
#' @param mc_results Output from run_monte_carlo()
#' @return Formatted summary table
table_inventory_summary <- function(mc_results) {

  mc_results$ci_summaries |>
    select(scenario, cycle,
           mean_ba_mean, mean_vol_mean, mean_carbon_mean,
           total_tpa_mean, harvest_rate_mean, plant_rate_mean) |>
    mutate(
      across(c(mean_ba_mean, mean_vol_mean, mean_carbon_mean, total_tpa_mean),
             ~ round(., 1)),
      across(c(harvest_rate_mean, plant_rate_mean),
             ~ sprintf("%.1f%%", . * 100))
    )
}

# =============================================================================
# 3. Projection Trajectory Figure
# =============================================================================

#' Plot inventory trajectories across scenarios with CI bands
#' @param mc_results Output from run_monte_carlo()
#' @param variable Variable to plot ("mean_vol", "mean_ba", "mean_carbon")
#' @param y_label Y-axis label
#' @param title Plot title
#' @return ggplot object
plot_projection_trajectory <- function(mc_results,
                                        variable = "mean_vol",
                                        y_label = expression(paste("Volume (ft"^3, " ac"^-1, ")")),
                                        title = "Projected Forest Volume by Scenario") {

  var_mean <- paste0(variable, "_mean")
  var_lo   <- paste0(variable, "_lo")
  var_hi   <- paste0(variable, "_hi")

  p <- mc_results$ci_summaries |>
    ggplot(aes(x = cycle, color = scenario, fill = scenario)) +
    geom_ribbon(aes(ymin = .data[[var_lo]], ymax = .data[[var_hi]]),
                alpha = 0.15, color = NA) +
    geom_line(aes(y = .data[[var_mean]]), linewidth = 1) +
    geom_point(aes(y = .data[[var_mean]]), size = 2) +
    scale_color_manual(values = scenario_colors, name = "Scenario") +
    scale_fill_manual(values = scenario_colors, name = "Scenario") +
    labs(x = "Projection Cycle", y = y_label, title = title) +
    theme_pub

  return(p)
}

# =============================================================================
# 4. G/R Ratio Figure
# =============================================================================

#' Plot G/R ratios by scenario over time
#' @param mc_results Output from run_monte_carlo()
#' @return ggplot object
plot_gr_ratios <- function(mc_results) {

  p <- mc_results$ci_summaries |>
    ggplot(aes(x = cycle, y = gr_ratio_mean, color = scenario)) +
    geom_hline(yintercept = 1.0, linetype = "dashed", color = "grey40") +
    geom_ribbon(aes(ymin = gr_ratio_lo, ymax = gr_ratio_hi, fill = scenario),
                alpha = 0.15, color = NA) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    scale_color_manual(values = scenario_colors, name = "Scenario") +
    scale_fill_manual(values = scenario_colors, name = "Scenario") +
    labs(
      x = "Projection Cycle",
      y = "Gross Growth / Harvest Removals",
      title = "Growth to Removals Ratio by Scenario"
    ) +
    annotate("text", x = 0.5, y = 0.95, label = "Unsustainable",
             hjust = 0, color = "grey50", size = 3) +
    annotate("text", x = 0.5, y = 1.05, label = "Sustainable",
             hjust = 0, color = "grey50", size = 3) +
    theme_pub

  return(p)
}

# =============================================================================
# 5. Harvest Rate and Planting Figure
# =============================================================================

#' Plot harvest rates and planting rates by scenario
#' @param mc_results Output from run_monte_carlo()
#' @return ggplot object (patchwork)
plot_harvest_planting <- function(mc_results) {

  p1 <- mc_results$ci_summaries |>
    ggplot(aes(x = cycle, y = harvest_rate_mean * 100, color = scenario)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    scale_color_manual(values = scenario_colors, name = "Scenario") +
    labs(x = "Cycle", y = "Harvest Rate (%)",
         title = "A) Annual Harvest Rate") +
    theme_pub + theme(legend.position = "none")

  p2 <- mc_results$ci_summaries |>
    ggplot(aes(x = cycle, y = plant_rate_mean * 100, color = scenario)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2) +
    scale_color_manual(values = scenario_colors, name = "Scenario") +
    labs(x = "Cycle", y = "Planting Rate (%)",
         title = "B) Planting Rate (post harvest)") +
    theme_pub + theme(legend.position = "none")

  combined <- (p1 | p2) +
    plot_layout(guides = "collect") &
    theme(legend.position = "bottom")

  return(combined)
}

# =============================================================================
# 6. Supply Curve Figure
# =============================================================================

#' Plot timber supply curve
#' @param supply_curve Output from generate_supply_curve()
#' @return ggplot object
plot_supply_curve <- function(supply_curve) {

  p <- supply_curve |>
    ggplot(aes(x = supply_mean, y = price_index)) +
    geom_ribbon(aes(xmin = supply_lo, xmax = supply_hi),
                alpha = 0.2, fill = "#009E73") +
    geom_line(linewidth = 1, color = "#009E73") +
    geom_point(size = 2, color = "#009E73") +
    geom_vline(
      xintercept = supply_curve$supply_mean[supply_curve$price_index == 1.0],
      linetype = "dashed", color = "grey50"
    ) +
    geom_hline(yintercept = 1.0, linetype = "dashed", color = "grey50") +
    labs(
      x = expression(paste("Harvest Volume (ft"^3, " ac"^-1, ")")),
      y = "Price Index (1.0 = Current)",
      title = "Timber Supply Curve"
    ) +
    theme_pub

  return(p)
}

# =============================================================================
# 7. CEM Match Quality Diagnostics
# =============================================================================

#' Plot CEM match quality diagnostics
#' @param cem_result Output from run_cem_matching()
#' @return ggplot object
plot_match_diagnostics <- function(cem_result) {

  matches <- cem_result$all_matches

  # Distribution of matches per subject
  match_counts <- matches |>
    count(subject_row, name = "n_matches")

  p1 <- ggplot(match_counts, aes(x = n_matches)) +
    geom_histogram(binwidth = 5, fill = "#56B4E9", color = "white") +
    labs(x = "Number of Donor Matches", y = "Count of Subject Conditions",
         title = "A) Match Multiplicity") +
    theme_pub

  # CEM iteration distribution
  iter_counts <- matches |>
    distinct(subject_row, .keep_all = TRUE) |>
    count(cem_iteration)

  p2 <- ggplot(iter_counts, aes(x = factor(cem_iteration), y = n)) +
    geom_col(fill = c("#009E73", "#E69F00", "#D55E00")[1:nrow(iter_counts)]) +
    labs(x = "CEM Iteration", y = "Subjects Matched",
         title = "B) Matching Iteration") +
    theme_pub

  combined <- p1 | p2

  return(combined)
}

# =============================================================================
# 8. Full Report Generation
# =============================================================================

#' Generate complete projection report with all figures and tables
#' @param mc_results Output from run_monte_carlo()
#' @param output_dir Directory to save outputs
#' @param cfg Configuration
generate_report <- function(mc_results, output_dir = "output", cfg = CONFIG) {

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  cat("=== Generating Projection Report ===\n")

  # Tables
  cat("  Saving tables...\n")
  gr_table <- table_gr_ratios(mc_results, cfg)
  write_csv(gr_table, file.path(output_dir, "table_gr_ratios.csv"))

  inv_table <- table_inventory_summary(mc_results)
  write_csv(inv_table, file.path(output_dir, "table_inventory_summary.csv"))

  # Figures
  cat("  Generating figures...\n")
  fmt <- cfg$reporting$fig_format
  dpi <- cfg$reporting$fig_dpi

  # Volume trajectory
  p_vol <- plot_projection_trajectory(mc_results, "mean_vol")
  ggsave(file.path(output_dir, paste0("fig_volume_trajectory.", fmt)),
         p_vol, width = 20, height = 12, units = "cm", dpi = dpi, bg = "white")

  # BA trajectory
  p_ba <- plot_projection_trajectory(
    mc_results, "mean_ba",
    y_label = expression(paste("Basal area (ft"^2, " ac"^-1, ")")),
    title = "Projected Basal Area by Scenario"
  )
  ggsave(file.path(output_dir, paste0("fig_ba_trajectory.", fmt)),
         p_ba, width = 20, height = 12, units = "cm", dpi = dpi, bg = "white")

  # Carbon trajectory
  p_c <- plot_projection_trajectory(
    mc_results, "mean_carbon",
    y_label = expression(paste("Carbon (tons ac"^-1, ")")),
    title = "Projected Carbon Stock by Scenario"
  )
  ggsave(file.path(output_dir, paste0("fig_carbon_trajectory.", fmt)),
         p_c, width = 20, height = 12, units = "cm", dpi = dpi, bg = "white")

  # G/R ratio
  p_gr <- plot_gr_ratios(mc_results)
  ggsave(file.path(output_dir, paste0("fig_gr_ratio.", fmt)),
         p_gr, width = 20, height = 12, units = "cm", dpi = dpi, bg = "white")

  # Harvest and planting
  p_hp <- plot_harvest_planting(mc_results)
  ggsave(file.path(output_dir, paste0("fig_harvest_planting.", fmt)),
         p_hp, width = 24, height = 12, units = "cm", dpi = dpi, bg = "white")

  # Save raw results
  cat("  Saving raw results...\n")
  write_csv(mc_results$all_summaries,
            file.path(output_dir, "raw_mc_summaries.csv"))
  write_csv(mc_results$ci_summaries,
            file.path(output_dir, "ci_summaries.csv"))

  cat(sprintf("=== Report saved to %s ===\n", output_dir))
}
