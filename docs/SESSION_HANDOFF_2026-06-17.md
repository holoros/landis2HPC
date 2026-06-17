# Session handoff and plan, 2026-06-17

Authoritative handoff for the harmonized multi-model CONUS forest carbon assessment. Supersedes
SESSION_HANDOFF_2026-06-14.md (still accurate for the per-job integration detail). For deep project
context read START_HERE_HANDOFF.md first.

## State in one paragraph

The harmonized five-model CONUS carbon assessment is in good shape and close to a clean full-coverage
milestone. The three-model backbone (FVS, yield curves, CBM) is complete for 48 states across 4
scenarios and 2 disturbance modes, with ensemble, credible intervals, geometric-mean and median
central estimates, external benchmark validation, and a clean stress test. CEM is at 47 of 48 (Georgia
rerunning). The libcbm calibration is locked to FIA-expansion; the measured GCBM engine gap is folded
in for the 6 GCBM-complete states; both CBM provenance flags are resolved and the canonical artifacts
archived. Zenodo v2.0.0 is published. Two pieces of corrective work are now queued: the calibrated FVS
member must be regenerated after a bug fix Aaron is making in fvs-modern, and the CBM team should
re-point the reserve adapter at the libcbm 76yr run. The cleanest path is to let CEM finish Georgia and
the FVS fix land, then do one final integration rather than integrating piecemeal.

## Model status

FVS (calibrated, DG-adopted): complete for 48 states but carries a known bug. The current member is
fvs_reserve_calibrated_v4_anchored.csv. A full-CONUS rerun is queued and gated on Aaron's fvs-modern
fix (see the plan below).

Yield curves: complete, 48 states, re-anchored to the common harvest, with an RCP plus simulation CI
band. No open items.

CBM (libcbm 76yr, FIA-expansion): complete, 48 states, annual 2025 to 2100. Reserve is a clean
no-disturbance baseline (empty events). Engine gap measured on the FIA-expansion calibration for the 6
GCBM-complete states (GA, IN, ME, MN, OR, WA); the other 42 carry the regional median until their GCBM
runs land. One reproducibility action open: re-point build_cbm_reserve.R off the volatile spatial
aggregate (CBM-team, recommendation written; guard in place meanwhile).

CEM: 47 of 48 native-2100 states complete. Georgia timed out at the 48h array wall and is rerunning as
job 11711470 (96h wall, single job, per-plot writing disabled). When it lands, the count reaches 48 and
the catch-and-integrate task fires.

LANDIS-II: 7-state reserve set integrated. The 270m Maine spatial deck is complete and verified; the
spatial-vs-plot comparison submits when CEM frees QOS slots. Plains/Rockies extension-species scaffolds
authored. Further state waves run via the daily monitor.

GCBM (spatial): 6 of 48 states done (GA, IN, ME, MN, OR, WA) with per-owner strata that are
PERSEUS-ready. Western expansion wave (CA, CO, NM, NV, then OH, NH) runs via the monitor as slots free,
each with its own measured engine gap. libcbm reference exists for all 48.

## What is running and what is gated

Running now: CEM Georgia rerun (job 11711470, up to 96h). Nothing else of ours is in the queue beyond
unrelated jobs (v7_qrf).

Gated on compute (handled by the daily monitor as QOS slots free): CEM 48-state integration, LANDIS
270m Maine spatial submit, GCBM western wave.

Gated on Aaron: the calibrated FVS rerun (waiting on the fvs-modern bug fix). Open question when it is
ready: which layer is the bug in (Fortran engine vs calibration params vs the extraction adapter), and
how I will know it is committed (a tag, a branch, or you tell me). That sets both cost and trigger.

Gated on the CBM team: re-pointing build_cbm_reserve.R per docs/CBM_REPOINT_RECOMMENDATION_2026-06-14.md.

Decision deferred (non-blocking): add the forestry community to the Zenodo record (one click on the
record page; the API add kept returning a server-side 500). If the corrected FVS shifts results
materially, deposit a corrected Zenodo version.

## The plan (sequenced)

Step 1, now to a few days: finish CEM. Georgia (job 11711470) runs to completion. The
cem-48-catch-and-integrate task checks every 6 hours, keeps home clean, and at 48 of 48 runs the CEM
reserve build and the full integration chain, pushes results, then self-deletes. No action needed
unless Georgia fails again, in which case the task surfaces its log.

