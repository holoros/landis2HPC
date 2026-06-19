# New-session handoff and resume prompt, 2026-06-19

Paste the block under "EXACT RESUME PROMPT" into a fresh conversation to pick up exactly here. The
narrative above it is the human summary; the prompt below is what a fresh Claude session needs.

## One-paragraph state

Harmonized five-model CONUS forest carbon assessment. Three-model backbone (FVS, yield curves, CBM)
complete for 48 states with ensemble, credible intervals, benchmark validation, clean stress test;
Zenodo v2.0.0 published (DOI 10.5281/zenodo.20693111). A bug in the calibrated FVS (per-species SDIMAX
keyword field-order, over-thinning TPH 25 to 35 percent) was found and fixed (WO-1 in config_loader.py).
The corrected projection path was established (the perseus driver via the FVS standalone-executable
subprocess path; the in-process fvs2py path is broken and off the critical path). The corrected base
CONUS FVS run (default + calibrated) is RUNNING now (job 11787944). CEM is at 47 of 48 (Georgia, job
11711470, about 2 days left). Per PI direction the FVS member expands to four arms: default, calibrated,
fvs-conus species-dependent (FVS engine + posterior draws + residual), fvs-conus species-free (new
standalone equation projector); both new arms carry parametric + residual uncertainty. Three scheduled
tasks carry the compute-gated work.

## Live jobs (2026-06-19)
- 11787944 conus_wo1: corrected base CONUS FVS (default+calibrated), 381 tasks %40, just started, 0/381
  outputs. Output /fs/scratch/PUOM0008/crsfaaron/fvs_stress/out_conus_wo1.
- 11711470 cem2100GA: CEM Georgia rerun, 47/48, ~1d22h left of 96h wall.
- Maine PERSEUS run (out_perseus_wo1) complete, not yet aggregated (watcher will).

## Scheduled tasks (watchers)
- harmonized-carbon-monitor (daily 7 AM): home hygiene, integrates campaigns, submits LANDIS/GCBM as QOS frees.
- cem-48-catch-and-integrate (every 6h): integrates CEM at 48, self-deletes.
- fvs-rerun-driver (every 2h): aggregates Maine, monitors the CONUS FVS array, builds the anchored
  per-state reserve on completion, flags the gompit/CONUS-variant and TreeMap steps.

