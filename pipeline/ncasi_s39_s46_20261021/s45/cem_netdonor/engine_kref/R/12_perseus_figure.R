# =============================================================================
# Title: PERSEUS-anchored comparison figure for Maine AG biomass projections
# Author: A. Weiskittel
# Date: 2026-04-17
# Description: Produces a figure matching the PERSEUS layout: MMT AGB on
#              y-axis, 2003-2040 on x-axis. 1999 baseline scenarios are
#              anchored to the PERSEUS untreated 2003 value (249 MMT
#              biomass). Observed FIA untreated + all-plot trajectories
#              and published PERSEUS model curves (LANDIS-II, OSM, FVS)
#              are overlaid for validation. Includes a second panel
#              showing delta-from-BAU so the subtle scenario differences
#              are visible despite converging absolute trajectories.
# Dependencies: tidyverse, ggplot2, ggtext, patchwork, scales
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse); library(ggplot2); library(ggtext); library(patchwork); library(scales)
})

STATE_V5_DIR <- "~/fia_cem_projections/output/state_mmt_v5"
PERSEUS_DIR  <- "~/fia_cem_projections/config/perseus"
OUT_DIR      <- "~/fia_cem_projections/output/figures"
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# --- Constants ---------------------------------------------------------------
# PERSEUS anchor for 1999-baseline trajectories: untreated 2003 value
PERSEUS_UNTREATED_2003_BIO <- 248.9116   # MMT AG biomass
# Approximate AGC from biomass using C = 0.5 * biomass
BIO_TO_AGC <- 0.5

# --- Theme -------------------------------------------------------------------
theme_pub <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey92", linewidth = 0.25),
    axis.title = element_text(size = 11),
    axis.text  = element_text(size = 9),
    legend.position = "bottom",
    legend.title = element_text(size = 9, face = "bold"),
    legend.text  = element_text(size = 8),
    plot.title = element_text(size = 12, face = "bold"),
    plot.margin = margin(8, 8, 8, 8)
  )

scenario_colors <- c(
  "No_harvest"          = "#1B7C3D",
  "Harvest_m25_mill"    = "#3498DB",
  "BAU"                 = "#2C3E50",
  "Harvest_p25_pulp"    = "#F39C12",
  "Harvest_p50_biomass" = "#8E44AD",
  "CC_proxy"            = "#E74C3C"
)
scenario_labels <- c(
  "No_harvest"          = "No harvest (Q = 0)",
  "Harvest_m25_mill"    = "Mill closure (-25% Q)",
  "BAU"                 = "BAU (Q = 1)",
  "Harvest_p25_pulp"    = "Pulp recovery (+25% Q)",
  "Harvest_p50_biomass" = "Biomass surge (+50% Q)",
  "CC_proxy"            = "Climate change proxy"
)
scenario_order <- c("No_harvest","Harvest_m25_mill","BAU",
                    "Harvest_p25_pulp","Harvest_p50_biomass")

# Distinct color palette for PERSEUS comparison models
perseus_model_colors <- c(
  "FIA observed (untreated)" = "black",
  "LANDIS-II v2"             = "#6A3D9A",
  "OSM"                      = "#33A02C",
  "FIA-JMF"                  = "#E31A1C",
  "Zhao HCM"                 = "#B15928"
)

# --- Load data ---------------------------------------------------------------
load_projections <- function() {
  # Load v5 1999 baseline and current-era CI tables
  hv_1999 <- read_csv(file.path(STATE_V5_DIR, "harvest_1999_v5_ci.csv"),
                      show_col_types = FALSE) |>
    mutate(run = "harvest_1999_v5")
  hv_cur  <- read_csv(file.path(STATE_V5_DIR, "harvest_v5_ci.csv"),
                      show_col_types = FALSE) |>
    mutate(run = "harvest_v5")
  bind_rows(hv_1999, hv_cur)
}

load_perseus <- function() {
  pu <- read_csv(file.path(PERSEUS_DIR, "perseus_untreated.csv"),
                 show_col_types = FALSE) |>
    filter(!is.na(`2003`)) |>
    pivot_longer(c(`2003`,`2008`,`2013`,`2018`),
                 names_to = "year", values_to = "mmt_biomass") |>
    mutate(year = as.integer(year),
           model = str_trim(model))
  pu
}

