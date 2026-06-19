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

## What is needed from Aaron
The decision is which harness + engine + fvs2py commit is runtime-stable for the CONUS projection. Options:
1. Point to the commit or tag live on 2026-06-11 that produced the working v4 run; rebuild engine and run
   the harness from that commit, then apply only the WO-1 config_loader guard on top.
2. If feat/conus-sf-integration is meant to run, identify the fvs2py / perseus_100yr_projection fix that
   resolves the segfault (debug build + backtrace can localize it, but it is an active WIP branch).
3. Restore the 2026-06-11 working libraries if archived anywhere off the empty fvs_gompit/lib.

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