## FVS four-arm design
1 default and 2 calibrated: running now (11787944).
3 fvs-conus species-DEPENDENT + uncertainty: CONUS-adapt perseus_uncertainty_projection.py (FVS engine,
  per-variant posterior draws from output/variants/<v>/*.rds) and add residual variance (point +/- residual
  SD) since parameter-only intervals undercover (~13 percent).
4 fvs-conus species-FREE + uncertainty: build a standalone projector adapting R/17_stand_projection_engine.R
  to the species-free fits (R/32_fit_dg_kuehne_speciesfree, 32_fit_hg_speciesfree_v5,
  34_fit_mortality/survival_speciesfree, 35_fit_cr_speciesfree, 36_fit_htdbh_speciesfree); first extract
  coefficients+residuals via R/50sf_extract_speciesfree_residuals.R. Validate equation forms against the
  fits and output/sf_bench before final numbers.
Mechanism hybrid; in-process FVS injection stays off the critical path. Then anchor all arms to FIA design
totals, map to TreeMap 2022 (FIA/treemap_paint.R), integrate as the FVS member family with bounds.

## Key paths
Repo (holoros/landis2HPC, pushed): docs/RESUME_PROMPT_2026-06-19.md (this), SESSION_HANDOFF_2026-06-19.md,
FVS_RERUN_STATUS_2026-06-19.md, CBM_REPOINT_RECOMMENDATION_2026-06-14.md; tooling in
harmonized/fvs_conus_setup/ (build_conus_plotlist.py, run_conus_task_wo1.py, submit_conus_wo1.slurm,
run_conus_perseus.py, submit_perseus_wo1.sh).
Cardinal: working perseus driver /users/PUOM0008/crsfaaron/fvs-conus/python/perseus_100yr_projection.py;
corrected CONUS runner /fs/scratch/PUOM0008/crsfaaron/fvs_stress/run_conus_task_wo1.py; CONUS plot lists
fvs_stress/conus_plotlist/; StandInit standinit_by_variant + manifest.tsv; TreeInit FIA_fresh/treeinit_h;
engine lib+exes /users/PUOM0008/crsfaaron/fvs-modern/lib; harmonized data+reserves /fs/scratch/PUOM0008/crsfaaron/FIA;
fvs-modern clone on conus-sf-integration-2026-05-21 (config pristine; pre-session WIP in stash@{0}).
Zenodo v2.0.0 DOI 10.5281/zenodo.20693111, concept 10.5281/zenodo.20516949.

## Non-blocking decisions for Aaron
Publish a corrected Zenodo version after FVS results shift; add the forestry community to the record;
route the CBM re-point recommendation to the build_cbm_reserve.R owner; validate arm-4 species-free
equation forms before final numbers.

---

## EXACT RESUME PROMPT (paste into a new session)

```
You are resuming the harmonized multi-model CONUS forest carbon assessment on OSC Cardinal (the CRSF
Maine-FOREST / PERSEUS project). Work folder is CRSF-Cowork; the repo is landis2HPC. Read
landis2HPC/docs/RESUME_PROMPT_2026-06-19.md, then SESSION_HANDOFF_2026-06-19.md and
FVS_RERUN_STATUS_2026-06-19.md for full context before acting. Be concise; no hyphens in prose; R-first,
Python where it wins; favor FIA / data-centric approaches.

ACCESS: SSH key is in the mounted .ssh-cardinal folder. Write a /tmp ssh config (IdentityFile=key, User
crsfaaron, HostName cardinal.osc.edu, StrictHostKeyChecking no, UserKnownHostsFile /dev/null) then
ssh -F cfg cardinal. Bash calls cap ~45s; for long ops use nohup+poll or sbatch and check back. Shared
transfers go via /fs/scratch, not /tmp (login-node-local). A QOS submit cap limits concurrent jobs;
check squeue depth before submitting and use array %throttle. Python on Cardinal needs PYTHONNOUSERSITE=1
(a user-site numpy 2.x otherwise breaks the module pandas). GitHub pushes go through the Cardinal clone
/users/PUOM0008/crsfaaron/repos/landis2HPC (git@github.com:holoros), not the local mount.

CURRENT STATE: The corrected base CONUS FVS run (default+calibrated) is running as SLURM array 11787944
(submit_conus_wo1.slurm, output fvs_stress/out_conus_wo1) via run_conus_task_wo1.py, which pairs the
FIADB FVS StandInit (standinit_by_variant + manifest.tsv) with the matched FVS TreeInit tables
(FIA_fresh/treeinit_h), imports the working fvs-conus perseus copy, and runs FVS through the standalone-
executable subprocess path with the WO-1 SDIMAX fix. CEM Georgia (job 11711470) is finishing the 48th
state. Three scheduled tasks run automatically: harmonized-carbon-monitor (daily), cem-48-catch-and-
integrate (6h), fvs-rerun-driver (2h, which aggregates and anchors the FVS run on completion).

DO, IN ORDER:
1. Check 11787944 and 11711470 (squeue, sacct, output counts). If FVS tasks FAILED, tail their .err in
   fvs_stress/conus_wo1_logs and fix; if a small fraction of stands per state match treeinit (about 32
   percent is expected and fine because the reserve anchors to FIA totals), flag any state with a tiny
   matched-plot count.
2. When 11787944 completes, let fvs-rerun-driver (or do it) concatenate fvs_stress/out_conus_wo1/conus_*_b*.csv,
   build the per-state per-ha reserve (Mg C/ha = AGB_TONS_AC*2.2417*0.5), anchor to FIA 2025 design totals
   (total(t)=FIA*perha(t)/perha(2025)) for default and calibrated, pull to repo results_snapshot/.
3. Build the two deeper fvs-conus arms (PI direction: hybrid mechanism, parametric+residual uncertainty):
   arm 3 species-dependent = CONUS-adapt perseus_uncertainty_projection.py (FVS engine + per-variant
   posterior draws from output/variants/<v>/*.rds) plus a residual-variance term; arm 4 species-free =
   new standalone projector adapted from R/17_stand_projection_engine.R fed by the species-free fits
   (extract coefficients+residuals via R/50sf_extract_speciesfree_residuals.R first), validated against
   output/sf_bench. Do NOT use the in-process fvs2py injection (set_tree_attr); it segfaults and is off
   the critical path.
4. Anchor all four arms to FIA totals, map to TreeMap 2022 via FIA/treemap_paint.R, integrate the FVS
   member family with bounds into build_crossmodel_ci.R + build_ensemble_estimate.R, re-stress, refresh
   the team report.
5. When CEM reaches 48 (cem-48 watcher handles it), do ONE clean final harmonized integration rather than
   integrating piecemeal.

CONSTRAINTS: never use Maine climate, growth curves, or the 58/59/82 ecoregion scheme for another state;
never relaunch a running or complete array; never launch at the QOS submit cap. Arm 4 is new modeling in
Aaron's fvs-conus domain; validate equation forms against his fits before generating final carbon numbers.

NON-BLOCKING, ASK AARON: publish a corrected Zenodo version once FVS results shift; add the forestry
community to record 20693111; route CBM_REPOINT_RECOMMENDATION_2026-06-14.md to the build_cbm_reserve.R
owner.
```
