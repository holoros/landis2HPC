# PERSEUS extension to Indiana + Minnesota (+ Ohio): readiness assessment + v2.0 scope

**Date:** 2026-05-20
**Status:** scoping memo — assesses what exists on Cardinal vs what PERSEUS calibration extension requires

## TL;DR

Indiana, Minnesota, and Ohio all have state directories on Cardinal at `/fs/scratch/PUOM0008/crsfaaron/landis2/states/{IN,MN,OH}/`. They are at substantially different levels of readiness:

| State | LANDIS-II inputs | Initial communities | FIA observations | PERSEUS calibration | Production status |
|---|---|---|---|---|---|
| **MN** | ✓ Complete (25 species, 7+ ecoregions, 3 climate scenarios) | ✓ Built (`initial-communities.tif`, 113 MB) | ✗ `untreated_plots_MN.csv` not extracted | ✗ Not staged | factorial scenarios already running |
| **IN** | ✓ Complete (23 species, 5 ecoregions, baseline + SSP245/585) | ✗ Not built | ✗ Not extracted | ✗ Not staged | 2 refined climate runs only |
| **OH** | ✓ Complete (species, ecoregion, baseline + SSP245/585) | ✗ Not built | ✗ Not extracted | ✗ Not staged | 2 refined climate runs only |

**Recommendation:** Promote MN to a v2.0 calibration target on a fast track (data is mostly there). Stage IN and OH on a slower track that depends on FIA tree-list assembly and IC builder. Treat as the natural extension of the v1.0 ME/GA/WA framework.

## What exists per state

### Minnesota (mature; closest to PERSEUS-ready)

**Inputs (`states/MN/inputs/`):**
- `SpeciesData.csv` — 25 species: BF, TAM, WS, BS, RS, JP, RP, WP, CE, HE, RM, SM, YB, PB, BE, WAS, BAS, QA, BA, WO, RO, BO, BSW, AE
- `SppEcoregionData.csv` — 169 rows across L3 ecoregions 46–52+
- `MN_ecoregion_l3.tif` (4.6 MB)
- `initial-communities.tif` (113 MB) — full-state IC raster already built
- `initial_communities/` subdirectory with mapcode lookup tables
- `MN_COND.csv` (190,615 FIA condition records) — FIA condition file for tree-list extraction
- Climate: `PRISM` baseline + `HadGEM3 SSP245`, `HadGEM3 SSP370`, `HadGEM3 SSP585`
- Landowner shares CSV + management-area rasters (already factorial-ready)

**Runs (`states/MN/runs/`):**
- `factorial/` — multiple scenario cells: baseline+baseline harvest, baseline+increased, baseline+none, baseline+perseus harvest, ssp245+baseline
- `factorial_chain.slurm` — chained submission script
- `refined_HadGEM3-GC31-LL_ssp245/` — refined climate run
- This state is materially further along than IN/OH on the scenario side

**Gap for PERSEUS calibration:**
- `untreated_plots_MN.csv` not in `tools/` — needs extraction from `MN_COND.csv` and FIA tree files filtering for untreated, multi-cycle remeasured plots
- `plot_ics_full/_summary.csv` equivalent — per-plot ICs in PERSEUS format with `plot_id` and `plt_cn` mapping
- `perseus/` subdirectory not yet created

### Indiana (data scaffolded; IC not built; calibration not staged)

**Inputs:**
- `SpeciesData.csv` — 23 species: WO, NRO, BO, POST, SHO, SHA_HK, MOK_HK, SM, RM, YP, BE, WAS, BAS, BSW, WALN, SWEETGUM, BLACKGUM, SYC, SASSAFRAS, DOGWOOD, EWP, QA, AE
- `SppEcoregionData.csv` — 116 rows across 5 L3 ecoregions (54, 55, 56, 71, 72)
- `IN_ecoregion_l3.tif` (705 KB)
- `PRISM_IN_l3.csv` + HadGEM3 SSP245/585
- ✗ no `initial-communities.tif`
- ✗ no `IN_COND.csv` visible

**Runs:**
- `refined_HadGEM3-GC31-LL_ssp245/`, `refined_HadGEM3-GC31-LL_ssp585/` — 2 refined climate runs

**Gap:**
- IC raster needs to be built from FIA tree-list before calibration is possible
- FIA condition file needs to be staged
- Then same scaffolding as MN

### Ohio (scaffolded similarly to IN)

**Inputs:**
- `SpeciesData.csv`, `SppEcoregionData.csv`, `OH_ecoregion_l3.tif` (4.6 MB)
- `PRISM_OH_l3.csv` + HadGEM3 SSP245/585
- ✗ no `initial-communities.tif`

**Runs:**
- 2 refined climate runs only

**Gap:** Same as IN.

## What PERSEUS calibration extension requires per state

For any new state to enter the calibration ladder framework, we need:

1. **`untreated_plots_{ST}.csv`** in `landis2/tools/`. Format: PLOT, FIRST_PLTCN, FIRST_INVYR, PUB_LAT, PUB_LONG, COUNTYCD, N_CYCLES, BIOM_{1997..2024}_Mgha columns. Built by extracting plots that are: (a) forested in the FIA cycle, (b) untreated (no TRTCD/CUTRECDR records), (c) remeasured at least twice across the 2001–2022 window. Source data: state's PLOT, COND, TREE, and POP_PLOT_STRATUM_ASSGN tables from the FIA Datamart.

