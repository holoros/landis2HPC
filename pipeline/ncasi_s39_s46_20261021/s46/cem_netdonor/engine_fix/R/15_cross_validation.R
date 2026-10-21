# =============================================================================
# Title: Cross-validation of 1999-baseline projections against FIA observed
# Author: A. Weiskittel
# Date: 2026-04-17
# Description: Addresses recommendation #5. Compares projected MMT AGC at
#   2003, 2008, 2013, 2018, 2024 to observed FIA totals at the same years.
#   Produces a table and a figure overlaying both trajectories.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse); library(ggplot2); library(ggtext); library(patchwork)
})

ROUNDS_DIR   <- "~/fia_cem_projections/output/state_mmt_rounds"
STATE_V5_DIR <- "~/fia_cem_projections/output/state_mmt_v5"
OUT_DIR      <- "~/fia_cem_projections/output/figures"

# --- Load runs ---------------------------------------------------------------
load_run <- function(prefix, label) {
  read_csv(file.path(ROUNDS_DIR, paste0(prefix, "_ci.csv")),
           show_col_types = FALSE) |>
    mutate(run = label)
}

runs <- bind_rows(
  load_run("round1b_untreated_both_nh",      "1999 baseline: untreated, no harvest"),
  load_run("round2b_all_untreated_donors",   "1999 baseline: all plots, 10%x50% harvest"),
  tryCatch(load_run("rcp45_hadgem2",         "HadGEM2-AO RCP 4.5 (harvest)"),
           error = function(e) NULL),
  tryCatch(load_run("rcp85_hadgem2",         "HadGEM2-AO RCP 8.5 (harvest)"),
           error = function(e) NULL)
)

# --- Observed FIA ------------------------------------------------------------
obs <- read_csv(file.path(STATE_V5_DIR, "observed_state_totals_multi.csv"),
                show_col_types = FALSE) |>
  group_by(year) |> slice(1) |> ungroup() |>
  select(year,
         mmt_agc_obs    = mmt_agc_mean,
         mmt_biomass_obs = mmt_biomass_mean)

# Year targets for the validation table
val_years <- c(2003, 2008, 2013, 2018, 2024)

# --- Validation table --------------------------------------------------------
# Match projected year to nearest validation year (within 2 years)
match_year <- function(proj_year) {
  diffs <- abs(proj_year - val_years)
  i <- which.min(diffs)
  if (diffs[i] <= 2) val_years[i] else NA_integer_
}

validation <- runs |>
  rowwise() |>
  mutate(val_year = match_year(year)) |>
  ungroup() |>
  filter(!is.na(val_year)) |>
  group_by(run, val_year) |>
  slice_min(abs(year - val_year), n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(run, val_year, year,
         proj_agc = mmt_agc_mean, agc_lo = mmt_agc_lo, agc_hi = mmt_agc_hi) |>
  left_join(obs |> rename(val_year = year), by = "val_year") |>
  mutate(
    diff_abs    = proj_agc - mmt_agc_obs,
    diff_pct    = 100 * diff_abs / mmt_agc_obs,
    within_obs  = proj_agc >= agc_lo & proj_agc <= agc_hi
  ) |>
  arrange(run, val_year)

cat("\n=== Cross-validation: projected vs observed FIA ===\n")
print(validation |>
  transmute(run, year = val_year,
            obs = round(mmt_agc_obs, 1),
            proj = round(proj_agc, 1),
            `diff (MMT)` = round(diff_abs, 1),
            `diff (%)` = round(diff_pct, 1)) |>
  pivot_wider(names_from = year, values_from = c(obs, proj, `diff (MMT)`, `diff (%)`)),
  n = Inf)

write_csv(validation, file.path(ROUNDS_DIR, "cross_validation.csv"))
cat("\nWrote cross_validation.csv\n")

# --- Cross-validation figure -------------------------------------------------
theme_pub <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey92", linewidth = 0.25),
    legend.position = "right",
    legend.title    = element_text(size = 9, face = "bold"),
    legend.text     = element_text(size = 8),
    plot.title      = element_text(size = 12, face = "bold"),
    plot.subtitle   = element_text(size = 9, color = "grey30")
  )

run_cols <- c(
  "1999 baseline: untreated, no harvest"       = "#1B7C3D",
  "1999 baseline: all plots, 10%x50% harvest"  = "#6E1B83",
  "HadGEM2-AO RCP 4.5 (harvest)"               = "#3B82C4",
  "HadGEM2-AO RCP 8.5 (harvest)"               = "#E74C3C"
)

p_cv <- ggplot(runs, aes(x = year, y = mmt_agc_mean,
                          ymin = mmt_agc_lo, ymax = mmt_agc_hi,
                          fill = run, color = run, group = run)) +
  geom_ribbon(alpha = 0.12, color = NA) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.0) +
  # Observed FIA trajectory
  geom_line(data = obs,
            aes(x = year, y = mmt_agc_obs),
            color = "black", linewidth = 0.5, linetype = "12",
            inherit.aes = FALSE) +
  geom_point(data = obs |> filter(year %in% val_years),
             aes(x = year, y = mmt_agc_obs),
             color = "black", size = 2.3, shape = 18,
             inherit.aes = FALSE) +
  scale_color_manual(values = run_cols, name = "Projection") +
  scale_fill_manual(values = run_cols, name = "Projection", guide = "none") +
  scale_x_continuous(breaks = seq(2000, 2100, by = 10),
                     limits = c(2000, 2100)) +
  labs(x = NULL, y = "Aboveground C (MMT)",
       title = "Cross-validation: projected vs observed FIA (2003-2024)",
       subtitle = "Black diamonds = FIA observed at 2003/08/13/18/24; ribbons = 95% Monte Carlo CI") +
  theme_pub

ggsave(file.path(OUT_DIR, "fig_cross_validation.png"), p_cv,
       width = 22, height = 14, units = "cm", dpi = 300, bg = "white")
ggsave(file.path(OUT_DIR, "fig_cross_validation.pdf"), p_cv,
       width = 22, height = 14, units = "cm")
cat("Wrote fig_cross_validation.{png,pdf}\n")
