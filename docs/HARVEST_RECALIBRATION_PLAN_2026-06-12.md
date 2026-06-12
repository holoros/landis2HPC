# Consistent CONUS harvest recalibration plan

Date 2026-06-12. Decision (Aaron): recalibrate the whole HCS common harvest layer to a survey/NFI
benchmark so all 48 states are treated alike, rather than patching MN alone. Triggered by the Nash and
Domke 2026 cross check (HWP_BENCHMARK_NASH_DOMKE_2026-06-12.md), which showed our TM2016 derived HCS
under detects MN harvest ~3x and the layer is inconsistent state to state.

## Why recalibrate

The HCS rate (hcs_harvest_rate_by_state.csv) is the single common harvest applied to every model's
reserve in apply_harvest_scenarios.R. It is derived from a TM2016 disturbance product that under detects
removals (documented for the West; the Nash check exposed MN in the East). Examples of the implausible
spread: on comparable forest area MN harvests 23,578 ha/yr vs MI 144,476 and WI 218,244. A consistent
calibration to an independent FIA NFI removal benchmark fixes the whole layer, not just the worst outlier.

## Method (matches the Nash and Domke base step)

Benchmark = FIA NFI annual removal rate per state, from rFIA::growMort on the staged FIADB. REMV_PERC is
the annual removal as a percent of standing aboveground biomass, the empirical analogue of our effective
rate h*f (h = HCS area rate, f = BAU removal fraction). Calibrating on the RATE is unit clean and
independent of the carbon fraction. Optional later layer: scale the NFI benchmark up to WOODCARBII /
survey (Nash's regression step, R2 = 0.92), since NFI itself runs below survey harvest.

## Stage 1 (RUNNING): build the NFI benchmark

- Script: fia_nfi_removal_benchmark.R (downloads only the missing TREE_GRM_BEGIN per state, read local
  first; runs growMort stateVar=BIO_AG; writes nfi_benchmark/nfi_removal_<ST>.csv with REMV_PERC).
- Job: SLURM array 11513714, 48 states, on Cardinal. Output dir
  /fs/scratch/PUOM0008/crsfaaron/FIA/nfi_benchmark/.
- VALIDATE FIRST when it lands: confirm a sane REMV_PERC for ME/MN/MI/WI before trusting all 48 (the
  inline test confirmed the download path but timed out before growMort finished).

## Stage 2 (pending Stage 1): calibrate the HCS layer

- Compare per state: our effective rate h*f vs FIA REMV_PERC. Derive a per state factor
  cal = REMV_PERC / (h*f). Apply to h to produce hcs_harvest_rate_by_state_calibrated.csv (back up the
  original; scale clearcut_ha_yr / partial_ha_yr / total_ha_yr proportionally; keep clearcut_frac).
- Sanity check the calibrated MI/MN/WI removals against Nash 2024 (MI 3.0, MN 2.0, WI 3.4 MMT C merch
  bole). Expected: MN rises ~4 to 5x, MI/WI move toward Nash.

## Stage 3 (pending Stage 2): rebuild and document

- Re-run apply_harvest_scenarios.R for each model x disturbance mode with the calibrated HCS to
  regenerate harmonized_carbon_npv_<MODEL>(_dist).csv. Then build_master_scenarios.R,
  build_ensemble_estimate.R, build_crossmodel_ci.R, uncertainty_ensemble.R.
- Keep the pre calibration canonical outputs backed up; write the recalibrated set alongside, diff the
  headline CONUS scenario totals (forest / hwp / total at 2100), and document old vs new before promoting.
- Re run stress_test_harmonized.py (0 failures = pass).

## Companion refinement (recommendation 3)

Adopt species specific carbon fractions (Westfall 2024) in place of the lumped CFRAC = 0.5 in
apply_harvest_scenarios.R (NPV) and the HWP accounting. Scope: the species fractions are not yet staged;
source from rFIA REF_SPECIES (CARBON_RATIO_LIVE) or Westfall 2024. Folds in with the Stage 3 rebuild.

## Stage 1 + 2 results (2026-06-12, COMPLETE)

Stage 1 (job 11513714) produced FIA NFI REMV_PERC for 46 of 48 states (ID and WY tasks failed, a vctrs
subscript error; rerun before Stage 3). Stage 2 (build_hcs_calibration.R) calibrated the HCS layer to the
benchmark: hcs_harvest_rate_by_state_calibrated.csv + hcs_calibration_comparison.csv. Original HCS backed
up (*.bak.precal_20260612). Nothing headline was overwritten.

Headline finding: the TM2016 derived HCS broadly UNDER detected harvest, in both regions.
- West near zero: OR was 0.003 %/yr vs FIA 1.058 (factor 526x); CA 286x; WA 150x; AZ, CO, NM were
  literally 0 and are now set from FIA. This is the documented western TM2016 failure, quantified, and it
  fixes the OR benchmark concern in the handoff.
- East under detected severalfold: ME 39x, VA 18x, NH 13x, PA 7.5x, MN 4.0x, and so on (partial harvest /
  thinning under detection).
- A minority were over detected and scale DOWN: IA 0.15x, TN 0.45x, WI 0.51x, GA 0.71x, MI 0.82x, FL/ND/IL
  ~0.9x.
Net effect: calibrated effective removal rates cluster near the empirical ~0.1 to 3.4 %/yr by state
instead of the implausible 0 to 3.6 %/yr TM2016 spread. MN was not special; the whole layer was off, which
is why the consistent recalibration is the right call. The reserve (no harvest) backbone is unaffected;
only the harvest scenarios shift (forest down, HWP up, most states).

## Stage 3 results (2026-06-12, rebuilt NON DESTRUCTIVELY in FIA/recal/)

run_recal_rebuild.sh (job 11514074) re-ran apply_harvest_scenarios.R for all 6 models x 2 disturbance
modes with the calibrated HCS, then rebuilt master/ensemble/conus into FIA/recal/. Canonical files were
NOT touched. A verification gate ran first: it reproduced the canonical CBM npv with the ORIGINAL HCS and
asserted an exact match before proceeding (VERIFY OK), so the rebuild chain is faithful. Internal check:
the reserve scenario (zero harvest) is byte identical old vs new, as it must be.

CONUS 2100 ensemble median, Tg C (full coverage models FVS_cal + YC + CBM):

| Scenario     | nodisturb orig | nodisturb cal | change | disturbed orig | disturbed cal | change |
|--------------|----------------|---------------|--------|----------------|---------------|--------|
| reserve      | 24,294         | 24,294        | 0%     | 23,074         | 23,074        | 0%     |
| conservation | 22,261         | 20,230        | -9.1%  | 21,061         | 19,085        | -9.4%  |
| BAU          | 20,218         | 16,040        | -20.7% | 19,040         | 14,985        | -21.3% |
| intensive    | 17,860         | 11,260        | -37.0% | 16,714         | 10,354        | -38.0% |

Interpretation: with realistic FIA benchmarked harvest (mostly higher than the TM2016 layer), the harvest
scenarios draw down more standing carbon, so managed scenario totals fall and the effect scales with
intensity. The reserve backbone is unchanged. Net: our prior assessment OVER stated retained carbon under
management because the common harvest was under detected. HWP rises (more harvest) but the forest drawdown
dominates the total.

Outputs in FIA/recal/: harmonized_carbon_npv_<MODEL>(_dist).csv, harmonized_master_all_scenarios.csv,
harmonized_ensemble_by_scenario.csv, harmonized_conus_by_scenario.csv. Local copies of the CONUS diff are
in harmonized/ (harmonized_conus_by_scenario_{original,calibrated}.csv).

## Recommendation 3 (Westfall species carbon fractions): mostly N/A for carbon

CFRAC = 0.5 in apply_harvest_scenarios.R is used ONLY in the timber NPV revenue term (rem/CFRAC*MERCH*...),
to convert carbon removal back to volume for dollars. The carbon accounting itself uses FIA anchored live
AGC, which already carries species specific carbon (the FIA CRM / Westfall fractions are in the anchor). So
species specific carbon fractions would refine only the NPV dollar term, not the carbon numbers. Low
priority; note in methods.

## PROMOTED to canonical (2026-06-12)

The NFI calibrated set was promoted over the canonical headline + npv files. Pre calibration canonical
(22 files) + the original HCS are backed up in FIA/precal_backup_20260612 (fully reversible). The
calibrated HCS is now the active hcs_harvest_rate_by_state.csv. Downstream rebuilt: build_ensemble_estimate,
build_crossmodel_ci (14 of 15 model pairs still distinguishable), uncertainty_ensemble. stress_test_
harmonized.py PASSES (0 hard failures, 0 warnings). Reserve backbone unchanged.

## WOODCARBII survey upscaling (sensitivity, FIA/recal_survey/)

A full per state WOODCARBII layer needs the EPA WOODCARBII state harvest series (appendix A-198) or FIA TPO
database queries, neither staged on Cardinal (only legacy state TPO reports exist). As a defensible
sensitivity, the NFI to survey gap was anchored to Nash's NLS numbers (already WOODCARBII scaled, merch
bole): our NFI merch bole equivalent for MI/MN/WI = 7.29 vs Nash 8.40 MMT C, a factor of 1.152. Applying
1.152 CONUS wide as an illustrative upper harvest case (caveat: the gap is regional, this is a uniform
scalar) gives:

