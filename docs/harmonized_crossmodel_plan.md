# Harmonized cross-model CONUS simulation plan

**Date:** 2026-06-06
**Config reviewed:** `cbm_states/cross_state/libcbm/tools_conus/harmonized_scenarios.yml` (version 1)
**Goal:** an apples-to-apples, multi-model forest carbon assessment across the lower 48, where the model is the only thing that differs. Daigneault et al. 2024 framing.

## 1. What the harmonized protocol fixes

Every participating model (yield curves, CBM, CEM, FVS, LANDIS) consumes the same inputs and emits the same output, so divergence is attributable to model structure rather than to setup. The locked elements are:

Extent is CONUS lower 48. Horizon is 2025 to 2100 in 5 year steps. Carbon fraction is a single common 0.5 (CEM's internal 0.47 is reconciled on output). Climate is "current" as the headline with rcp45 as a sensitivity. Forest area per state comes from FIA EXPNS.

The anchor is the key methodological device. Every model starts at the latest FIA state level above-ground live tree carbon (year 0 = 2025) and is rescaled so that `model_anchored(t) = model(t) * (FIA_y0 / model_y0)`. This forces a common year-0 stock per state and isolates each model's dynamics. The published anchor is to be recomputed directly from FIA TREE plus COND with EXPNS (CARBON_AG times TPA times EXPNS).

Harvest is driven by one source for all models: the HCS spatially explicit harvest probability, summarized to a per-state rate (`hcs_harvest_rate_by_state.csv`), with a 10 year observation window validated against FIA TPO.

The scenario taxonomy is four management levels, all at current climate: reserve (harvest multiplier 0.0), BAU (1.0, equal to the HCS rate), conservation (0.6, partial harvest emphasis and longer rotations), and intensive (2.0, clearcut plus plant). Common outputs are per-ha live AGC (the headline), removal volume, and stand age distribution.

Acceptance requires that all models share year-0 AGC per state within a few percent after anchoring, use the identical scenario list, climate, horizon, carbon fraction and forest area, draw harvest from the single HCS source, and report per-ha live AGC.

## 2. The most important implication for LANDIS

LANDIS is listed in the config as covering ME only, with the note "Aaron to CONUS." Two adjustments are needed before LANDIS output can enter the harmonized comparison, and neither is the 12 cell factorial built so far.

First, the scenario set must be remapped. The current `scenario_factorial.sh` builds 3 climate by 4 harvest with flat literature harvest rates (none, 0.022, 0.035, PerseusBA50). The harmonized set is 4 management scenarios at one "current" climate, with the harvest rate taken from the per-state HCS table and scaled by the scenario multiplier. The crosswalk is reserve equals none, BAU equals 1x the HCS per-state rate, conservation equals 0.6x with clearcut converted to partial, and intensive equals 2x with clearcut emphasis. The flat 0.022 baseline rate should be retired in favor of the HCS per-state rate so LANDIS matches every other model.

Second, LANDIS output must be FIA anchored. Compute LANDIS year-0 per-state AGC, then rescale each trajectory by FIA_y0 over LANDIS_y0, and report per-ha live AGC on the 2025 to 2100 by 5 grid.

## 3. The per-plot versus statewide-raster decision (resolved for this purpose)

The harmonized output is state level per-ha live AGC anchored to FIA. That does not require a spatially contiguous statewide raster run. It is most reliably produced by the proven per-plot pipeline, the same one that calibrated the eight states and produced WA's 306 Mg/ha statewide carbon, aggregated to a state per-ha value with FIA expansion factors.

This matters because the statewide-raster path is currently blocked. The 2026-06-06 pilots proved the extension wiring but then segfaulted during landscape init: Biomass Succession v7 (Universal Cohorts) requires the `MapCode,SpeciesName,CohortAge,CohortBiomass` CSV, and no statewide-extent IC exists in that format. The only statewide IC is the legacy age-list `initial_communities.txt`, which has no biomass column and crashes the parser. The per-plot builders (`build_plot_ics_WA.py` and siblings) already emit correct Universal IC from FIA tree lists, so the per-plot route sidesteps the blocker entirely.

Recommendation: produce the harmonized LANDIS contribution from per-plot runs aggregated to state level. Treat the statewide-raster factorial as a later, separate enhancement for spatially explicit disturbance work, gated on building a statewide Universal IC (map every IC raster MapCode to cohorts with biomass).

## 4. Cross-cutting prerequisites (all models depend on these)

The single FIA year-0 anchor table is the foundation: agc_live_total per state for 2025 from TREE plus COND with EXPNS. It is referenced as the operational anchor and still needs to be recomputed directly for the published version.

The HCS per-state harvest rate table (`hcs_harvest_rate_by_state.csv`) is referenced by the config but is not yet present on Cardinal. It is produced by `tools_conus/hcs_harvest_rate.py` via `run_hcs_rate_array.slurm`, and must be validated against FIA TPO before any BAU run. This is the current critical path item for the whole harmonized run, since BAU, conservation and intensive all scale from it.

A common harmonization and aggregation layer is needed: one ingest step per model that reads native output and emits the shared schema (per-ha live AGC, removals, stand age distribution) on the common grid, applies the anchor rescale, and writes a tidy long table keyed by model, state, scenario, year. The acceptance checks in the config become an automated gate on that table.

## 5. Sequencing

Phase A, shared scaffolding. Build and validate the FIA year-0 anchor table and the HCS per-state harvest rate table. These unblock every model and are independent of LANDIS coverage.

Phase B, LANDIS conformance on the eight calibrated states. Add a harmonized mode that runs the four Daigneault scenarios per state in per-plot mode at current climate, using the HCS per-state rate, then aggregates to state per-ha AGC and applies the FIA anchor. Validate against the acceptance criteria on ME first (the only state already in the cross-model set), then GA, MN, WI, MI, IN, OH, WA.

Phase C, the other four models. Confirm yield curves (48 by 4, direct), CBM (48 managed harvest, event mapping), CEM (extend from GA/ME/MN/WA), and FVS (CONUS by variant, harvest keywords) emit the shared schema under the same anchor and HCS harvest.

Phase D, LANDIS CONUS expansion. Extend LANDIS coverage from eight to 48 states per the rollout roadmap, feeding each new state into the harmonized comparison as it lands.

Phase E, synthesis. Assemble the model by state by scenario by year table, run the acceptance gate, and produce the cross-model comparison: per-ha AGC trajectories and 2100 stocks by scenario, with the spread across models as the headline uncertainty, plus the regional gradient.

## 6. Open questions to resolve with the team

Whether rcp45 sensitivity runs are in scope for the first comparison or deferred. How disturbance (wildfire, insects) is handled consistently, since CBM carries optional disturbance and LANDIS disturbance extensions are currently disabled; either all models include a common disturbance regime or none do, to preserve the model-only contrast. Whether intensive's clearcut plus plant is represented in LANDIS via the Biomass Harvest prescription set or requires a planting step. And which FVS pathway (native versus gompit) is the comparison baseline.
