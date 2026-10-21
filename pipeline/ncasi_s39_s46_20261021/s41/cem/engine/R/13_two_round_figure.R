# =============================================================================
# Title: Two-round comparison figure (untreated no-harvest vs all-plots harvest)
# Author: A. Weiskittel
# Date: 2026-04-17
# Description: Final comparison figure per user spec:
#   Round 1: ~1,233 untreated FIA plots, no harvest, 1999-2099
#   Round 2: all FIA plots, 2%/yr * 50% biomass harvest, 1999-2099
#   Overlaid with PERSEUS published models (untreated sheet) and FIA observed.
# Dependencies: tidyverse, ggplot2, ggtext, patchwork
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse); library(ggplot2); library(ggtext); library(patchwork); library(scales)
})

ROUNDS_DIR   <- "~/fia_cem_projections/output/state_mmt_rounds"
PERSEUS_DIR  <- "~/fia_cem_projections/config/perseus"
STATE_V5_DIR <- "~/fia_cem_projections/output/state_mmt_v5"
OUT_DIR      <- "~/fia_cem_projections/output/figures"
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# --- Theme -------------------------------------------------------------------
theme_pub <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey92", linewidth = 0.25),
    axis.title   = element_text(size = 11),
    axis.text    = element_text(size = 9),
    legend.position = "right",
    legend.title = element_text(size = 9, face = "bold"),
    legend.text  = element_text(size = 8),
    legend.key.width = unit(1.0, "cm"),
    plot.title   = element_text(size = 12, face = "bold"),
    plot.subtitle = element_text(size = 9, color = "grey30"),
    plot.caption = element_text(size = 8, color = "grey40"),
    plot.margin  = margin(8, 8, 8, 8)
  )

# --- Load CEM projection rounds ---------------------------------------------
r1 <- read_csv(file.path(ROUNDS_DIR, "round1_untreated_nh_ci.csv"),
               show_col_types = FALSE) |>
  mutate(round = "Round 1: untreated, no harvest")
r2 <- read_csv(file.path(ROUNDS_DIR, "round2_all_10pct_50int_ci.csv"),
               show_col_types = FALSE) |>
  mutate(round = "Round 2: all plots, 10% area x 50% biomass")
cem <- bind_rows(r1, r2)

# Re-anchor biomass if missing: approximate biomass = 2 * AGC
if (!"mmt_biomass_mean" %in% names(cem)) {
  cem <- cem |> mutate(
    mmt_biomass_mean = mmt_agc_mean / 0.5,
    mmt_biomass_lo   = mmt_agc_lo / 0.5,
    mmt_biomass_hi   = mmt_agc_hi / 0.5
  )
}

# --- PERSEUS untreated reference --------------------------------------------
perseus <- read_csv(file.path(PERSEUS_DIR, "perseus_untreated.csv"),
                    show_col_types = FALSE) |>
  filter(!is.na(`2003`)) |>
  pivot_longer(c(`2003`,`2008`,`2013`,`2018`),
               names_to = "year", values_to = "mmt_biomass") |>
  mutate(year = as.integer(year), model = str_trim(model))

# --- Observed FIA trajectory (all plots, every EXPALL EVALID) ---------------
obs <- read_csv(file.path(STATE_V5_DIR, "observed_state_totals_multi.csv"),
                show_col_types = FALSE) |>
  group_by(year) |> slice(1) |> ungroup() |>
  select(year, mmt_agc_obs = mmt_agc_mean, mmt_biomass_obs = mmt_biomass_mean)

# --- Figure ------------------------------------------------------------------
round_cols <- c(
  "Round 1: untreated, no harvest"              = "#1B7C3D",
  "Round 2: all plots, 10% area x 50% biomass"  = "#8E44AD"
)

perseus_cols <- c(
  "FIA observed (untreated)" = "black",
  "LANDIS-II v2"             = "#6A3D9A",
  "OSM"                      = "#33A02C",
  "FIA-JMF"                  = "#E31A1C",
  "Zhao HCM"                 = "#B15928"
)

