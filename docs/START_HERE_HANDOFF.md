# START HERE — harmonized multi-model CONUS forest carbon assessment

Single-file bootstrap for resuming this project in a fresh conversation. Read this first;
it points to everything else. Last updated 2026-06-11.

## How to resume (paste this intent into the new conversation)

"Resume the harmonized multi-model CONUS forest carbon assessment on OSC Cardinal. Read
landis2HPC/docs/START_HERE_HANDOFF.md and continue from the open items. Selected folder is
CRSF-Cowork/repos/fvs-modern; the harmonized work is in the landis2HPC repo. Preferences:
concise, R-first, no hyphens."

## What this is (one paragraph)

Five independent forest-carbon models (FVS, LANDIS-II, CBM, yield curves, CEM) run on ONE
common pipeline so model STRUCTURE is the only difference. Every trajectory is anchored to
the same FIA 2025 live aboveground-carbon design total per state
(total(t) = FIA_total x perha(t)/perha(2025); the ratio cancels units and carbon fraction),
driven by the same HCS common harvest, the same four scenarios (reserve 0x / conservation
0.6x / BAU 1x / intensive 2x), and the same first-order IPCC Tier-2 harvested-wood-products
pool. The reserve (no harvest, no disturbance) is the backbone. Framing follows Daigneault
et al. 2024. Goal: apples-to-apples cross-model comparison with uncertainty quantified
(structural between-model + parameter within-model + FIA sampling).

## Access (Cardinal / OSC, project PUOM0008, user crsfaaron)

SSH: key is mounted in the .ssh-cardinal folder. Pattern (bash calls are isolated, 45s cap):
write a /tmp ssh config with IdentityFile=<mounted key>, `ssh -F <cfg> cardinal`. Long ops
run via nohup + poll, or sbatch. /tmp is login-node-local (not shared across calls) — write
shared driver scripts under /fs/scratch. Scratch root for harmonized work:
`/fs/scratch/PUOM0008/crsfaaron/FIA`. Repos on Cardinal: cbm_maine (CBM + GCBM), landis2
(LANDIS), fvs-modern + fvs-conus (FVS), fia_cem_projections (CEM). Local repo (this folder):
CRSF-Cowork/repos/landis2HPC (harmonized/ scripts + docs/).

## Model state + coverage (the scorecard)

| Model       | Coverage  | Horizon | Intra-model band            | Notes |
|-------------|-----------|---------|-----------------------------|-------|
| FVS         | 48 states | 2100    | Bayesian posterior (~3%)    | calibrated (gompit); DG adopted all variants; West over-projects (intrinsic, not a bug) |
| Yield curve | 48 states | 2100    | rcp45/85 + sim CI (~8%)     | re-anchored to common harvest |
| CBM         | 48 states | 2100    | OAT + GCBM engine gap (measured) | cbm_states per-state pipeline; GCBM spatial 6/48 (GA IN ME MN OR WA); libcbm calibration FINALIZED to FIA-expansion (B1.3); measured engine gap integrated for the 6 |
| CEM         | 37 (33 native-2100) | 2100 | anchor SE (scenario band TBD)| conus2100 array landed 33 native-2100 states; adapter now prefers conus2100 dirs; 4 still running. Native 2100 propagated through overlay+ensemble+CI 2026-06-13. Full overlap reaches 9 when the LANDIS states (MN WI MI ME VT + WA NH) finish in CEM. |
| LANDIS-II   | 9 -> 33+  | 2100    | anchor SE (replicate TBD)    | per-PLOT runs (not spatial); waves 1-4 calibrating; Plains/Rockies need species lit |

Full 5-model overlap today: IN, NH, OH, WA (4 states; coverage-driven, recomputed 2026-06-13;
the prior "IN/OH/NH" was a hardcoded artifact). Limiters are LANDIS (9) and CEM (36). When the
running CEM 48-state array lands it absorbs the 5 LANDIS states not yet in CEM (MN, WI, MI, ME,
VT), so full overlap jumps to all 9 LANDIS states and grows with the LANDIS waves (toward 33).
build_crossmodel_ci.R + the headline figure are now coverage-driven and auto-expand. Three-model
CONUS backbone (FVS/YC/CBM, 48 states x 4 scenarios x 2 disturbance modes) is COMPLETE with
ensemble + CIs.

