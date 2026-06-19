# Calibrated FVS rerun: progress and the runtime blocker

2026-06-19. Status of the corrected calibrated-FVS rerun (the SDIMAX bug fix Aaron found). Solid
progress, then a hard blocker that needs Aaron's input. The rest of the assessment is unaffected.

## Confirmed and fixed
- The bug is real and pinned down. The per-species SDIMAX keyword in config_loader.generate_keywords()
  emitted fields in the wrong order (species index in field 1, which FVS reads as the max-SDI value),
  so FVS set max SDI near 1 for all species and over-thinned TPH by 25 to 35 percent across NE, LS, SN,
  CR. The calibrated FVS we used therefore under-counted carbon. Fix: WO-1 commit 21dfbae on
  feat/conus-sf-integration guards the emission behind _emit_sdimax (default off). This is a Python
  keyword-generation fix, independent of the compiled engine, so the corrected rerun does not need the
  WIP engine rewrites to apply it.
- numpy/pandas environment was broken by a user-site numpy 2.2.6 (installed for geopandas) shadowing the
  module numpy 1.x and breaking pandas. Fix: export PYTHONNOUSERSITE=1 in the submit scripts (uses the
  module numpy 1.26.4 + pandas 2.2.2). Added to the gompit submit scripts.
- Engine builds clean. Full rebuild of all 25 variant .so into fvs_gompit/lib_wo1 (FVSacd built; FVSadk
  skipped because adk is absent from the build script default variant list and its source list does not
  persist on feat). ACD standinit carved cleanly (ME 23, NH 33, VT 50 = 32,717 stands -> standinit_ACD.csv,
  VARIANT=ACD), manifest_acd.tsv and submit_conus_gompit_acd.slurm staged.

## The blocker: the projection harness segfaults the FVS call
Every projection task FAILS with a segmentation fault immediately after "Library loaded successfully",
on the first FVS call. Tested three ways, all identical SIGSEGV (exit 11):
1. feat engine (lib_wo1) + feat harness + GOMPIT on.
2. feat engine (lib_wo1) + feat harness + GOMPIT off (so not the calibration injection).
3. 05-21 stable engine (lib_0521, the branch that built the working v4 libs) + feat harness.

Because the known-good 05-21 engine also crashes under the current harness, the fault is NOT the engine
build. It is the projection harness on feat/conus-sf-integration (calibration/python/perseus_100yr_projection.py
plus the fvs2py ctypes binding) crashing the FVS call regardless of which engine .so it loads. The feat
branch has active "injection blocker" / fvs2py work in flight, which is the likely source.

The v4 run that worked (out_gompit_v4, last written 2026-06-11) used an older harness+engine state. Its
libraries are gone (fvs_gompit/lib is empty) and the commit live on 2026-06-11 is older than anything in
the current reflog window, so that exact working combination is not recoverable by branch switching alone.

## Root cause found (update)
The segfault is the known "extree / growth-step segfault" in the fvs2py tree read/write path. Aaron's
own fvs2py Route A work fixes it:
- 4266a47 (2026-06-18) "Route A milestone: fvsAddTrees in-memory load eliminates the extree segfault"
- c32d40c (2026-06-18) "Route A: rebuild fixes keyrdr EOF; in-process tree-attr verified; growth-step segfault isolated"
- 60960d6 (2026-06-18) "Route A: fvs2py in-process per-tree read/write (fvsTreeAttr binding)"

These commits are NEWER than feat/conus-sf-integration HEAD (21dfbae, 2026-06-16), which is what I built
and ran from. So feat does not contain the segfault fix, which is why every task crashed on the first
FVS call. Separately, commit b22be5d (2026-06-12) "Decouple calibration subtree into standalone fvs-conus
project" moved the projection harness (perseus_100yr_projection.py) out of fvs-modern into a standalone
fvs-conus project, so the harness on feat is the pre-decouple copy. The branch topology is mid-refactor:
the segfault fix and the decoupled harness are not co-located on a single branch I can simply build from.

## Final diagnosis (the precise blocker)
The Route A fvs2py fix (4266a47, on conus-sf-integration-2026-05-21) replaced the broken extree/treeinit
tree-loading path with an in-memory fvsAddTrees path. But the production CONUS projection driver on
scratch, /fs/scratch/PUOM0008/crsfaaron/fvs_stress/run_conus_task_fvstreeinit.py, still uses the OLD
treeinit path (its name says so). So even with the Route A fix present in fvs2py and the engine loaded,
the driver never calls the fixed code and segfaults on the first FVS call. Verified across four
combinations: feat engine, 05-21 engine, GOMPIT on, GOMPIT off, and 05-21 fvs2py with the fvs-conus
harness on PYTHONPATH. All segfault identically right after "Library loaded successfully".

fvs-conus (/users/PUOM0008/crsfaaron/fvs-conus) is the decoupled calibration + manuscript project; its
QUICKSTART covers fitting the Bayesian models, not the 100yr projection run, so the Route A projection
entry point is not wired up there yet.