Step 2, on Aaron's signal: rerun calibrated FVS, full CONUS. When the fvs-modern fix is committed,
confirm the bug layer, then on the Cardinal clone (/users/PUOM0008/crsfaaron/fvs-modern, branch
conus-sf-integration-2026-05-21) git pull, rebuild the .so libraries if the engine changed
(bash deployment/scripts/build_fvs_libraries.sh src-converted ./lib), rerun the full-CONUS calibrated
(gompit) projection to regenerate fvs_stress/out_gompit_v3, then re-extract the reserves via
run_fvs4.sh (build_fvs_reserve_cfg.R --config gompit -> fvs_reserve_calibrated_anchored.csv, plus the
v4 DG-adopted extraction and the TreeMap variant) and refresh fvs_posterior_ci_all.csv. Respect the
QOS submit cap; do not launch the array while Georgia or other jobs sit near the limit.

Step 3, once CEM is at 48 and corrected FVS is in: one clean final integration. Run
apply_disturbance_overlay.R, apply_harvest_scenarios.R, build_master_scenarios.R,
build_ensemble_estimate.R, build_crossmodel_ci.R (auto-expands the full-overlap set from 4 toward 9),
uncertainty_ensemble.R, inventory_stress.R, stress_test_harmonized.py. Validate against the
default-vs-calibrated 2100 reserve sanity table in run_fvs4.sh (WA OR MN ME GA AL CA), the external
benchmark check, and a clean stress test (target 0 anomalies). Regenerate the team report. Pull all
CSVs and figures to the repo, run organize_deliverables.sh, commit and push.

Step 4, expansion as slots free (monitor-owned, lower priority than the corrective work): LANDIS 270m
Maine spatial run and spatial-vs-plot extract; GCBM western states with per-state engine-gap
measurement folded back into build_crossmodel_ci.R and build_ensemble_estimate.R.

Step 5, publication and reproducibility: if corrected FVS shifts results materially, deposit a corrected
Zenodo version (v2.1.0 or v3.0.0) referencing the fix; add the forestry community to the record. Hand
the CBM re-point recommendation to whoever owns build_cbm_reserve.R so the pipeline reproduces from
source rather than a frozen CSV.

## Automation in place

harmonized-carbon-monitor (daily 7 AM): home hygiene first, then integrates each campaign as it lands
and submits LANDIS and GCBM as QOS slots free. Keeps the docs current.

cem-48-catch-and-integrate (every 6 hours): the tight-cadence Georgia watcher. Counts unique completed
states, archives per-plot files to scratch, and at 48 runs the integration and self-deletes. Knows
Georgia is job 11711470 and will surface its log if it fails rather than running long.

## Key paths and artifacts

Repo (holoros/landis2HPC, pushed): docs/SESSION_HANDOFF_2026-06-17.md (this file),
CBM_REPOINT_RECOMMENDATION_2026-06-14.md, Harmonized_Carbon_Team_Report_2026-06-14.docx,
MODEL_INVENTORY_AND_PERSEUS, LIBCBM_CALIBRATION_DECISION, CBM_ENGINE_GAP_MEASURED,
ENGINE_GAP_ASSESSMENT, CBM_FLAGS_RESOLVED, GCBM_STATE_PIPELINE_STATUS (all 2026-06-14),
START_HERE_HANDOFF (consolidated). Scripts in landis2HPC/harmonized/ and results in results_snapshot/.

Cardinal: harmonized scripts at /fs/scratch/PUOM0008/crsfaaron/landis2/harmonized; harmonized data and
reserves at /fs/scratch/PUOM0008/crsfaaron/FIA (cem_reserve_anchored.csv,
fvs_reserve_calibrated_v4_anchored.csv, harmonized_crossmodel_ci.csv, harmonized_ensemble_geomean.csv,
cbm_canonical/, cem_ci_summaries_all.csv). FVS clone at /users/PUOM0008/crsfaaron/fvs-modern. CEM at
/users/PUOM0008/crsfaaron/fia_cem_projections (GA rerun: submit_cem_GA_relaunch.slurm). Repo clone with
GitHub auth at /users/PUOM0008/crsfaaron/repos/landis2HPC.

Zenodo: v2.0.0 published, version DOI 10.5281/zenodo.20693111, concept 10.5281/zenodo.20516949.

## Resume line

To resume in a new conversation: read docs/SESSION_HANDOFF_2026-06-17.md, then check CEM Georgia
(job 11711470) and the cem-48-catch-and-integrate task. The next decision point is Aaron signaling the
fvs-modern fix is committed.