## Headline numbers (current)

CONUS reserve best estimate, disturbance-aware (harmonized_best_estimate.csv): 2025 15.3,
2050 19.9, 2075 22.6, 2100 ~23 Pg C (reserve = no harvest, UNCHANGED by the harvest recalibration).
Central-estimate choice (CONUS reserve 2100, FVS+YC+CBM): arithmetic mean 26.3 / geometric mean 25.4
/ median 24.2 Pg C (harmonized_conus_geomean.csv). The geometric mean (ens_geom in best_estimate;
harmonized_ensemble_geomean.csv) runs ~9-12% below the arithmetic mean by down-weighting the high FVS
end-member and is the recommended robust central estimate for these strictly-positive stocks.
All-scenarios CONUS 2100 ensemble median (Tg C, nodisturb), AFTER the 2026-06-12 harvest recalibration
(now canonical): reserve 24,294 / conservation 20,188 / BAU 15,929 / intensive 11,056; disturbed
~5% lower per scenario. These supersede the pre-calibration values (BAU was 20,218, intensive 17,860);
the common harvest was recalibrated from the TM2016 layer to the FIA NFI removal benchmark, which raised
harvest in most states and lowered the managed-scenario carbon (BAU -21%, intensive -37%). See
HARVEST_RECALIBRATION_PLAN_2026-06-12.md. Pre-calibration canonical is backed up in
FIA/precal_backup_20260612 (reversible). Cross-model 2100 divergence is REAL signal: 14-15 of 15 model
pairs distinguishable by non-overlapping 90% CIs at the overlap states. Structural
uncertainty dominates parameter uncertainty by ~40x at 2100.

## Spatial outputs — which models have them

GCBM (moja FLINT, natively gridded) and landscape-mode LANDIS-II produce spatial rasters;
both are now being run + retained. The harmonized backbone otherwise runs plot/stratum-based
(FVS, CBM-libcbm, CEM, yield curves, and the per-plot LANDIS used in the cross-model
comparison) so the headline numbers stay apples-to-apples.

- GCBM: full CONUS spatial run underway. Maine pilot RUNNING (per-tile GeoTIFFs ->
  retained mosaics). build_state_gcbm_stack.R generalizes the source-stack build to any
  state from CONUS TreeMap; source-stack wave for MN/WA/OR/CA/GA LAUNCHED (job 11511365).
  Per-state pipeline: build_state_gcbm_stack.R -> build_inputs.sh (tile) -> run array ->
  retain_maine_rasters.sh (mosaic). Next: generalize build_inputs.sh prefix for the wave.
- LANDIS spatial-vs-non-spatial (Maine): the per-plot LANDIS (cross-model member) vs a true
  30m landscape run from the SAME TreeMap-derived initial communities + calibrated params +
  reserve. slurm_maine_fullstate_reserve2100.sh (job 11511377) runs the landscape reserve to
  2100, writing per-species biomass rasters (RETAINED in outputs/biomass). When it lands,
  extract_me_spatial_reserve.R builds landis_ME_spatial_vs_plot.csv: both anchored to the
  same FIA 2025 total, so 2025 matches and the 2100 gap isolates the spatial-structure effect
  (neighborhood dispersal, ecoregion climate, landscape competition) vs independent plots.

## Session 2026-06-12 fixes (two failed jobs diagnosed + resubmitted)

- gcbm_stack wave (was 11511365, all 5 states FAILED in ~2s): submit script loaded only
  gcc + R, not the geospatial modules, so terra could not find libproj.so.25. Fixed the
  module block in cbm_maine/tools/build_gcbm_stack_wave.sh to the mandatory order
  (gcc; then gdal/geos/proj; then R). RESUBMITTED as 11511540, now running clean.
