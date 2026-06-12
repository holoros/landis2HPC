# benchmark_nash_domke_harvest.R
# Compare our harmonized BAU common harvest removals for the Northern Lake States
# (MI, MN, WI) against Nash and Domke 2026 (Carbon Balance and Management,
# doi 10.1186/s13021-026-00464-y) 2024 FIA based harvest estimates.
#
# Our removal: rem = h * f * B
#   h = HCS area harvest rate  (hcs_harvest_rate_by_state.csv, harvest_rate_pct_yr/100)
#   f = BAU removal fraction   = clearcut_frac*F_CLEARCUT + (1-clearcut_frac)*F_PARTIAL
#   B = FIA 2025 anchor live AGC (fia_agc_anchor_design_by_state.csv, agc_TgC_design)
# Constants taken from apply_harvest_scenarios.R: F_CLEARCUT=0.85, F_PARTIAL=0.45, BAU mult=1.

library(tidyverse)

F_CLEARCUT <- 0.85
F_PARTIAL  <- 0.45

ours <- tibble(
  state = c("MI", "MN", "WI"),
  h     = c(1.775, 0.335, 3.257) / 100,   # HCS harvest_rate_pct_yr -> fraction/yr
  cc    = c(0.549, 0.540, 0.545),         # clearcut_frac
  B     = c(512.45, 308.78, 396.22)       # FIA 2025 anchor live AGC, Tg C
) |>
  mutate(
    f        = cc * F_CLEARCUT + (1 - cc) * F_PARTIAL,
    removal  = h * f * B,                  # Tg C/yr live AGC removed, BAU 2025
    pct_AGC  = removal / B * 100,
    nash2024 = c(MI = 3.0, MN = 2.0, WI = 3.4)[state],   # MMT C merch bole
    ratio    = removal / nash2024
  )

print(ours)

cat(sprintf("\nNLS total: ours BAU %.1f Tg C/yr vs Nash 2024 %.1f MMT C/yr (ratio %.2f)\n",
            sum(ours$removal), sum(ours$nash2024), sum(ours$removal) / sum(ours$nash2024)))
cat(sprintf("Merch bole equivalent (x0.6): %.1f Tg C/yr (ratio %.2f)\n",
            sum(ours$removal) * 0.6, sum(ours$removal) * 0.6 / sum(ours$nash2024)))
