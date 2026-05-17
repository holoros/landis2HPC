# v8 Apptainer disturbance extension validation — probe summary

**Date:** 2026-05-15
**Probes run:** Original Wind ✓, Original Fire ✓, Climate BDA (loads, agent config WIP), Hurricane (deferred)
**Target:** Establish what's feasible for the climate × harvest × disturbance factorial.

## Probes attempted

### Original Wind (Extension-OriginalWind v4) — PASSED

WA plot 1 with `base-wind.txt` (single ecoregion 77, default severity table). Loads under bind-mounted patched `Landis.Console.dll`. Ran full 100-yr scenario with Biomass Succession + Original Wind. Wrote `output/wind/severity-{timestep}.tif` and event logs.

Run dir: `/fs/scratch/PUOM0008/crsfaaron/landis2/states/WA/perseus/runs/plot_1_wind_probe/`

Format note: `LandisData "Original Wind"` (not "Base Wind"). Same name change applies to the v8 release line.

### Original Fire (Extension-OriginalFire v5) — PASSED

Same WA plot 1 plus `base-fire.txt`. Required adjustments from v7 testing config:

1. `LandisData "Original Fire"` (v7 test still says "Base Fire").
2. `Species_CSV_File ./OriginalFire_Spp_Table.csv` — new mandatory line in v8.
3. Spp_Table.csv needs header row `SpeciesCode,FireTolerance` (the v8 parser drops first row as header).
4. Spp_Table values come from `SpeciesData.csv` `FireTolerance` column.

Built a 1-row Fire Region for ecoregion 77 with `InitialFireRegionsMap` pointing to a 1×1 tif (value 77). FuelCurveTable, WindCurveTable, FireDamageTable lifted from v8 NECN test scenario.

Run dir: `/fs/scratch/PUOM0008/crsfaaron/landis2/states/WA/perseus/runs/plot_1_fire_probe/`

Output: 21 timestep severity tifs plus `fire-log.csv` and `fire-summary-log.csv`.

### Climate BDA (Extension-ClimateBDA v5) — LOADS BUT AGENT CONFIG NEEDS WORK

Setup file `Climate-BDA_SetUp.txt` parses. Agent file syntax is brittle: my probe failed with `Found the name "ClimateVariableName" but expected "OutbreakPattern"` — the v5 parser enforces a strict declaration order. The v8 test agent file (`Climate-BDA_Agent_BUDWORM.txt`) is the source of truth; ports to other agents must follow the exact section ordering.

Action item: model each state's BDA agent (ME: SBW, GA: SPB, WA: MPB) on the v8 BUDWORM test directly rather than rewriting from the v7 spec.

### Hurricane (Extension-Hurricane v3) — DEFERRED

The Hurricane test config requires per-region wind exposure tifs (135°/180°/225°) and a `EvennessWindReductions.csv`. Not blocker, but it's a non-trivial GA-specific build: needs Atlantic storm tracks calibrated for the Southeast and per-ecoregion exposure surfaces. **Recommend deferring until GA Tier 2 calibration is complete** so we can prioritize one disturbance probe at a time and validate parameter realism against the SAMMS hurricane vulnerability literature.

## What this means for the factorial

The proposed climate × harvest × disturbance design is feasible in the existing v8 Apptainer infrastructure. The blockers are state-specific parameter files, not framework gaps. Specifically:

| Disturbance | Status | Per-state build effort |
|---|---|---|
| Original Wind | ✓ validated v8 | trivial — 5-line ecoregion table |
| Original Fire | ✓ validated v8 | low — needs Spp_Table + fire regions + FuelCurve per state |
| Climate BDA | extension loads, agent file needs author | medium — agent parameter literature search per state-pest |
| Hurricane | not yet probed | high — needs storm tracks + exposure maps |
| DynamicFire | not yet probed | high — fuel models + ignition climate sensitivities |
| LinearWind | not yet probed | likely low (variant of OriginalWind) |
| SocialClimateFire | not yet probed | medium — needs human ignition pattern parameterization |

## Recommended disturbance configuration per state

For a defensible first-cut factorial:

**Maine** — already has working Original Wind + Biomass Harvest. Add Climate BDA / SBW agent built on the v8 BUDWORM template. Three-level disturbance = none / wind-only / wind+SBW.

**Georgia** — Original Wind (low-intensity baseline, hurricanes deferred) + Climate BDA / SPB. Three-level = none / wind+SPB at baseline / wind+SPB amplified.

**Washington** — Original Fire + Climate BDA / MPB. Three-level = none / fire+MPB at baseline / fire+MPB amplified.

The "amplified" level for each state uses climate-modified disturbance regime parameters (higher fire ignition probability + lower precip threshold for MPB outbreak under SSP585).

## Implications for paper / proposals

The factorial works methodologically. The bigger gating step is **per-state Tier 2 calibration**, because the scenario inferences (carbon ↔ harvest tradeoff, climate-driven mortality) are only defensible if the underlying productivity parameters are calibrated. With ME Tier 2 complete and WA Tier 0 in progress, the realistic timeline to a publication-grade factorial is:

- 2 weeks: WA Tier 1+2, GA Tier 2 (current calibration sprint)
- 2 weeks: per-state disturbance agent file authoring + single-plot probes
- 1 week: factorial scenario builder generalization (extend the WA single-cell builder to multi-extension)
- 2 weeks: factorial runs across 3 states × 36 cells × 4,500 plots
- 2 weeks: aggregation + figures
- Total: ~9 weeks from today to factorial paper-ready

## Files added

- `/fs/scratch/.../runs/plot_1_wind_probe/` — validated WA Wind run
- `/fs/scratch/.../runs/plot_1_fire_probe/` — validated WA Original Fire run (with OriginalFire_Spp_Table.csv)
- `/fs/scratch/.../runs/plot_1_bda_probe/` — BDA setup parses, agent file needs work
- `outputs/20260515_disturbance_extension_probes.md` — this memo

## Next actions

1. Author Climate BDA agent files using v8 BUDWORM test as template. One agent per state-pest: SBW-ME, SPB-GA, MPB-WA.
2. Defer Hurricane until GA Tier 2 is done.
3. Build a `build_plot_scenario_<state>_factorial.sh` that takes (climate, harvest, disturbance) levels as arguments and emits a complete scenario dir.
4. Validate one full factorial cell (climate=baseline, harvest=perseus, disturbance=fire) on a WA plot before going to scale.
