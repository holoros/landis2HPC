# WI/MI LANDIS empty-stub fix (2026-06-09)

**Repo:** github.com/holoros/landis2HPC | **Cardinal:** PUOM0008, scratch `/fs/scratch/PUOM0008/crsfaaron`

## What was broken

WI and MI statewide LANDIS runs were producing header-only trajectory stubs (WI 2/636, MI 0/401 with data) despite the 06-08 handoff reporting them fixed. Two independent bugs, neither related to the wall-time or skip-check changes from 06-08:

1. **Missing baseline.** The drivers launch `run_statewide_buildfresh.sh` with `ST=WI`/`ST=MI`, so `apply_theta` reads `states/{WI,MI}/inputs/SppEcoregionData.csv`. Both `inputs/` directories were empty. `apply_theta` threw `FileNotFoundError`, the theta-applied `SppEcoregionData` was never built, every per-plot `SppEcoregionData.csv` was 0 bytes, and LANDIS ran with no growth parameters and emitted nothing. This affected the northern (MN-covered) plots, which built and ran but produced empty output.

2. **Build script ecoregion gap.** `build_plot_scenario_{MI,WI}.sh` are copies of the MN script and their `case "$RAW_ECO"` only handled ecoregions 46 to 52. MI's southern ecoregions 55, 56, 57 and WI's 53, 54 hit the `*) ERROR: unknown eco` branch and failed at build, leaving empty run dirs and no trajectory at all.

## What was changed (all on Cardinal scratch)

1. Built `states/MI/inputs/SppEcoregionData.csv` (ecoregions 50, 51, 55, 56, 57) and `states/WI/inputs/SppEcoregionData.csv` (47, 50, 51, 52, 53, 54), in the MN 24-species flora. MN-covered ecoregions copied verbatim from `states/MN/inputs/SppEcoregionData.csv`; uncovered southern ecoregions (MI 55/56/57, WI 53/54) inherit MN ecoregion-51 (North Central Hardwood Forests) rows, the warmest MN-calibrated analog.

2. Patched `build_plot_scenario_MI.sh` and `build_plot_scenario_WI.sh` to add cases for ecoregions 53 to 57 with EPA L3 names. Backups at `*.backup_20260609` in `landis2/tools/`.

3. Cleared the stale stub run dirs (859 MI, 838 WI) and relaunched `driver_sw_MI.slurm` (job 11406511) and `driver_sw_WI.slurm` (job 11406512).

## Validation (before mass resubmit)

Single-plot LANDIS runs through the full driver pipeline, all producing real 5-step trajectories:

| Plot | State | Eco | 2025 to 2100 TotalBiomass (g/m2) |
|---|---|---|---|
| 19 | MI | 51 (native MN) | 4,748 to 20,994 |
| 150 | MI | 55 (inherited) | 5,773 to 31,649 |
| 5 | MI | 56 (inherited) | 547 to 17,605 |
| 7 | MI | 57 (inherited) | 1,141 to 20,847 |
| 2 | WI | 53 (inherited, proxy) | 7,495 to 34,952 |
| 171 | WI | 54 (inherited) | 7,732 to 15,669 |

First 60 WI production trajectories after relaunch: all 6 lines with real data.

## Documented assumption (flag for refinement)

MI ecoregions 55/56/57 and WI ecoregions 53/54 use MN ecoregion-51 productivity and (via the build script's existing nearest-neighbor fallback) MN ecoregion-50 climate, because the MN flora has no native parameterization or climate template for those southern ecoregions. This is conservative for the most productive central-hardwood sites. The harmonized pipeline anchors each state's 2025 stock to the FIA design estimate (`harmonized_aggregate.R`), so the borrowed parameters mainly shape post-2025 dynamics, not the starting stock. All MI/WI plot initial communities use only the MN 24-species set (verified), so no species-universe extension was needed. Dedicated WI/MI ecoregion calibration would remove the assumption.

## Not yet in git

The two build-script patches and the new baseline CSVs live on Cardinal scratch only. If you want them version-controlled, commit the patched `build_plot_scenario_{MI,WI}.sh` and a small builder for the WI/MI `SppEcoregionData.csv` to the repo.

## Next

1. Let the MI/WI drivers finish (a few hours), then re-run `build_landis_reserve_perha.R` and `apply_harvest_scenarios.R` to close the six-state LANDIS multi-criteria table (WA, MN, OH, IN, WI, MI).
2. Build ME and GA statewide runs.
3. Re-anchor the yield curves to the FIA design value under the common harvest.
