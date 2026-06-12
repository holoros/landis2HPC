# PERSEUS session handoff — 2026-06-06

**Repo:** github.com/holoros/landis2HPC, branch main
**Chains from:** SESSION_HANDOFF_2026-06-02
**Focus:** kicked off the CONUS scenario projection track, patched the factorial generator, found and diagnosed the statewide-extent blocker, and reviewed the harmonized cross-model config.

---

## 1. Headline state

Eight states carry Tier 2 production theta (ME, WA, GA, MN, WI, MI, IN, OH), confirmed on Cardinal. (The 2026-06-02 handoff says nine; the on-disk inventory shows eight. Reconcile before the methods table.)

The scenario projection step had never run successfully for any state. This session got the first cells past extension loading, found three generator defects, patched two of them, and uncovered the real architectural blocker for statewide-extent runs (initial communities format). A CONUS rollout roadmap and a harmonized cross-model plan were written.

## 2. Scenario engine: what happened

The WA factorial built 2026-05-02 had failed all 12 cells at scenario load. Three defects:

1. Wind extension named `"Base Wind"`, which the v8 container does not register (it is `"Original Wind"`). Already fixed in the current generator; only the old May 2 cells carried it.
2. Generator copied the literature Tier 0 `SppEcoregionData.csv` (WA Douglas-fir ANPPmax 1850) instead of the calibrated production vector (430). Patched: the generator now auto-resolves and uses `states/<ST>/perseus/statewide/*_calibrated/SppEcoregionData_*_calibrated.csv`, with a loud warning and literature fallback if none exists.
3. Initial communities text file never staged. Patched, then hardened (see section 3).

Default `Duration` raised from 50 to 100 to match the projection horizon. Patched generator deployed to Cardinal at `tools/scenario_factorial.sh` (original backed up as `tools/scenario_factorial.sh.bak_pre_calibfix_20260606`) and committed to the repo at `pipeline/scenario_factorial.sh`.

## 3. The real blocker: statewide-extent initial communities (UNRESOLVED)

Two pilot jobs (11315259 baseline/none, 11315509 baseline/perseus) loaded all extensions correctly, including Biomass Harvest v6, then **segfaulted ~15 s in during landscape init**. Both are FAILED, not running.

Cause: Biomass Succession v7 (Universal Cohorts) requires the IC CSV format `MapCode,SpeciesName,CohortAge,CohortBiomass`. The only statewide IC is the legacy age-list `inputs/initial_communities.txt` (`LandisData "Initial Communities"`, no biomass column), which segfaults the Universal parser. Rasters are fine (ecoregions and IC both 19953 x 14774). The per-plot builders (`build_plot_ics_WA.py`) already emit correct Universal IC from FIA tree lists; there is simply no statewide-extent version.

To stop the generator from silently producing crashing runs, the IC logic now requires a Universal-format statewide IC (validates the header) and exits with guidance if only the legacy file is present. So the statewide factorial will now fail fast with a clear message rather than segfault.

Resolution paths, in order of preference:

1. For the harmonized cross-model comparison, do not run statewide-raster at all. Run LANDIS per-plot (the proven path) and aggregate to state per-ha AGC. This sidesteps the blocker. See `docs/harmonized_crossmodel_plan.md`.
2. If statewide-raster is wanted later for spatially explicit disturbance, build a statewide Universal IC: map every MapCode in `initial-communities.tif` to species/age/biomass cohorts (same FIA/TreeMap source the per-plot builder uses, assembled at the statewide MapCode level).

## 4. Harmonized cross-model config reviewed

Read `cbm_states/cross_state/libcbm/tools_conus/harmonized_scenarios.yml`. It is the keystone for an apples-to-apples assessment across yield curves, CBM, CEM, FVS and LANDIS (Daigneault 2024). All models share: CONUS lower 48, 2025 to 2100 by 5, carbon fraction 0.5, current climate (rcp45 sensitivity), FIA EXPNS forest area, a single HCS per-state harvest rate, and an FIA year-0 AGC anchor with `model_anchored(t) = model(t) * FIA_y0/model_y0`. Scenarios are reserve / BAU / conservation / intensive. Output headline is per-ha live AGC.

LANDIS is listed as ME only ("Aaron to CONUS"). Full plan in `docs/harmonized_crossmodel_plan.md`. Key point: the harmonized scenario set (4 management levels at current climate, HCS-sourced harvest, FIA-anchored) is NOT the 12 cell climate-by-harvest factorial; LANDIS needs a harmonized mode and a crosswalk (reserve=none, BAU=1x HCS, conservation=0.6x partial, intensive=2x clearcut).

Critical-path missing input: `hcs_harvest_rate_by_state.csv` is referenced by the config but not yet on Cardinal. It is produced by `tools_conus/hcs_harvest_rate.py` / `run_hcs_rate_array.slurm` and gates BAU, conservation and intensive for every model.

## 5. Jobs touched this session

| Job | Cell | Result |
|---|---|---|
| 11315259 | WA baseline/none (pilot_v2, hand-built) | FAILED, IC segfault |
| 11315509 | WA baseline/perseus (patched generator) | FAILED, IC segfault |

No scenario jobs are running. The unrelated `tm_total_chain` (11314579, cbm_states tools_conus) is a separate CONUS disturbance/TreeMap chain.

## 6. Files created or changed

In repo: `docs/CONUS_rollout_roadmap_v2.0.md` (48-state rollout tracker), `docs/harmonized_crossmodel_plan.md` (this session), `pipeline/scenario_factorial.sh` (patched generator), `docs/SESSION_HANDOFF_2026-06-06.md`. On Cardinal: `tools/scenario_factorial.sh` patched (backup `.bak_pre_calibfix_20260606`); WA `runs/pilot_v2/` and `runs/factorial/WA_clim_baseline_harv_perseus/` regenerated.

## 7. Next steps (priority order)

1. Build and validate the `hcs_harvest_rate_by_state.csv` (run `hcs_harvest_rate.py`) and the FIA year-0 anchor table. These unblock the whole harmonized comparison and are model-independent.
2. Add a harmonized mode to the LANDIS scenario pipeline: 4 Daigneault scenarios, per-plot, current climate, HCS per-state rate, FIA-anchored per-ha AGC. Validate on ME first against the acceptance criteria, then the other seven calibrated states.
3. Decide per-plot versus statewide-raster as the standing LANDIS execution mode (recommendation: per-plot for harmonized outputs; statewide-raster deferred and gated on a statewide Universal IC).
4. Continue the 48-state rollout per `docs/CONUS_rollout_roadmap_v2.0.md`: freeze the N4 and S2 blend references, pilot NH/VT/NY off N1.
5. Reconcile the eight-versus-nine state count and update Methods Section 3.
6. Refresh the WA v2.0 statewide carbon figure with the 306 Mg/ha year-100 value already on disk.
