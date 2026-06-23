# fvs-conus equation arms: status, mechanics, and wiring plan (2026-06-22)

The two deeper fvs-conus arms (species-dependent and species-free, with uncertainty) are produced by the
standalone equation projector in /fs/scratch/PUOM0008/crsfaaron/fvs_stress/conus_eq_proj, NOT by FVS
engine injection (the in-process fvs2py path stays blocked and is not used). This advances tasks #84/#85.

## Mechanics (verified 2026-06-22)
- Driver: conus_eq_projector_v3.R, run per (variant, mode) by conus_eq_v3_array.sbatch, manifest
  eq_manifest.tsv. Wires DG, mortality (logit or gompit), ht-dbh (Wykoff), CR recession, dynamic competition.
- MODES: --mode=free  -> CONFIG conus_b1 = species-FREE DG (W*gamma, trait-only).
         --mode=dependent -> CONFIG conus_b2 = species-DEPENDENT DG (v8 species-aware), uses b1_re_means.rds.
  So b1 = species-free arm, b2 = species-dependent arm. (gompit is the CONUS mortality variant.)
- Output per variant: out_conus_eq_v3/conus_eq_<var>_conus_b{1,2}_metrics.csv with columns
  STAND_CN, STATE, YEAR, PROJ_YEAR, VARIANT, CONFIG, AGB_TONS_AC, BA_FT2AC, QMD_IN, TPH, CCH_MEAN.
- AGB STEP (separate, required): the projector leaves AGB_TONS_AC blank; conus_eq_agb.py fills it using
  the real NSBECalculator with a single common DBH->HT->biomass mapping (AGB_HT_ANCHOR, tuned so the
  projector year-0 NE AGB matches the engine year-0 NE AGB) so all four arms are comparable. Run this on
  every completed metrics CSV before aggregating.

## Status (2026-06-22)
- conus_eq_v3 array (11913643): 15 small variants COMPLETE (b1+b2); the 5 big variants CR, CS, LS, NE, SN
  (both modes, 9 tasks) ran OUT OF MEMORY at 64G; 1 was still running.
- FIX APPLIED: relaunched those 9 indices at 192G as job 11944923 (array 8,9,11,18,19,22,23,26,27 %4).
  If any still OOM, go to a largemem node or add a stand-offset chunking arg to the projector (it currently
  takes --nstands as a count cap but no offset, so chunking needs a small projector edit).

## Wiring plan (when all variants done + AGB filled)
1. Run conus_eq_agb.py on every out_conus_eq_v3/conus_eq_<var>_conus_b{1,2}_metrics.csv to populate AGB.
2. Concatenate per mode: all-variant b1 (species-free) and all-variant b2 (species-dependent).
3. Aggregate to per-state per-ha mean AGB by YEAR x mode (Mg C/ha = AGB_TONS_AC * 2.2417 * 0.5), with the
   per-state matched-stand count; flag sparse states.
4. Anchor each to FIA 2025 design totals (total(t)=FIA*perha(t)/perha(2025)), writing
   FIA/fvs_conus_b1_reserve_anchored.csv (species-free) and FIA/fvs_conus_b2_reserve_anchored.csv
   (species-dependent), with default-arm equivalents if needed.
5. Uncertainty (PI direction: parametric + residual): draw posterior parameters (the projector fit
   objects / b1_re_means) and add the component residual SD per the validation_summary_*.csv, propagate to
   per-state percentiles.
6. Add both as fvs-conus arms in the FVS member family in build_crossmodel_ci.R + build_ensemble_estimate.R
   (extend the existing FVS family band, which currently holds default+calibrated, to default+calibrated+
   conus_b1+conus_b2). Re-stress and refresh the team report.
7. TreeMap 2022 allocation (FIA/treemap_paint.R) for the FVS family spatial layer.

## Not wireable yet
Do not wire until (a) all 19 variants have b1+b2 metrics and (b) conus_eq_agb.py has filled AGB. As of
2026-06-22 the big-variant relaunch (11944923) is in flight and AGB is unfilled, so the equation arms
cover only the 15 small variants without AGB. Wiring now would miss ~83 percent of CONUS stands.
