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

## What is needed from Aaron
Identify the single runtime-stable combination, since it spans the mid-refactor state:
1. Which branch or project state carries the Route A fvs2py segfault fix (4266a47 line) TOGETHER with the
   projection harness (the decoupled fvs-conus project) and the WO-1 config_loader guard. That is the
   state to build the engine from and run.
2. Where the decoupled standalone fvs-conus project lives (separate repo or path), since the run harness
   now imports from there rather than fvs-modern/calibration/python.
Once pointed at that combination, the rerun is mechanical: build engine, run the gompit projection
(PYTHONNOUSERSITE=1, the staged submit scripts), extract the corrected reserve, onboard ACD (ready), and
integrate. The SDIMAX bug fix and the numpy env fix are already done and carry over.

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
