# Harmonized session handoff — 2026-06-08

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-07L and multicriteria_metrics_framework.md
**Focus:** carbon-versus-timber-NPV tradeoff across the four scenarios; NPV/stumpage resolved.

---

## 1. Carbon (forest + HWP) and timber NPV, paired (4 states x 4 scenarios)

`harmonized/harmonized_carbon_npv_4state.csv`. Total carbon = standing forest AGC + harvested wood products (HWP), with timber NPV (dollars/ha) on a separate axis. NPV and HWP are both valued from each scenario's own harvest removals (internally consistent with the carbon scenarios). HWP is a first-order pool: of removed carbon, HWP_FRAC 0.5 enters products, split long-lived (half-life 35 yr) and short-lived (4 yr), with a landfill pool (100 yr); storage only, no material-substitution credit (conservative).

2100 carbon, reserve vs intensive (Tg C), and intensive NPV/ha at 5%:

| State | reserve total | intensive forest | intensive HWP | intensive total | intensive NPV/ha |
|---|---|---|---|---|---|
| MN | 704 | 508 | +43 | 551 | 202 |
| IN | 706 | 627 | +18 | 645 | 250 |
| OH | 967 | 881 | +20 | 901 | 161 |
| WA | 1670 | 1653 | +4 | 1657 | 13 |

HWP recovers roughly 20 to 25% of the harvest-driven forest-carbon loss by 2100 (MN: 196 Tg forest loss, 43 Tg HWP gain). Reserve still stores the most total carbon in every state, but counting HWP materially narrows the carbon penalty of harvest. Ordering is coherent (forest carbon falls, HWP and NPV rise, reserve to intensive); magnitude scales with each state's HCS harvest rate. This is the carbon-economics tradeoff frontier.

## 2. NPV/stumpage resolved

The economic methodology existed (`ecoregion_npv_by_rate.csv`, four discount rates, built by `cbm_conus/10_economics/02_npv.R`). Two resolutions this session: (a) that file's npv_rev/npv_net columns fold in a carbon valuation, so I report timber and carbon separately; and (b) it carries timber revenue ONLY for the BAU/managed-harvest scenario (conservation and intensive came back as $0 timber), so I do NOT use it for the cross-scenario tradeoff. Instead timber is valued from the scenario removals directly, which gives consistent NPV for all four scenarios.

Stumpage remains a generic placeholder ($14/m3 2020 USD, with merchantable fraction 0.6 and 1.9 m3/Mg). Real 2024-25 benchmarks (southern pine saw ~22-25, hardwood ~16-35, PNW Douglas-fir ~42-55 $/ton) say the next refinement is regional stumpage; for WA this would raise NPV per harvested unit, though WA's near-zero harvest rate keeps its scenario NPV small regardless. The relative tradeoff pattern is robust to the stumpage level; absolute dollars are provisional.

## 3. Ecosystem-service metrics (status)

Designed in `docs/multicriteria_metrics_framework.md`. An LSOG biomass-threshold proxy is now computed across all scenarios: `harmonized/harmonized_lsog_proxy_4state.csv` (fraction of plots with live AGC above 75 Mg C/ha, propagated through scenarios by the same expected-value harvest flux). 2025 to 2100, reserve to intensive: OH 0.97/0.94/0.91/0.85, IN 0.90/0.85/0.82/0.75, MN 0.56/0.52/0.49/0.43, WA 0.91/0.90/0.90/0.90. Coherent (reserve highest, intensive lowest, scaling with harvest rate). This is a biomass surrogate for age; the rigorous age-based LSOG, plus biodiversity and habitat, still need the metrics-output LANDIS rerun (retain CohortStats, per-species Biomass, WildlifeHabitat), a configuration change.

So the multi-criteria vector now spans three axes for the four states: total carbon (forest + HWP), timber NPV, and LSOG proxy. Reserve maximizes carbon and LSOG at zero timber value; intensive maximizes NPV at the cost of carbon and LSOG.

## 4. Next steps (priority order)

1. Add the LSOG biomass-threshold proxy to the scenario table from existing biomass trajectories.
2. Refit stumpage to real regional series (TimberMart-South, state extension, WA/OR DNR) and regenerate NPV; keep the generic version as a labeled placeholder.
3. Commit the metrics-output LANDIS rerun to unlock age-based LSOG, dynamic biodiversity, and habitat suitability.
4. Re-harvest reserve + scenarios for all calibrated states once the statewide resumes finish; fix WI/MI zero-paint.
5. Bring FVS, CEM, CBM, yield curves onto the pipeline and apply the same scenario + NPV method for the cross-model comparison.

## 5. Files created or changed this session

Repo: `harmonized/apply_harvest_scenarios.R` (now also computes timber NPV), `harmonized/harmonized_carbon_npv_4state.csv`, `harmonized/state_carbon_npv.R` (ecoregion-NPV join utility, superseded by the removal-based NPV for cross-scenario use), `docs/multicriteria_metrics_framework.md`, `docs/SESSION_HANDOFF_2026-06-08.md`. Cardinal: same scripts and the carbon+NPV summary.
