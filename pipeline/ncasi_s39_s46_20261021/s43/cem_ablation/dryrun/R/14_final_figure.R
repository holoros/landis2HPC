# =============================================================================
# Title: Final two-round comparison figure (v6) with all recommendations applied
# Author: A. Weiskittel
# Date: 2026-04-17
# Description: Rounds 1b (untreated subjects + untreated donors, no harvest)
#              and 2b (all subjects, untreated donors, 10% area x 50% biomass
#              harvest) projected 1999-2099 on 5-yr cycles, overlaid with
#              observed FIA and PERSEUS published models.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse); library(ggplot2); library(ggtext); library(patchwork); library(scales)
})

ROUNDS_DIR   <- "~/fia_cem_projections/output/state_mmt_rounds"
PERSEUS_DIR  <- "~/fia_cem_projections/config/perseus"
STATE_V5_DIR <- "~/fia_cem_projections/output/state_mmt_v5"
OUT_DIR      <- "~/fia_cem_projections/output/figures"
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

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

# --- Load all four rounds ----------------------------------------------------
load_round <- function(prefix, label) {
  read_csv(file.path(ROUNDS_DIR, paste0(prefix, "_ci.csv")),
           show_col_types = FALSE) |>
    mutate(round = label)
}

cem <- bind_rows(
  load_round("round1_untreated_nh",              "R1: untreated subjects | all donors | no harvest"),
  load_round("round1b_untreated_both_nh",        "R1b: untreated subjects | untreated donors | no harvest"),
  load_round("round2_all_10pct_50int",           "R2: all subjects | all donors | 10%x50% harvest"),
  load_round("round2b_all_untreated_donors",     "R2b: all subjects | untreated donors | 10%x50% harvest")
)

if (!"mmt_biomass_mean" %in% names(cem)) {
  cem <- cem |> mutate(
    mmt_biomass_mean = mmt_agc_mean / 0.5,
    mmt_biomass_lo   = mmt_agc_lo / 0.5,
    mmt_biomass_hi   = mmt_agc_hi / 0.5
  )
}

perseus <- read_csv(file.path(PERSEUS_DIR, "perseus_untreated.csv"),
                    show_col_types = FALSE) |>
  filter(!is.na(`2003`)) |>
  pivot_longer(c(`2003`,`2008`,`2013`,`2018`),
               names_to = "year", values_to = "mmt_biomass") |>
  mutate(year = as.integer(year), model = str_trim(model)) |>
  filter(model %in% c("FIA","LANDIS-II v2","OSM (n~= 1223)",
                      "FIA-JMF (n<1233)","Zhao HCM")) |>
  mutate(label = case_when(
    model == "FIA"              ~ "FIA observed (untreated)",
    model == "LANDIS-II v2"     ~ "LANDIS-II v2",
    model == "OSM (n~= 1223)"   ~ "OSM",
    model == "FIA-JMF (n<1233)" ~ "FIA-JMF",
    model == "Zhao HCM"         ~ "Zhao HCM"
  ))

obs <- read_csv(file.path(STATE_V5_DIR, "observed_state_totals_multi.csv"),
                show_col_types = FALSE) |>
  group_by(year) |> slice(1) |> ungroup() |>
  select(year, mmt_agc_obs = mmt_agc_mean, mmt_biomass_obs = mmt_biomass_mean)

# --- Colors ------------------------------------------------------------------
round_cols <- c(
  "R1: untreated subjects | all donors | no harvest"         = "#AEDD84",
  "R1b: untreated subjects | untreated donors | no harvest"  = "#1B7C3D",
  "R2: all subjects | all donors | 10%x50% harvest"          = "#D9B3E4",
  "R2b: all subjects | untreated donors | 10%x50% harvest"   = "#6E1B83"
)

perseus_cols <- c(
  "FIA observed (untreated)" = "black",
  "LANDIS-II v2"             = "#4C3D7A",
  "OSM"                      = "#2E7D32",
  "FIA-JMF"                  = "#C62828",
  "Zhao HCM"                 = "#8D5524"
)

