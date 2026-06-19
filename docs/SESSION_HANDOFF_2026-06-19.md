# Session handoff and plan, 2026-06-19

Authoritative handoff for the harmonized multi-model CONUS forest carbon assessment. Supersedes
SESSION_HANDOFF_2026-06-17.md. FVS rerun detail is in FVS_RERUN_STATUS_2026-06-19.md. Deep context in
START_HERE_HANDOFF.md.

## State in one paragraph

The harmonized five-model assessment is healthy. The three-model backbone (FVS, yield curves, CBM) is
complete for 48 states with ensemble, credible intervals, geometric-mean and median central estimates,
benchmark validation, and a clean stress test. Zenodo v2.0.0 is published. The major work this session
was the FVS rerun: a bug was found in the calibrated FVS (the per-species SDIMAX keyword emitted fields
in the wrong order, over-thinning TPH 25 to 35 percent and under-counting carbon), fixed by WO-1 in
config_loader.py. The corrected projection path was established (the perseus driver via the FVS
standalone-executable subprocess path, not the segfaulting fvs2py in-process path), validated, and the
Maine PERSEUS run completed. The full-CONUS FVS rerun is wired and staged: a corrected runner pairs the
FIADB FVS StandInit tables with the matched FVS TreeInit tables and runs default and calibrated arms; it
auto-launches when the executable rebuild finishes. CEM is at 47 of 48 (Georgia rerunning). Three
scheduled tasks carry the compute-gated work.

## Model status

FVS: bug fixed (WO-1). Corrected Maine run done. Full-CONUS corrected rerun wired and staged
(run_conus_task_wo1.py, 381-task submit), auto-launching via the fvs-rerun-driver watcher when the exe
rebuild completes. Default and calibrated arms validated; the gompit / CONUS-variant third arm and the
TreeMap 2022 allocation are documented follow-ons.

Yield curves: complete, 48 states, RCP plus simulation CI band. No open items.

CBM (libcbm 76yr, FIA-expansion): complete, 48 states. Reserve is a clean no-disturbance baseline.
Engine gap measured for 6 GCBM-complete states. Open reproducibility action (CBM team): re-point
build_cbm_reserve.R per CBM_REPOINT_RECOMMENDATION_2026-06-14.md; guard is in place meanwhile.

CEM: 47 of 48. Georgia rerunning (job 11711470, 96h wall, about 2 days left). The cem-48-catch-and-
integrate watcher fires the integration at 48 and self-deletes.

LANDIS-II: 7-state reserve set integrated. 270m Maine spatial deck complete; submits when QOS frees.
GCBM: 6 of 48 states with PERSEUS-ready per-owner strata; western wave runs via the daily monitor.

## What is running / staged

Running: CEM Georgia (11711470). The fvs-modern executable rebuild (login-node nohup, all 25 variants).
Unrelated: lsog jobs.

Staged, auto-launch: full-CONUS FVS rerun (fvs_stress/submit_conus_wo1.slurm, array 1-381) via
run_conus_task_wo1.py. The fvs-rerun-driver watcher launches it when the exe rebuild finishes and no
conus_wo1 array is queued, then monitors, concatenates, and builds the anchored per-state reserve.

## Refinements and watch items

1. Executable rebuild was redundant (the 25 exes already existed and worked); it is slow and is the only
   thing delaying the CONUS launch. If it stalls, the existing exes are fine to use; the watcher could be
   pointed to launch without waiting.
2. TreeInit match rate is about 32 percent of StandInit stands (varies by state; IL 2 of 9, the 50-stand
   test 16 of 50). This is acceptable because the reserve anchors to FIA design totals, so matched plots
   are a per-state sample for the trajectory shape. Refinement: in aggregation, flag any state with a
   small matched-plot count (noisy per-ha trajectory) and consider pooling to the variant or ecoregion
   level for those.
3. The gompit / CONUS-variant third arm runs run_conus_task_wo1 with GOMPIT_ARM=1, FVS_GOMPIT=1,
   FVS_GOMPIT_COEF=conus_mort/full_out/greg_mortality_coefficients.csv. The subprocess-path behavior of
   the gompit arm is not yet validated end to end; smoke-test one variant before the full pass.
4. Corrected FVS will raise the FVS member materially (the bug suppressed carbon). After the CONUS rerun
   and integration, deposit a corrected Zenodo version (v2.1.0 or v3.0.0) and refresh the team report.
5. ACD onboarding is ready (standinit_ACD carved, ME/NH/VT, 32,717 stands). ADK is blocked on a FIA COND
   county join to subset the NY Adirondacks; treat as a separate variant-development follow-on.
6. Do one final harmonized integration once CEM reaches 48 and the corrected FVS (all arms) is in, rather
   than integrating piecemeal.

## Automation in place

harmonized-carbon-monitor (daily 7 AM): home hygiene, integrates campaigns as they land, submits LANDIS
and GCBM as QOS frees.
cem-48-catch-and-integrate (every 6h): Georgia watcher; integrates CEM at 48, self-deletes.
fvs-rerun-driver (every 2h): aggregates the Maine run, launches the CONUS FVS array when exes are ready,
monitors, builds the anchored per-state reserve, flags the gompit arm and TreeMap allocation.

## Key paths

Repo (holoros/landis2HPC, pushed): docs/SESSION_HANDOFF_2026-06-19.md, FVS_RERUN_STATUS_2026-06-19.md,
CBM_REPOINT_RECOMMENDATION_2026-06-14.md, Harmonized_Carbon_Team_Report_2026-06-14.docx; tooling in
harmonized/fvs_conus_setup/ (build_conus_plotlist.py, run_conus_perseus.py, run_conus_task_wo1.py,
submit_conus_wo1.slurm, submit_perseus_wo1.sh); results in results_snapshot/.
Cardinal: working perseus driver /users/PUOM0008/crsfaaron/fvs-conus/python/perseus_100yr_projection.py;
corrected CONUS runner /fs/scratch/PUOM0008/crsfaaron/fvs_stress/run_conus_task_wo1.py; CONUS plot lists
fvs_stress/conus_plotlist/plotlist_<variant>.csv; StandInit standinit_by_variant; TreeInit
FIA_fresh/treeinit_h; engine lib + exes /users/PUOM0008/crsfaaron/fvs-modern/lib; harmonized data + FVS
reserves /fs/scratch/PUOM0008/crsfaaron/FIA; fvs-modern clone on conus-sf-integration-2026-05-21 (config
pristine; pre-session WIP in stash@{0}).
Zenodo: v2.0.0 DOI 10.5281/zenodo.20693111, concept 10.5281/zenodo.20516949.

## Open decisions for Aaron (non-blocking)

Publish a corrected Zenodo version after the FVS rerun changes results; add the forestry community to the
record. Confirm the gompit arm is the intended CONUS-variant or whether a deeper fvs-conus DG/HG injection
is wanted. Hand the CBM re-point recommendation to the build_cbm_reserve.R owner.

## Resume line

Read docs/SESSION_HANDOFF_2026-06-19.md, then check the fvs-modern exe rebuild and the fvs-rerun-driver
watcher (which auto-launches the CONUS FVS array), CEM Georgia (job 11711470), and the cem-48 watcher.