- CEM array (11505310) had 5 state failures: MI/NC/SC/WI were FIA datamart download
  timeouts (download.file timeout arg is ignored; R honors options(timeout), default 60s on
  ~200MB TREE.zip). FIADB is already staged on scratch + $HOME/fia_data as ST_TABLE.csv, so
  R/01_data_prep.R download_fia_rfia now reads local CSVs via rFIA::readFIA (same
  FIA.Database structure) and only downloads genuinely missing states. Verified on DE
  (27042 TREE rows). Eliminates the datamart-timeout failure mode entirely.
  DE failed on a separate count() abort: a sparse Monte Carlo draw yielded zero matches,
  leaving all_match_pairs a columnless tibble(). Added a thin-data guard in
  R/02_cem_matching.R that rebuilds it as a typed 0-row tibble from the iter1 schema so
  every subject carries forward as unmatched. Both R files parse-checked. The 5 states
  RESUBMITTED as 11511649 (--array=1,4,6,9,12 = DE,MI,NC,SC,WI). Backups: *.bak.*_20260612.
- Version control: the cbm_maine GCBM build scripts (build_gcbm_stack_wave.sh +
  build_state_gcbm_stack.R) were committed + pushed to github.com/holoros/cbm_maine (main).
  fia_cem_projections was NOT a git repo; it is now git-init'd on Cardinal (commit 4c09748,
  same SHA) with a strict .gitignore (data/output/logs/figures/config CSVs + *.rds/*.csv
  excluded; code only, 316 files) and pushed to a new private repo
  github.com/holoros/fia-cem-projections. Cardinal cannot auth to GitHub directly, so pushes
  go via git bundle -> sandbox -> gh. To link Cardinal to origin later, register a holoros
  token/key on Cardinal and `git remote add origin` (HEAD already matches 4c09748).

## Running jobs (2026-06-11, check with squeue -u crsfaaron)

- 11505497 me_state — GCBM Maine 20-tile spatial array (RUNNING; 65k+ per-tile GeoTIFFs so far).
- 11505514 me_retain — mosaics per-tile -> retained full-extent ME rasters (AG_Biomass_C,
  Total_Ecosystem_C, Age) into FIA/gcbm_rasters/ME. Dependency afterany:11505497.
- 11511365 gcbm_stack — GCBM source-stack build wave (MN WA OR CA GA), next states for the
  full CONUS GCBM run.
- me_spatial_res — Maine landscape LANDIS reserve to 2100 (30m, biomass rasters). First submit
  (11511377) FAILED on a maine_ vs me_ prefix mismatch in the ecoregion path; fixed and resubmitted
  as 11555051. extract_me_spatial_reserve.R produces landis_ME_spatial_vs_plot.csv when it lands.
- gcbm_tile (11555044) — tiling the 5 GCBM source stacks (MN WA OR CA GA) with per-state PRISM MAT
  (state_mat_prism.csv: MN 5.2, WA 8.5, OR 8.7, CA 14.6, GA 17.8 degC; NOT Maine 5.67). Next:
  per-state GCBM run arrays -> retain -> measured engine gap (build_inputs_state.sh is the generalized tiler).
- AUTOPILOT: scheduled task `harmonized-carbon-monitor` (daily 07:00) checks these jobs and runs the
  integration steps as each lands (CEM re-adapt, spatial-LANDIS extract, GCBM run+gap, LANDIS integrate).
- 11505310 + 11505312 cem2100 — CEM 48-state native-2100 (16-cycle) array (RUNNING, ~7h).
- LANDIS waves 1-4 t2 chains (24 states calibrating). Monitor check_t2v2_chains.sh.
- (v7_qrf / hg_v6 / hcb_v6 / cspi are unrelated raster ML jobs.)

## Open items (priority order)

1. WHEN cem2100 lands: re-run build_cem_reserve.R on the conus2100_<ST> dirs -> native-2100
   CEM reserve for 48 states (drops the 2095->2100 extrapolation), then re-run the overlay +
   scenarios + master + ensemble + CI.
2. GCBM full CONUS run (in progress): WHEN ME retain lands, verify FIA/gcbm_rasters/ME mosaics
   + replace ME regional-default engine gap with the measured value + zenodo-deposit. WHEN the
   MN/WA/OR/CA/GA stacks (11511365) land, generalize build_inputs.sh prefix and run those
   states (array + retain), then loop the remaining states. Each completed state swaps its
   regional-default engine gap for a measured one in cbm_engine_gap.csv.
2b. LANDIS spatial Maine (11511377): WHEN it lands, run extract_me_spatial_reserve.R ->
   landis_ME_spatial_vs_plot.csv (spatial vs per-plot reserve) + retain outputs/biomass rasters.
3. LANDIS integration as t2 chains converge: run_statewide_buildfresh.sh <ST> theta_best.csv
   -> add via the add_nh_vt pattern (extend build_landis_reserve_perha.R --states). Refresh
   master/ensemble/CI.
4. Plains/Rockies LANDIS (KS NE OK ND SD MT CO NM AZ UT WY NV ID TX): fill SpeciesData for
   the 5 cluster scaffolds (harmonized/plains_rockies/cluster_<C>_extension_species.csv;
   most species have published LANDIS params, ~12 pinyon-juniper species need derivation),
   freeze cluster ref thetas, onboard members. This is the LANDIS-team domain step.
5. Last anchor-only bands: LANDIS replicate band (seed-varied reruns) + CEM scenario band.
6. Optional: substitution benefit (HWP displacing concrete/steel); better western harvest
   layer (LCMS/FIA TPO) to test the OR 45% benchmark; true FIA-initialized CBM run.

## Key recipes

- Re-stress everything: `python3 stress_test_harmonized.py` (0 failures = pass).
- Rebuild ensemble/CI after any reserve change: `Rscript build_master_scenarios.R` then
  `build_ensemble_estimate.R`, `build_crossmodel_ci.R`, `uncertainty_ensemble.R`.
- New LANDIS state: build_plot_scenario + apply_theta + SppEcoregionData baseline ->
  calibrate (cma_es) -> run_statewide_buildfresh.sh -> add_nh_vt pattern.
- GCBM new state: build_inputs.sh (tile the WGS84 stack) -> run_maine_statewide.sh pattern
  -> retain_maine_rasters.sh (mosaic_retain_gcbm.py).
- CEM re-adapt: build_cem_reserve.R pointed at conus2100_<ST> dirs.

## Document map (landis2HPC/docs/)

- START_HERE_HANDOFF.md — this file (the index).
- SESSION_HANDOFF_2026-06-11_FULL.md — detailed full handoff.
- HARMONIZED_ASSESSMENT_REPORT_2026-06-11.md/.docx — the assessment report.
- ENSEMBLE_METHOD_2026-06-11.md — weighted-ensemble method.
- BENCHMARK_VALIDATION_2026-06-10.md — American Forests CBM benchmark comparison.
- HWP_BENCHMARK_NASH_DOMKE_2026-06-12.md — harvest + HWP cross check vs Nash and Domke 2026 (MI/MN/WI);
  flags the MN HCS rate as under set and recommends species specific carbon fractions + survey harvest
  calibration. Reproducible: harmonized/benchmark_nash_domke_harvest.R.
- HWP_AND_COVERAGE_FINALIZATION_2026-06-11.md — product carbon + CEM/LANDIS finalization.
- CONUS_COMPLETION_CAMPAIGN_2026-06-11.md — CEM/LANDIS to 48 states campaign.
- GCBM_AND_PLAINS_ROCKIES_2026-06-11.md — GCBM spatial run + Plains/Rockies species.
- FVS_SDIMAX_AUDIT_2026-06-10.md, FVS_DG_ADOPTION_GAP_2026-06-10.md — FVS investigations.
- DATA_INDEX.md — catalog of the output CSVs (what each file is).

## Data + scripts

Scripts: landis2HPC/harmonized/ (build_*.R, apply_*.R, *_test.py, mosaic_retain_gcbm.py,
build_plains_rockies_species.py). Outputs live on Cardinal FIA scratch (472 CSVs; the
canonical ~25 are cataloged in DATA_INDEX.md). The local repo holds the scripts + docs +
the plains_rockies scaffolds; large outputs and rasters stay on Cardinal scratch and are
archived to Zenodo at publication.

## ============================================================================
## 2026-06-14 CONSOLIDATED UPDATE (read this first; supersedes older sections)
## ============================================================================

STATUS: the 3-model CONUS backbone (FVS, yield curves, CBM, 48 states x 4 scenarios x 2 disturbance
modes) is complete with ensemble, CIs, geometric-mean + median central estimates, and external
benchmark validation. A full stress test (model x state x scenario) passes with ZERO anomalies. Team
report: Harmonized_Carbon_Team_Report_2026-06-14.docx.

KEY FINDINGS: inventory/stress clean. Cross-model 2100 divergence median CV 46%, fold 3.9x,
CONCENTRATED IN THE WEST (NV 8x, NM 11x, CA 9x, CO 8x) = real structural signal. See inv_*.csv,
MODEL_INVENTORY_AND_PERSEUS_2026-06-14.md.

CBM (clarified + finalized): CENTRAL = libcbm 76-yr stratum engine (cbm_reserve_anchored, 48 states
2025-2100). GCBM (spatial) is the engine-gap REFERENCE (5-yr cbm_states runs), not the central
member. libcbm calibration FINALIZED to FIA-expansion (B1.3 per-state vol-to-bio) - a refinement over
the Boudewyn coefficients standard CBM/MSU use; the gap reads as GCBM vs FIA ground truth
(LIBCBM_CALIBRATION_DECISION_2026-06-14.md). Engine band = early (yr5) density gap; a 75-yr growth-
shape alternative was tried and RETRACTED (GCBM runs are only 5 yr; step-interval error;
ENGINE_GAP_ASSESSMENT_2026-06-14.md). Measured gaps integrated (6 states): ME +40, MN 0, WA -17,
IN -25, OR -27, GA -34 %. TWO HOUSEKEEPING FLAGS, assessed (CBM_FLAGS_RESOLVED_2026-06-14.md):
(1) re-point build_cbm_reserve.R explicitly at the libcbm 76-yr reserve run; (2) archive/label that
no-harvest run. Reserve confirmed no-harvest (+63% MN, not BAU +140%) so the overlay does not double-count.

GCBM (cbm_states): per-state chain port_new_state.sh; 6/48 spatial done (GA IN ME MN OR WA) with
mosaics + per-owner strata; libcbm reference for all 48. Finalization = run the remaining 42 (compute).
GCBM_STATE_PIPELINE_STATUS_2026-06-14.md.

PERSEUS: feed (1) state x scenario x model x year carbon+NPV matrix, plus (2) for spatial members the
per-owner stratum tables GCBM already emits (gcbm_state_per_owner.csv), at 10-YEAR steps (reserve is
near-linear; <0.1% reconstruction error), with stratum area. Native rasters archived for mapping.

LANDIS: 9-state per-plot integrated. 270m spatial-vs-plot ME deck fully reconstructed + verified (all
Biomass Succession 7.0 keywords, 101-240 ecoregion scheme, 80-ecoregion climate); ready to submit,
blocked only by the QOS limit behind the CEM array.

CEM: 37/48 native-2100; 15 relaunched (job 11555926, 48h wall). Re-adapt + overlap->9 when complete.

MONITOR: daily harmonized-carbon-monitor submits LANDIS, launches the GCBM port_new_state wave
(CA CO NM NV then OH NH), re-adapts CEM, refreshes ensemble/CI/inventory as QOS slots free.

NEW DOCS (docs/): MODEL_INVENTORY_AND_PERSEUS, GCBM_STATE_PIPELINE_STATUS, CBM_ENGINE_GAP_MEASURED,
LIBCBM_CALIBRATION_DECISION, ENGINE_GAP_ASSESSMENT, CBM_FLAGS_RESOLVED (all 2026-06-14) + team report.
NEW SCRIPTS (harmonized/): inventory_stress.R, resolution_strata_gcbm.R, gen_team_report.js.