perseus_plot <- perseus |>
  filter(model %in% c("FIA","LANDIS-II v2","OSM (n~= 1223)",
                      "FIA-JMF (n<1233)","Zhao HCM")) |>
  mutate(label = case_when(
    model == "FIA"              ~ "FIA observed (untreated)",
    model == "LANDIS-II v2"     ~ "LANDIS-II v2",
    model == "OSM (n~= 1223)"   ~ "OSM",
    model == "FIA-JMF (n<1233)" ~ "FIA-JMF",
    model == "Zhao HCM"         ~ "Zhao HCM"
  ))

p_agc <- ggplot(cem, aes(x = year, y = mmt_agc_mean,
                          ymin = mmt_agc_lo, ymax = mmt_agc_hi,
                          fill = round, color = round, group = round)) +
  geom_ribbon(alpha = 0.15, color = NA) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.2) +
  scale_color_manual(values = round_cols, name = "CEM projection",
                     aesthetics = c("color","fill")) +
  scale_x_continuous(breaks = seq(2000, 2100, by = 10),
                     limits = c(2000, 2100)) +
  labs(x = NULL, y = "Aboveground C (MMT)",
       title = "A) Aboveground carbon",
       subtitle = "CEM projections 1999 to 2099 at 5-yr cycles; ribbons = 95% Monte Carlo CI") +
  theme_pub

p_biomass <- ggplot(cem, aes(x = year, y = mmt_biomass_mean,
                              ymin = mmt_biomass_lo, ymax = mmt_biomass_hi,
                              fill = round, color = round, group = round)) +
  geom_ribbon(alpha = 0.15, color = NA) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.2) +
  # PERSEUS reference curves
  geom_line(data = perseus_plot,
            aes(x = year, y = mmt_biomass, color = label, group = label),
            linetype = "32", linewidth = 0.5, inherit.aes = FALSE) +
  geom_point(data = perseus_plot,
             aes(x = year, y = mmt_biomass, color = label),
             size = 1.5, shape = 15, inherit.aes = FALSE) +
  # Observed FIA all-plots trajectory (as a secondary reference)
  geom_line(data = obs,
            aes(x = year, y = mmt_biomass_obs),
            color = "grey30", linewidth = 0.4, linetype = "12",
            inherit.aes = FALSE) +
  geom_point(data = obs |> filter(year %in% c(2003,2008,2013,2018,2024)),
             aes(x = year, y = mmt_biomass_obs),
             color = "grey30", size = 1.2, shape = 17,
             inherit.aes = FALSE) +
  scale_color_manual(values = c(round_cols, perseus_cols),
                     name = "Source",
                     breaks = c(names(round_cols), names(perseus_cols))) +
  scale_fill_manual(values = round_cols, guide = "none") +
  scale_x_continuous(breaks = seq(2000, 2100, by = 10),
                     limits = c(2000, 2100)) +
  labs(x = NULL, y = "Aboveground biomass (MMT)",
       title = "B) Aboveground biomass with PERSEUS comparison",
       subtitle = "Solid = CEM projections; dashed = PERSEUS published models; dotted grey = FIA all-plots observed") +
  theme_pub +
  theme(legend.key.width = unit(1.2, "cm"))

combined <- p_agc / p_biomass +
  plot_layout(heights = c(1, 1)) +
  plot_annotation(
    title    = "Maine forest projections: 1999 baseline to 2099 at 5-yr cycles",
    subtitle = "Round 1: ~1,233 untreated plots with no harvest. Round 2: all plots with 2%/yr area x 50% biomass removal.",
    caption  = paste(
      "CEM projections use growth-rate-based forecasting (donor T2/T1 ratio applied to subject level).",
      "Round 2 harvest regime: 10% of area harvested per 5-yr cycle, each removing 50% of standing biomass.",
      "PERSEUS reference curves from the untreated-plots sheet (1,233 plots, TRTCD1 == 0 in 1999-2018).",
      sep = "\n")
  )

ggsave(file.path(OUT_DIR, "fig_two_round_comparison.png"), combined,
       width = 28, height = 22, units = "cm", dpi = 300, bg = "white")
ggsave(file.path(OUT_DIR, "fig_two_round_comparison.pdf"), combined,
       width = 28, height = 22, units = "cm")
cat("Wrote fig_two_round_comparison.{png,pdf}\n")