CONUS 2100 ensemble median, Tg C, nodisturb: original 24,294 / 22,261 / 20,218 / 17,860 ->
NFI calibrated 24,294 / 20,230 / 16,040 / 11,260 -> survey +15% 24,294 / 19,730 / 15,293 / 10,553
(reserve / conservation / BAU / intensive).

Read: the TM2016 to NFI correction dominates (BAU -21%); the NFI to survey term is a smaller additional
reduction (BAU a further -4.7%). The survey case is a sensitivity bracket, not promoted. A full per state
WOODCARBII layer remains the documented next step if the EPA/TPO series is obtained.

## ID/WY resolved (2026-06-12)

The ID/WY growMort failure was a corrupted local table: ID_COND.csv had been reduced to 14 columns (vs the
full 153) by an earlier subset save, dropping CONDPROP_UNADJ. Re-downloaded the full COND and reran: ID FIA
REMV = 0.428 %/yr (it was 0.028 in the TM2016 layer, a ~19x under detection; Idaho is a real timber state).
ID folded into the calibration (new HCS rate 0.543 %/yr) and canonical refreshed (job 11514355, stress test
passes). WY genuinely has NO FIA removal evaluation (growMort: "WY doesn't include REMV"), so its near zero
rate is kept and documented; negligible CONUS impact. Recalibration now covers all 48 states (47 from the
FIA REMV benchmark, WY documented as no eval).

Final canonical CONUS 2100 ensemble median (Tg C), after the ID fix: nodisturb reserve 24,294 /
conservation 20,188 / BAU 15,929 / intensive 11,056; disturbed 23,074 / 19,049 / 14,888 / 10,177.

## Full per state WOODCARBII/TPO layer: data not programmatically obtainable here

FIA TPO is served only through the interactive TPO Reporting Tool / NRUM Toolkit (point and click per state
or county); there is no clean bulk CSV download, and the EPA WOODCARBII state series is not staged. So a full
per state survey layer cannot be pulled automatically in this environment. The implemented base IS the survey
consistent method (the FIA NFI removal benchmark is exactly Nash and Domke's base step), and the residual NFI
to survey gap is bracketed by the 1.152 sensitivity (recal_survey/). Obtaining the per state EPA/TPO series
via the interactive tool remains the documented next step for anyone who wants to replace the uniform scalar.

## Status

COMPLETE for all 48 states. NFI recalibration promoted to canonical (reversible via precal_backup_20260612),
ID fixed, CI + uncertainty rebuilt, stress test passes (0 failures). Survey upscaling delivered as a
sensitivity bracket. Full per state WOODCARBII layer is blocked on interactive only TPO data, documented.
