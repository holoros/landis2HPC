# conus_tools: ecoregion readiness toolkit for the per-plot LANDIS pipeline

This directory generalizes the WI/MI fix (2026-06-09) into reusable checks and
repairs that apply to any state as the CONUS rollout proceeds. It targets one
failure class: a state whose plots fall in ecoregions that are not covered by
its `SppEcoregionData` baseline or not handled by its `build_plot_scenario`
script. Either case produces header-only trajectory stubs with no error, so the
statewide run "completes" while generating nothing usable. WI and MI lost full
run cycles to exactly this before it was caught.

## The two underlying bugs (what to prevent)

1. **Baseline gap.** The statewide runner overwrites each plot's
   `SppEcoregionData.csv` with the theta-applied baseline filtered to the plot's
   ecoregion. If that ecoregion is absent from `states/<ST>/inputs/SppEcoregionData.csv`,
   the filter returns nothing, LANDIS runs with no growth parameters, and the
   trajectory is header-only.
2. **Build gap.** `build_plot_scenario_<ST>.sh` uses a hardcoded `case` over
   ecoregion codes. A plot in an ecoregion not in the case hits `*) ERROR:
   unknown eco` and fails at build, leaving an empty run dir and no trajectory.

WA already avoids the baseline gap a third way: its build remaps uncovered
ecoregions (3, 15) onto calibrated analogs (2, 11). The toolkit supports all
three patterns and makes the mapping explicit data.

## Files

| File | Language | Purpose |
|---|---|---|
| `conus_preflight.R` | R | Doctor. Scans every state, resolves each plot ecoregion to its model ecoregion (through build remaps), and confirms baseline coverage + theta/species presence. Emits `conus_preflight_report.csv` and a PASS/FAIL summary. Exit 1 if any state FAILs. |
| `compose_sppeco_baseline.R` | R | Repair for baseline gaps. Fills missing ecoregions by copying a donor ecoregion already in the same baseline (same species flora), relabeled. Writes a provenance log. Never invents values, never crosses floras. |
| `extract_eco_crosswalk.R` | R | Captures each build script's implicit native/remap ecoregion handling into `tools/eco_crosswalk_<ST>.csv` (single source of truth). |
| `resolve_eco.sh` | bash | Drop-in replacement for the hardcoded `case` block. Resolves raw to model ecoregion via the crosswalk and the name via `ecoregion_names.csv`. Fails loudly on an unknown ecoregion instead of silently stubbing. |
| `ecoregion_names.csv` | data | CONUS EPA Level III code to name lookup, seeded from the project's own build scripts and run directories. |
| `crosswalks/` | data | Snapshot of the generated `eco_crosswalk_<ST>.csv` files. |

## Typical workflow

Run the doctor before launching any statewide driver:

```bash
module load gcc/12.3.0 R/4.4.0
Rscript conus_preflight.R                 # all states
Rscript conus_preflight.R --states GA,OH  # a subset
```

For a state flagged `BASELINE_GAP`, fill it (dry run first, then apply):

```bash
Rscript compose_sppeco_baseline.R --state OH --map "83=61"          # dry run
Rscript compose_sppeco_baseline.R --state OH --map "83=61" --apply  # writes + backs up
```

For a state flagged `BUILD_UNHANDLED`, either add the raw-to-model row to its
`eco_crosswalk_<ST>.csv` (preferred) or add the ecoregion name to
`ecoregion_names.csv`, then re-run the doctor.

## Current snapshot (2026-06-09)

After remediation: MI, WI, WA, MN, IN, OH, GA all **PASS** (7 of 8). OH ecoregion
83 was composed from donor 61 (Erie Drift Plain) and GA ecoregion 68 from donor
67 (Ridge and Valley); see `provenance/`. ME remains **FAIL** with `NO_PLOTLIST`,
which is correct: it has no `plot_to_ecoregion` file or build script yet and is
not ready to run. See `conus_preflight_report.csv`.

## Optional: make the build fully data-driven

To remove bug #2 permanently for every state, replace the `case "$RAW_ECO" in
... esac` block in each `build_plot_scenario_<ST>.sh` with:

```bash
ST=<ST>
source "$(dirname "$0")/../conus_tools/resolve_eco.sh"
resolve_eco "$RAW_ECO" "$ST"   # sets $ECO and $ECO_NAME, or exits non-zero
```

Run `extract_eco_crosswalk.R --apply` first so each state's current native and
remap behavior is preserved as `eco_crosswalk_<ST>.csv`. This is opt-in; the
preflight and composer work without it.

## Modeling note (carried from the WI/MI fix)

Composed ecoregions inherit a donor ecoregion's productivity. This is a
documented approximation, conservative for the most productive sites. The
harmonized pipeline anchors each state's 2025 stock to the FIA design estimate
(`harmonized/harmonized_aggregate.R`), so a composed baseline mainly shapes
post-2025 dynamics rather than the starting stock. Dedicated per-ecoregion
calibration removes the assumption.
