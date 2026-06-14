# Session handoff 2026-06-14 (waiting on jobs)

Action-oriented handoff for resuming after the running jobs finish. For full project context read
START_HERE_HANDOFF.md (the 2026-06-14 consolidated section first). To resume, paste the resume line
at the top of START_HERE_HANDOFF.md into a new conversation.

## State in one paragraph
The harmonized five-model CONUS carbon assessment is in good shape. The three-model backbone (FVS,
yield curves, CBM, 48 states x 4 scenarios x 2 disturbance modes) is complete with ensemble, credible
intervals, geometric-mean and median central estimates, external benchmark validation, and a clean
stress test (zero anomalies). The libcbm calibration is finalized to FIA-expansion (data-centric,
the refinement over Boudewyn defaults); the measured GCBM-vs-libcbm engine gap is integrated for the
6 GCBM-complete states; the two CBM housekeeping flags are resolved (reserve is a no-disturbance
baseline; canonical reserve + engine gap archived to FIA/cbm_canonical/; adapter guarded against
silent truncation). The team report is written. Code + docs are committed and pushed to GitHub
(holoros/landis2HPC, commit 801ddb9). A Zenodo v2.0.0 package is staged and fire-ready.

## What is RUNNING (do not relaunch; QOS job-submit limit is the throttle)
- CEM 48-state native-2100 (job array 11555926, 48h wall): 38 of 48 states complete; 5 stragglers
  running, remainder pending. This is the gating job; it holds the QOS slots.

## Cardinal home disk (RESOLVED this session)
Home hit its 500G hard quota and was likely stalling the CEM stragglers. Fixed:
- Moved all completed-state CEM per_plot_projections.rds (115 files, ~108G; the 582M files the
  harmonized adapter never reads) to /fs/scratch/PUOM0008/crsfaaron/cem_per_plot_archive/. CEM output
  dropped 102G to ~24G; home now ~420G of real files, comfortably under quota.
- Key CEM info preserved at FIA/cem_ci_summaries_all.csv (consolidated reserve CI by cycle) and pulled
  to the repo results_snapshot/. The 2.0T FIA entry on home is a symlink to scratch (does not count).
- Refill prevention WIRED into the daily monitor: it now runs a home-hygiene step first each run,
  moving any newly completed state's per_plot to scratch and refreshing cem_ci_summaries_all.csv, so
  the 5 running jobs writing their per_plot files will not refill home.
- Other large home dirs (LSOG 120G, fvs-conus 119G, zenodo_staging 13G of already-published deposit
  copies) are separate projects; left untouched. zenodo_staging old copies are reversibly movable to
  scratch if Aaron wants the space back later.

## What to do WHEN EACH JOB LANDS (the monitor harmonized-carbon-monitor does this daily; verify)
1. CEM reaches 48 (count: ls -d fia_cem_projections/output/*conus2100*/ci_summaries.csv | wc -l):
   - Re-run build_cem_reserve.R (prefers conus2100 dirs) -> native-2100 48-state CEM reserve.
   - Refresh: apply_disturbance_overlay.R --reserve cem_reserve_anchored.csv, apply_harvest_scenarios.R,
     build_master_scenarios.R, build_ensemble_estimate.R, build_crossmodel_ci.R (auto-expands the
     full-overlap set from 4 toward 9), uncertainty_ensemble.R, inventory_stress.R, stress_test_harmonized.py.
   - Pull CSVs to repo; refresh FIA/_deliverables (organize_deliverables.sh).
2. LANDIS spatial 270m (submit run_me_spatial_101_240.sh when CEM frees slots): when
   states/ME/runs/maine_spatial_101_240/outputs/biomass/*.tif appear, summarize total biomass C and
   compare to the per-plot landis_ME_reserve (spatial-vs-plot structural check). The deck is complete
   and verified; only the QOS slot is needed.
3. GCBM expansion (cbm_states/port_new_state.sh): launch a wave one state at a time as slots free,
   western divergence states first (CA, CO, NM, NV), then eastern overlap (OH, NH). After each state's
   gcbm_state_aggregate lands, measure its engine gap from cross_state and update FIA/cbm_engine_gap.csv
   (FIA-expansion basis), then re-run build_crossmodel_ci.R + build_ensemble_estimate.R. libcbm
   reference already exists for all 48.

## Deferred items: now resolved
- ZENODO PUBLISH: DONE 2026-06-14. v2.0.0 published as a new version of concept 10.5281/zenodo.20516949,
  version DOI 10.5281/zenodo.20693111 (https://zenodo.org/record/20693111), 23 files, CC-BY-4.0, ORCID
  attached. The newversion draft inherited v1's files and the per-record file cap forced clearing them,
  so v2 contains exactly the 23 harmonized files (intended; v2 supersedes the v1 libcbm-vs-GCBM set).
  ONE NICETY OUTSTANDING: the "forestry" community add returned a Zenodo server-side 500 repeatedly and
  was skipped; add it later with one click on the record page (Communities > add). Does not affect the DOI.
- CBM ADAPTER RE-POINT: recommendation written for the CBM team at
  docs/CBM_REPOINT_RECOMMENDATION_2026-06-14.md (regenerate the libcbm 76yr no-disturbance FIA-expansion
  reserve, write to a stable path, re-point build_cbm_reserve.R, keep the <70-step guard, verify against
  the archived canonical). Execution is still a CBM-team task; the guard protects the pipeline meanwhile.
- GitHub push from the local mounted repo: a local commit (ebfd40a) also exists in the user's
  CRSF-Cowork/repos/landis2HPC; origin already has the content via the Cardinal push (801ddb9), so
  the local clone can simply be reset/pulled to origin/main next session if desired.

## Key artifacts (all on GitHub + Cardinal)
Docs (landis2HPC/docs/): Harmonized_Carbon_Team_Report_2026-06-14.docx, MODEL_INVENTORY_AND_PERSEUS,
LIBCBM_CALIBRATION_DECISION, CBM_ENGINE_GAP_MEASURED, ENGINE_GAP_ASSESSMENT, CBM_FLAGS_RESOLVED,
GCBM_STATE_PIPELINE_STATUS (all 2026-06-14), START_HERE_HANDOFF (consolidated).
Canonical data: FIA/cbm_canonical/ (no-dist 76yr reserve + FIA-expansion engine gap),
harmonized_best_estimate / _conus_by_scenario / _crossmodel_ci / _master_all_scenarios / _ensemble_geomean,
inv_*.csv, perseus_*.csv, gcbm_states_summary.csv.
Scripts (landis2HPC/harmonized/): inventory_stress.R, resolution_strata_gcbm.R, build_state_gcbm_stack.R,
build_inputs_state.sh, derive_state_mat.R, gcbm_me_spatial_summary.R, build_ensemble_geomean.R, gen_team_report.js.

## Monitoring while waiting
squeue -u crsfaaron (ignore v7_qrf, hg_v6, hcb_v6, cspi, lsog, zup, ingrowth). The daily monitor
harmonized-carbon-monitor (7 AM) integrates each campaign as it lands and keeps these docs current.
Nothing else is actionable until the CEM array frees QOS slots.
