# CONUS multi-model forest carbon assessment: project map

Single entry point for the project. The repo is named landis2HPC for historical reasons but the work is
a five-plus-model CONUS harmonized carbon assessment feeding the PERSEUS decision-support tool. To resume
a session, use docs/RESUME_PROMPT_2026-06-19.md. For full status, docs/SESSION_HANDOFF_2026-06-19.md.

## What this is

Six modeling families (FVS, yield curves, CBM, CEM, LANDIS-II, GCBM) run on one common pipeline anchored
to FIA 2025, four harvest scenarios (reserve, conservation, BAU, intensive), common HCS harvest, first-
order IPCC Tier-2 HWP, with a disturbance overlay and a weighted ensemble with credible intervals. Model
structure is the only difference; uncertainty is quantified.

## Unified output tree (new, 2026-06-19)

All model outputs are now reachable under one per-model tree on Cardinal (symlinks, nothing was moved):

    /fs/scratch/PUOM0008/crsfaaron/conus_multimodel/
      fvs/           reserves fvs_reserve_*.csv + runs_conus, runs_maine_perseus
      yield_curves/  yc_reserve_anchored.csv, yc_bands.csv
      cbm/           cbm_reserve_*.csv, cbm_engine_gap.csv, canonical/
      cem/           cem_reserve_*.csv, cem_ci_summaries_all.csv, runs/
      landis/        landis_*state_reserve.csv, states/
      gcbm/          gcbm_*.csv, states/ (per-state spatial)
      harmonized/    harmonized_*.csv, inv_*.csv, perseus_*.csv, scripts/

The authoritative reserves still physically live in /fs/scratch/PUOM0008/crsfaaron/FIA; the tree above is
the organized view. Adopt this tree as the canonical convention going forward (see Next steps).

## Per-model status and outputs

FVS: bug fixed (WO-1 SDIMAX). Base CONUS run (default+calibrated) RUNNING (job 11787944). Expanding to four
arms (default, calibrated, fvs-conus species-dependent, fvs-conus species-free; last two with parametric+
residual uncertainty). Output conus_multimodel/fvs/. Runner run_conus_task_wo1.py.

Yield curves: complete, 48 states, RCP+simulation CI band. Output conus_multimodel/yield_curves/.

CBM (libcbm 76yr, FIA-expansion): complete, 48 states, clean no-disturbance baseline; engine gap measured
for 6 GCBM states. Output conus_multimodel/cbm/. Open: re-point build_cbm_reserve.R (CBM team).

CEM: 47 of 48; Georgia rerunning (job 11711470). Output conus_multimodel/cem/. cem-48 watcher integrates at 48.

LANDIS-II: 7-state reserve integrated; 270m Maine spatial deck ready. Output conus_multimodel/landis/.

GCBM (spatial): 6 of 48 states with per-owner strata. Output conus_multimodel/gcbm/. Western wave via monitor.

Harmonized layer: ensemble, crossmodel CI, geomean+median central estimates, stress test, PERSEUS strata.
Output conus_multimodel/harmonized/. Scripts harmonized/ (repo) and landis2/harmonized (Cardinal).

## Automation
harmonized-carbon-monitor (daily), cem-48-catch-and-integrate (6h), fvs-rerun-driver (2h). See the handoff.

## Repo layout
PROJECT_MAP.md (this), docs/ (handoffs, resume prompt, decision docs), harmonized/ (integration scripts +
fvs_conus_setup/ tooling + results_snapshot/). Zenodo v2.0.0 DOI 10.5281/zenodo.20693111.

## Next steps and suggested refinements

Science (status as of 2026-06-21 review):
1. DONE: base CONUS FVS run complete (26.6M rows, all 19 variants); corrected reserve anchored
   (fvs_reserve_{calibrated,default}_wo1_anchored.csv, 06-20) and folded into the crossmodel CI as the FVS
   family band (arms+anchor). Corrected calibrated is at parity with default (calib/def ~0.99), confirming
   the SDIMAX over-thinning artifact is gone. Old buggy reserves backed up .bak_pre_wo1.
2. DONE: CEM reached 48 states (Georgia finished). BUT the harmonized CEM member is STALE: cem_reserve_anchored.csv
   is still 06-13 (pre-48). IMMEDIATE NEXT STEP: rebuild build_cem_reserve.R from the 48 conus2100 dirs, then
   re-run the integration chain (apply_disturbance_overlay, apply_harvest_scenarios, build_master_scenarios,
   build_ensemble_estimate, build_crossmodel_ci, uncertainty_ensemble, inventory_stress, stress_test) so the
   CEM member is current. This is the one clean final integration; the cem-48-catch-and-integrate watcher is
   meant to do it on its 6h cadence (verify it fired; trigger if not).
3. Then build the two deeper fvs-conus arms (#84 species-dependent, #85 species-free) with parametric+residual
   uncertainty, TreeMap 2022 allocation for the FVS family, and re-integrate.
4. Deposit a corrected Zenodo version once results are final; refresh the team report.
5. Flag any state with a small FVS treeinit-matched sample (n_matched in the anchored reserve); pool to
   variant/ecoregion if noisy.

Infra: home recovered to 257G (LSOG jobs finished); keep LSOG output pointed at scratch to avoid refilling.

Organization (to make handoffs easier; do the disruptive parts at a quiet milestone, not mid-run):
5. Adopt conus_multimodel/<model>/ as the canonical output convention; point new runs there (or symlink on
   completion). Once the running FVS array and watchers finish, physically move (not symlink) outputs in.
6. Consolidate the dated handoffs (SESSION_HANDOFF_2026-06-14/-17/-19, FVS_RERUN_STATUS, RESUME_PROMPT) into
   one living handoff plus an archive/ folder, so there is a single current source.
7. Restructure the repo into models/{fvs,landis,cbm,cem,yield_curves,gcbm}/ + harmonized/ + docs/, and
   consider renaming holoros/landis2HPC to conus-multimodel-carbon. This updates the Cardinal clone, the
   watcher push target, and the github-manager skill, so schedule it when no array is mid-run.