2. **`plot_ics_full/` directory** with per-plot initial community files. Structure: `plot_{N}/initial_communities.csv` + `_summary.csv` linking `plot_id ↔ plt_cn`. Built by running an LANDIS IC builder script on each plot's tree-list.

3. **`build_plot_scenario_{ST}.sh`** — per-plot LANDIS scenario builder. Copies the IC, species/ecoregion files, climate, and writes the scenario.txt + biomass-succession.txt for that single plot's ecoregion.

4. **`apply_theta_{ST}_perspecies.py`** — theta application. Takes the candidate's CSV of species multipliers and applies to `SppEcoregionData.csv` to write a modified version.

5. **`run_param_set_{ST}_t2.sh`** — inner CMA-ES runner. Submit the SLURM array of per-plot runs, wait with the v1.0.1 settling check, compute LL with the per-plot pairing logic.

6. **`cma_es_optimize_{ST}.py`** — CMA-ES driver. State-specific species name list. Calls into the runner. Uses the v1.0 driver guards (active-growth, empty-aggregator, MIN_N_PAIRS ≥ 300).

7. **A `perseus/` subdirectory** under the state for the calibration scratch/Bayesian output.

8. **Climate match**. The v1.0 calibrations use the multi-cycle hindcast period 2001–2022 for residual pairing. MN/IN/OH would need their PRISM baseline mapped to that same window. MN has 3277 climate days = ~9 years of data (2014–2023) and IN has 1081 days = ~3 years. May need to extend the climate baseline file to cover the full hindcast window.

## v2.0 fast-track plan (MN-first, IN + OH following)

**Phase 1 — MN PERSEUS staging (~1–2 days of focused work):**
1. Extract `untreated_plots_MN.csv` from `MN_COND.csv` + `MN_TREE.csv` (FIA Datamart) using the same multi-cycle filtering logic that produced `untreated_plots_{GA,WA}.csv`.
2. Build `plot_ics_full/` per-plot subset (~5,000–10,000 MN plots expected).
3. Adapt `build_plot_scenario_WA.sh` to `build_plot_scenario_MN.sh` (ecoregion codes + species list).
4. Adapt `cma_es_optimize_WA.py` to `cma_es_optimize_MN.py` with MN species list + 25 species × 2 = 50 parameter T2 vector.
5. Launch MN Tier 1 theta ladder first (8 θ values, ~8 hours total).
6. If T1 ladder converges cleanly, launch MN Tier 2 CMA-ES (~12–15 hours).

**Phase 2 — IN + OH PERSEUS staging (~3–5 days):**
1. Build IC raster from FIA tree-list using existing builder (apply to IN, then OH).
2. Extract `untreated_plots_{IN,OH}.csv` from FIA Datamart.
3. Build `plot_ics_full/` per-plot subsets.
4. Repeat Phase 1 scaffolding adaptations + Tier 1 ladder + Tier 2 chain.

**Phase 3 — v2.0 release:**
- 5-state production calibration table (ME, GA, WA, MN, IN, OH or any subset that lands by submission deadline).
- Cross-state directional asymmetry analysis extended to 5 states. The MN result is the most interesting prior because the northern hardwood forest type may show the same direction as ME (under-prediction) or the opposite (more like Great Lakes climate forcing); IN's mixed hardwood would test the eastern temperate gradient between ME and GA.
- Methods paper amended with v2.0 calibration table + extended discussion. Companion scenario paper extended with 5-state factorial.

## Cardinal compute budget

A single Tier 2 CMA-ES chain at the v1.0 sizing (14 candidates × 8 iterations × ~600s/candidate × ~800 plots/candidate) is approximately 12–15 wall-hours per state. Adding three new state chains is ~36–45 wall-hours of dedicated compute. Each state's T1 ladder (8 θ values × ~800 plots × ~10s/plot) is approximately 1–2 wall-hours. Total v2.0 compute: ~50 wall-hours, comfortably within the OSC allocation.

## Decision point

Should we commit to v2.0 5-state calibration before the v1.0 manuscript goes to journal? Trade-offs:

- **Yes**: stronger methodological contribution, generalizes the framework to broader US forest types, more compelling cross-state asymmetry analysis with 5 states vs 3.
- **No**: v1.0 is already substantive (3 contrasting states, novel methodology). Adding states delays journal submission by 1–2 weeks at minimum. The companion scenario paper can run independently with MN's existing factorial, and v2.0 can be a follow-up paper.

**Recommended path:** ship v1.0 methods paper as-is to bioRxiv + Environmental Modelling & Software now, and begin MN PERSEUS staging in parallel. If MN lands cleanly within 2 weeks, fold into manuscript revision or supplementary materials. If not, defer to v2.0 / companion paper without holding up v1.0.

## Immediate autopilot next step if approved

1. Identify whether `tools/untreated_plots_MN.csv` can be auto-derived from the existing `MN_COND.csv` + FIA tree-list scripts that produced WA/GA. If yes, scaffold MN PERSEUS today.
2. Otherwise, stage a feasibility check: run the WA T2 driver code through the MN data path (with MN species list + ecoregion codes) to identify the first blocking dependency.

This memo flagged as `docs/IN_MN_extension_scope_memo.md` for co-author review.