# --- Rescale projections to PERSEUS anchor -----------------------------------
#' Anchor 1999-baseline projections to PERSEUS untreated 2003 value.
#' Converts our proj_carbon (MMT AGC) to proj_biomass (MMT AGB) via 2x factor,
#' then rescales each scenario-run so cycle-1 == PERSEUS 2003 baseline.
anchor_1999_to_perseus <- function(ci_all) {
  d99 <- ci_all |> filter(run == "harvest_1999_v5")

  # Add biomass columns if missing (biomass = 2 * AGC approximately)
  if (!"mmt_biomass_mean" %in% names(d99)) {
    d99 <- d99 |>
      mutate(mmt_biomass_mean = mmt_agc_mean / BIO_TO_AGC,
             mmt_biomass_lo   = mmt_agc_lo   / BIO_TO_AGC,
             mmt_biomass_hi   = mmt_agc_hi   / BIO_TO_AGC)
  }

  anchor <- PERSEUS_UNTREATED_2003_BIO
  d99 <- d99 |>
    group_by(scenario, run) |>
    arrange(cycle) |>
    mutate(scale = anchor / first(mmt_biomass_mean),
           across(c(mmt_biomass_mean, mmt_biomass_lo, mmt_biomass_hi),
                  ~ . * scale),
           # Also rescale AGC with same ratio
           across(c(mmt_agc_mean, mmt_agc_lo, mmt_agc_hi),
                  ~ . * scale)) |>
    ungroup() |>
    select(-scale)

  # Shift calendar year so cycle 1 = 2003 (our pipeline had it at 2004)
  d99 <- d99 |> mutate(year = year - 1L)

  # Prepend a 2003 anchor row per scenario
  anchor_rows <- d99 |> distinct(scenario, run) |>
    mutate(cycle = 0L, year = 2003L,
           mmt_biomass_mean = anchor,
           mmt_biomass_lo   = anchor,
           mmt_biomass_hi   = anchor,
           mmt_agc_mean     = anchor * BIO_TO_AGC,
           mmt_agc_lo       = anchor * BIO_TO_AGC,
           mmt_agc_hi       = anchor * BIO_TO_AGC)
  for (col in setdiff(names(d99), names(anchor_rows))) anchor_rows[[col]] <- NA
  bind_rows(anchor_rows, d99) |> arrange(scenario, cycle)
}

# --- Panel A: absolute MMT biomass -------------------------------------------
panel_absolute_biomass <- function(d99_rescaled, perseus_df) {

  perseus_df <- perseus_df |>
    filter(model %in% c("FIA", "LANDIS-II v2", "OSM (n~= 1223)",
                        "FIA-JMF (n<1233)", "Zhao HCM")) |>
    mutate(model_label = case_when(
      model == "FIA"               ~ "FIA observed (untreated)",
      model == "LANDIS-II v2"      ~ "LANDIS-II v2",
      model == "OSM (n~= 1223)"    ~ "OSM",
      model == "FIA-JMF (n<1233)"  ~ "FIA-JMF",
      model == "Zhao HCM"          ~ "Zhao HCM",
      TRUE                          ~ model
    ))

  d99_rescaled <- d99_rescaled |>
    mutate(scenario = factor(scenario, levels = scenario_order))

  ggplot(d99_rescaled, aes(x = year, y = mmt_biomass_mean,
                            ymin = mmt_biomass_lo, ymax = mmt_biomass_hi,
                            color = scenario, fill = scenario,
                            group = scenario)) +
    geom_ribbon(alpha = 0.12, color = NA) +
    geom_line(linewidth = 0.6) +
    geom_point(size = 1.1) +
    # PERSEUS model curves
    geom_line(data = perseus_df,
              aes(x = year, y = mmt_biomass, color = model_label,
                  group = model_label),
              linewidth = 0.6, linetype = "32",
              inherit.aes = FALSE) +
    geom_point(data = perseus_df,
               aes(x = year, y = mmt_biomass, color = model_label),
               size = 1.5, shape = 15,
               inherit.aes = FALSE) +
    scale_color_manual(
      values = c(scenario_colors, perseus_model_colors),
      breaks = c(scenario_order, names(perseus_model_colors)),
      labels = c(unname(scenario_labels[scenario_order]),
                 names(perseus_model_colors)),
      name = "Source"
    ) +
    scale_fill_manual(
      values = scenario_colors[scenario_order],
      breaks = scenario_order,
      labels = unname(scenario_labels[scenario_order]),
      name = "Source",
      guide = "none"
    ) +
    scale_x_continuous(breaks = seq(2000, 2040, by = 5)) +
    labs(x = NULL, y = "Aboveground biomass (MMT)",
         title = "A) 1999 baseline projections anchored to PERSEUS 2003",
         subtitle = "Dashed = published models (untreated n = 1,233 plots); Solid = this study's CEM projections") +
    theme_pub +
    theme(legend.position = "right",
          legend.box = "vertical",
          legend.key.width = unit(1.2, "cm")) +
    guides(color = guide_legend(ncol = 1, order = 1,
                                override.aes = list(
                                  shape    = c(rep(16, 5), rep(15, 5)),
                                  linetype = c(rep("solid", 5), rep("32", 5))
                                )),
           fill  = "none")
}

