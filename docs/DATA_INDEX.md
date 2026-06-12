# Data index — harmonized assessment outputs

The Cardinal scratch dir /fs/scratch/PUOM0008/crsfaaron/FIA holds 472 CSVs (canonical
deliverables + per-state intermediates + diagnostics). This catalogs the CANONICAL set.
organize_deliverables.sh copies these into a tidy _deliverables/ tree (originals untouched).

## Proposed tidy layout (organize_deliverables.sh builds this on scratch)

```
FIA/_deliverables/
  00_anchor/        fia_agc_anchor_design_by_state.csv
  01_reserves/      <model>_reserve_anchored.csv + _disturbed.csv (per model)
  02_scenarios/     harmonized_master_all_scenarios, _ensemble_by_scenario, _conus_by_scenario
  03_ensemble_ci/   harmonized_best_estimate, _crossmodel_ci, _crossmodel_5model
  04_uncertainty/   uncertainty_conus*, *_by_state_year*, cbm_oat_bands, yc_bands,
                    fvs_posterior_ci_all, cbm_engine_gap
  05_benchmark/     americanforests_cbm_benchmarks, benchmark comparison
  06_rasters/       gcbm_rasters/<ST>/ (GCBM spatial GeoTIFFs) + landis_ME_spatial (biomass
                    rasters from the Maine landscape run), when runs land
  README.md         this catalog
```

## Spatial campaign files (2026-06-11)

- build_state_gcbm_stack.R — state-generalized GCBM source-raster builder (CONUS TreeMap clip).
- build_gcbm_stack_wave.sh — SLURM array building the MN/WA/OR/CA/GA source stacks.
- mosaic_retain_gcbm.py / retain_maine_rasters.sh — mosaic per-tile GCBM GeoTIFFs -> retained
  full-extent rasters per variable per year.
- slurm_maine_fullstate_reserve2100.sh — Maine 30m landscape LANDIS reserve to 2100 (biomass
  rasters retained in outputs/biomass).
- extract_me_spatial_reserve.R -> landis_ME_spatial_vs_plot.csv — spatial-landscape vs
  per-plot LANDIS reserve, both on the same FIA anchor (isolates the spatial-structure effect).

## Canonical files (what each is)

ANCHOR
- fia_agc_anchor_design_by_state.csv — FIA 2025 live-AGC design total + cv per state. The
  common anchor every model is scaled to.

RESERVES (per model; agc_TgC_anchored by state x year; _disturbed = after overlay)
- fvs_reserve_calibrated_anchored.csv — FVS calibrated (primary FVS member).
- fvs_reserve_default_anchored.csv — FVS default params (sensitivity).
- fvs_reserve_calibrated_v4_anchored.csv — DG-adopted re-run.
- fvs_reserve_*_treemap_anchored.csv — TreeMap-allocated FVS variants.
- cbm_reserve_anchored.csv — CBM libcbm, eastern entry-point corrected (cbm_reserve_raw_ =
  pre-correction).
- yc_reserve_anchored.csv — yield curves, re-anchored to common harvest.
- cem_reserve_anchored.csv — CEM (26 states; 48-state native-2100 re-adapt pending).
- harmonized_landis_reserve_9state.csv — LANDIS (9 states; per-plot).

SCENARIOS
- harmonized_master_all_scenarios.csv — LONG: model x dist_mode x state x scenario ->
  total / forest / hwp / npv. The full matrix.
- harmonized_ensemble_by_scenario.csv — per state x mode x scenario ensemble (equal +
  benchmark) + 90% CI.
- harmonized_conus_by_scenario.csv — CONUS rollup by scenario x mode.

ENSEMBLE + CI
- harmonized_best_estimate.csv — weighted best estimate + 90% credible interval per state x
  year (equal-weight primary; benchmark-weight sensitivity).
- harmonized_crossmodel_ci.csv — per-model 2100 value with 90% CI at overlap states
  (distinguishability test).
- harmonized_crossmodel_5model.csv — 5-model comparison table.

UNCERTAINTY (intra-model bands)
- cbm_oat_bands.csv — CBM one-at-a-time parameter sweep band.
- cbm_engine_gap.csv — GCBM-over-libcbm % per state (the dominant intra-CBM uncertainty).
- yc_bands.csv — yield-curve rcp + simulation band.
- fvs_posterior_ci_all.csv — FVS Bayesian posterior band.
- uncertainty_conus_disturbed.csv / uncertainty_by_state_year*.csv — variance decomposition.

BENCHMARK
- americanforests_cbm_benchmarks.csv — extracted American Forests state CBM report numbers
  (MN, OR, CA, MD, PA) for external validation.

## Intermediates (the other ~440 CSVs, not canonical)

Per-state CBM pools (pools_<ST>_BAU.csv), per-state CEM ci_summaries, LANDIS per-state
reserve extracts (landis_<ST>_reserve.csv), FVS per-variant posterior draws, diagnostic
and OAT sweep files. Kept for reproducibility; not part of the headline deliverable set.