# --- Panel A: AGC trajectories ----------------------------------------------
p_agc <- ggplot(cem, aes(x = year, y = mmt_agc_mean,
                          ymin = mmt_agc_lo, ymax = mmt_agc_hi,
                          fill = round, color = round, group = round)) +
  geom_ribbon(alpha = 0.12, color = NA) +
  geom_line(linewidth = 0.6) +
  geom_point(size = 1.0) +
  scale_color_manual(values = round_cols, name = "CEM projection",
                     aesthetics = c("color","fill")) +
  scale_x_continuous(breaks = seq(2000, 2100, by = 10),
                     limits = c(2000, 2100)) +
  labs(x = NULL, y = "Aboveground C (MMT)",
       title = "A) Aboveground carbon - all four rounds",
       subtitle = "1999 to 2099 at 5-yr cycles; ribbons = 95% Monte Carlo CI") +
  theme_pub

# --- Panel B: biomass with PERSEUS ------------------------------------------
p_biomass <- ggplot(cem, aes(x = year, y = mmt_biomass_mean,
                              ymin = mmt_biomass_lo, ymax = mmt_biomass_hi,
                              fill = round, color = round, group = round)) +
  geom_ribbon(alpha = 0.12, color = NA) +
  geom_line(linewidth = 0.6) +
  geom_point(size = 1.0) +
  geom_line(data = perseus,
            aes(x = year, y = mmt_biomass, color = label, group = label),
            linetype = "32", linewidth = 0.5, inherit.aes = FALSE) +
  geom_point(data = perseus,
             aes(x = year, y = mmt_biomass, color = label),
             size = 1.5, shape = 15, inherit.aes = FALSE) +
  geom_line(data = obs,
            aes(x = year, y = mmt_biomass_obs),
            color = "grey35", linewidth = 0.4, linetype = "12",
            inherit.aes = FALSE) +
  geom_point(data = obs |> filter(year %in% c(2003,2008,2013,2018,2024)),
             aes(x = year, y = mmt_biomass_obs),
             color = "grey35", size = 1.2, shape = 17,
             inherit.aes = FALSE) +
  scale_color_manual(values = c(round_cols, perseus_cols),
                     name = "Source",
                     breaks = c(names(round_cols), names(perseus_cols))) +
  scale_fill_manual(values = round_cols, guide = "none") +
  scale_x_continuous(breaks = seq(2000, 2100, by = 10),
                     limits = c(2000, 2100)) +
  labs(x = NULL, y = "Aboveground biomass (MMT)",
       title = "B) Biomass with PERSEUS + FIA observed reference",
       subtitle = "Solid = CEM; dashed = PERSEUS models (untreated); grey triangles = FIA all-plots observed") +
  theme_pub +
  theme(legend.key.width = unit(1.2, "cm"))

combined <- p_agc / p_biomass +
  plot_layout(heights = c(1, 1)) +
  plot_annotation(
    title    = "Maine forest projections 1999-2099: harvest scenario completed",
    subtitle = "Donor-pool filter (--untreated_donors) applied to R1b and R2b gives clean growth signal",
    caption  = paste(
      "R2b is the completed harvest scenario: all FIA plots, 2%/yr area (10% per 5-yr cycle) x 50% biomass removal.",
      "R2b uses growth rates from untreated donors + explicit harvest reduction, matching PERSEUS's decomposition approach.",
      "Biomass ~ 2 x AGC. SDImax from Woodall & Weiskittel (2021). EXPNS from FIA POP_STRATUM.",
      sep = "\n")
  )

ggsave(file.path(OUT_DIR, "fig_harvest_scenario_complete.png"), combined,
       width = 30, height = 22, units = "cm", dpi = 300, bg = "white")
ggsave(file.path(OUT_DIR, "fig_harvest_scenario_complete.pdf"), combined,
       width = 30, height = 22, units = "cm")
cat("Wrote fig_harvest_scenario_complete.{png,pdf}\n")