# --- Panel B: scenario delta from BAU ----------------------------------------
panel_delta_from_bau <- function(d99_rescaled) {
  bau <- d99_rescaled |>
    filter(scenario == "BAU") |>
    select(year, cycle, bau_mean = mmt_biomass_mean)

  delta <- d99_rescaled |>
    left_join(bau, by = c("year","cycle")) |>
    mutate(delta_mean = mmt_biomass_mean - bau_mean,
           delta_lo   = mmt_biomass_lo   - bau_mean,
           delta_hi   = mmt_biomass_hi   - bau_mean,
           scenario   = factor(scenario, levels = scenario_order))

  ggplot(delta, aes(x = year, y = delta_mean,
                     ymin = delta_lo, ymax = delta_hi,
                     color = scenario, fill = scenario,
                     group = scenario)) +
    geom_hline(yintercept = 0, color = "grey40", linewidth = 0.3) +
    geom_ribbon(alpha = 0.15, color = NA) +
    geom_line(linewidth = 0.6) +
    geom_point(size = 1.0) +
    scale_color_manual(values = scenario_colors[scenario_order],
                       labels = unname(scenario_labels[scenario_order]),
                       breaks = scenario_order,
                       name = "Scenario") +
    scale_fill_manual(values = scenario_colors[scenario_order],
                      labels = unname(scenario_labels[scenario_order]),
                      breaks = scenario_order,
                      name = "Scenario") +
    scale_x_continuous(breaks = seq(2000, 2040, by = 5)) +
    labs(x = NULL, y = "Delta MMT biomass vs BAU",
         title = "B) Scenario delta from BAU (this study only)",
         subtitle = "Makes scenario convergence visible when absolute curves overlap") +
    theme_pub
}

# --- Compose and save --------------------------------------------------------
build_perseus_figure <- function(out_prefix = file.path(OUT_DIR, "fig_perseus_comparison")) {
  ci_all    <- load_projections()
  perseus   <- load_perseus()
  d99_rescaled <- anchor_1999_to_perseus(ci_all)

  # Save rescaled data for inspection
  write_csv(d99_rescaled, paste0(out_prefix, "_data.csv"))

  p_a <- panel_absolute_biomass(d99_rescaled, perseus)
  p_b <- panel_delta_from_bau(d99_rescaled)

  combined <- p_a / p_b +
    plot_layout(heights = c(1.6, 1)) +
    plot_annotation(
      title    = "Maine AGB: CEM projections vs PERSEUS models",
      caption  = paste(
        "1999-baseline CEM projections anchored to PERSEUS untreated 2003 value (248.9 MMT AGB).",
        "Biomass ~ 2 x AGC. Scenario comparison uses the CEM harvest_Q biasing (no economic model).",
        "PERSEUS curves from 1,233 untreated plots (TRTCD1 == 0 in 1999-2018).",
        sep = "\n")
    )

  ggsave(paste0(out_prefix, ".png"), combined,
         width = 26, height = 22, units = "cm", dpi = 300, bg = "white")
  ggsave(paste0(out_prefix, ".pdf"), combined,
         width = 26, height = 22, units = "cm")
  cat(sprintf("Wrote %s.{png,pdf}\n", out_prefix))
  invisible(combined)
}

# CLI entry guarded so the pipeline doesn't auto-run it
if (!interactive() && identical(Sys.getenv("RUN_PERSEUS_FIG"), "TRUE")) {
  build_perseus_figure()
}