## What is needed from Aaron
The projection driver must be the Route A version that calls the in-memory fvsAddTrees path, not the
stale run_conus_task_fvstreeinit.py. This is the in-progress Route A work. Specifically:
1. The Route A projection driver (the script that drives perseus_100yr_projection via fvsAddTrees), and
   how it is invoked for a CONUS array task. Once that driver exists/is identified, the staged submit
   scripts point at it instead of run_conus_task_fvstreeinit.py.
2. Confirmation of the three intended FVS runs and their engines: default, calibrated (gompit), and the
   new CONUS-variant via fvs-conus. Each runs through the same corrected driver, differing by config.
Once the Route A driver is in place, the rerun is mechanical: build engines, run the three projections
(PYTHONNOUSERSITE=1, staged submits), extract the three reserves, onboard ACD (ready) and ADK (needs a
county join), and do one final harmonized integration. The SDIMAX/WO-1 fix and the numpy env fix carry over.

## UPDATE 2026-06-19 (afternoon): projection path works; Maine run live; CONUS setup begun
The blocker was the wrong driver. The working path is the perseus_100yr_projection.py CLI (fvsAddTrees +
fvs.summary readback), NOT the stale scratch run_conus_task_fvstreeinit.py. With the WO-1 SDIMAX fix and
PYTHONNOUSERSITE=1, it runs clean.

DONE:
- Maine PERSEUS run launched and running: SLURM array 11787011 (37 tasks, ACD+NE x default+calibrated),
  output /fs/scratch/PUOM0008/crsfaaron/fvs_stress/out_perseus_wo1. Watcher fvs-rerun-driver aggregates
  and extracts on completion. These are the SDIMAX-corrected projections.
- CONUS plot list built from the FIADB FVS table ENTIRE_FVS_STANDINIT_PLOT.csv: 19 per-variant lists
  (1,861,183 plots) at fvs_stress/conus_plotlist/plotlist_<variant>.csv (PLOT, FIRST_PLTCN=STAND_CN,
  STATECD, FIRST_INVYR, lat/long). Builder: fvs_stress/build_conus_plotlist.py.
- CONUS runner wrapper: fvs_stress/run_conus_perseus.py wraps the working driver and loads FIA trees per
  STATECD (each <ST>_TREE.csv). Validated for SN: per-state load works and matching plots project
  correctly (AGB 0 -> 41.5 -> growing over cycles).

REMAINING for the full harmonized CONUS FVS member:
1. CN alignment: some StandInit STAND_CN do not match the current <ST>_TREE.csv PLT_CN (older cycles).
   Per Aaron, use the FIADB FVS tables: pair ENTIRE_FVS_STANDINIT with the matched FVS TreeInit tables
   (<ST>_FVS_TREEINIT_PLOT.csv) keyed by STAND_CN, instead of raw TREE.csv, so every stand has its trees.
2. Third config arm, the CONUS-variant via fvs-conus: the perseus driver supports only default and
   calibrated; the fvs-conus equations must be injected via set_tree_attr (stop at restart code 5,
   overwrite dg/htg with fvs-conus predictions, resume). The mechanism (set_tree_attr) exists in fvs2py
   _base.py; wiring fvs-conus coefficient predictions as a third config is the remaining dev step.
3. Launch the per-variant CONUS array (19 variants, ~375 chunks of 5000) through run_conus_perseus.py
   for default, calibrated, conus-variant, when QOS frees (Maine run + CEM GA currently hold slots).
4. Map to TreeMap 2022: allocate the per-plot reserve to TreeMap 2022 pixels via treemap_paint.R for
   spatial CONUS coverage, then anchor to FIA design totals and integrate as the corrected FVS member.

## Clone state left for Aaron (nothing lost)
fvs-modern Cardinal clone is on conus-sf-integration-2026-05-21, config_loader.py reverted to pristine.
stash@{0} ("WIP on feat/conus-sf-integration") holds uncommitted work that predated this session; restore
with git stash pop if it is yours. lib_0521 (SN, 05-21 engine) and lib_wo1 (all 25, feat engine) retained.

## State left in place (nothing destructive)
- lib_wo1 (feat engine, all 25 variants), lib_0521 (05-21 engine, SN only) retained.
- standinit_ACD.csv, manifest_acd.tsv, submit_conus_gompit_wo1.slurm, submit_conus_gompit_acd.slurm staged.
- The fvs-rerun-driver scheduled task is DISABLED (paused) so it does not relaunch a crashing projection.
- adk.json seeded from acd.json. ADK also needs a FIA COND county join to subset the NY Adirondacks
  (standinit has no usable county field), so ADK is a separate follow-on regardless.
- The fvs-modern Cardinal clone is on feat/conus-sf-integration with the WO-1 config_loader applied.

## Unaffected
CEM Georgia (job 11711470) is running normally (about halfway through its 96h wall). The three-model
backbone, CBM, yield curves, Zenodo v2.0.0, and the CEM 48-state integration path are all unaffected by
this FVS blocker.
