# Corrected base CONUS FVS reserve (SDIMAX WO-1): run report

2026-06-20. Autonomous OODA run. Modes: autonomous, full, R with data.table. This run closed out the
base CONUS FVS member (arms 1 and 2) of the harmonized multi model carbon assessment: it confirmed the
corrected array completed, aggregated the per stand output, anchored it to FIA design totals for both
configs, and staged the products. Arms 3 and 4 (stand level fvs-conus projections) and the final
harmonized integration remain compute gated and CEM gated and are queued, not done, by design.

## OBSERVE

SLURM array 11787944 (submit_conus_wo1.slurm, run_conus_task_wo1.py) finished: 380 of 381 tasks
COMPLETED, exit 0. The single FAILED id (381) is benign, the runner logged "task 381 not in manifest.tsv"
because the manifest holds 380 real tasks and the array index ran one past it. All 381 output CSV are on
scratch at fvs_stress/out_conus_wo1/conus_<variant>_b<batch>.csv with columns
STAND_CN, STATE, YEAR, PROJ_YEAR, VARIANT, CONFIG, AGB_TONS_AC. Total 26,600,402 rows across both configs.
CEM Georgia (job 11711470) is still RUNNING at about 2 days 19 hours of its 96 hour wall, so 47 of 48
states; the cem-48 watcher will trigger integration when it lands.

Per variant matched stand counts (StandInit stands that paired to a TreeInit tree list and projected):

| metric | value |
|---|---|
| StandInit stands in | 1,861,183 |
| stands with trees | 753,579 |
| stands projected | 748,004 |
| CONUS match rate | 40.5 percent |

Match rate sits in the expected band (about 32 to 40 percent). The reserve anchors to FIA design totals,
so matched plots supply only the trajectory shape, not the level. Lowest per state matched counts are
RI 654, DE 730, ND 1,207, all far above any noise threshold, so no per state pooling to variant or
ecoregion was needed. Lowest per variant match rates were EM 8.1 percent, CR 16.6 percent, CS 19.6
percent, still thousands of matched stands each.

## ORIENT

The known vulnerability was the per species SDIMAX keyword field order bug (WO-1), which set max SDI near
1 and over thinned TPH 25 to 35 percent, suppressing carbon. The corrected run uses the WO-1 fix and the
perseus standalone executable subprocess path (the segfaulting in process fvs2py path stays off the
critical path). The remaining analysis risk is the no disturbance reserve growing without bound; this is
handled downstream by anchoring to FIA totals and by integrating the FVS member with bounds, not by
trusting the raw 2100 level.

## DECIDE

Aggregate per stand AGB to a per state per ha trajectory and anchor to FIA design totals, for both default
and calibrated, reusing the validated v4 anchoring math:

```
Mg C per ha = AGB_TONS_AC * 2.2417 * 0.5
total(t)    = FIA_total * mean_perha(t) / mean_perha(2025)
```

Targets 2025, 2050, 2075, 2100; per ha trajectory interpolated with rule 2; standard error carried from
the FIA design CV. Seed 42. The production script is build_fvs_reserve_wo1.R (data.table, fault tolerant
reads, both configs in one pass, plus a per state matched stand diagnostic).

## ACT: results

CONUS aboveground live carbon, no disturbance reserve, FIA anchored (Tg C):

| arm | 2025 | 2050 | 2075 | 2100 |
|---|---|---|---|---|
| default (WO-1 corrected) | 15,279 | 26,523 | 35,091 | 40,137 |
| calibrated (WO-1 corrected) | 15,279 | 26,489 | 35,034 | 40,085 |
| calibrated (buggy v4, prior) | 15,279 | n/a | n/a | 32,207 |

The WO-1 fix raises the 2100 reserve from 32,207 to 40,085 Tg C, plus 7,878 Tg C or about 24.5 percent,
exactly the direction predicted (the bug suppressed carbon). Default and calibrated are nearly identical
(40,137 vs 40,085 at 2100), consistent with the prior finding that the calibration multipliers net near
zero at stand level. See fig_fvs_wo1_conus_trajectory.png.

## Independent validation already in hand (component level)

The four arm diameter increment comparison (Phase 1, county blocked held out, about 172k trees) is
complete and validates the equation forms that arms 3 and 4 will use at the stand level:

| arm | n | bias (in/yr) | RMSE (in/yr) |
|---|---|---|---|
| fvs-modern default (Wykoff) | 172,165 | -0.068 | 0.269 |
| fvs-modern calibrated | 172,654 | -0.082 | 0.134 |
| fvs-conus species dependent (b2) | 167,653 | -0.021 | 0.090 |
| fvs-conus species free (b1) | 166,178 | -0.025 | 0.098 |

The fvs-conus equations beat the engine; species free is competitive with species dependent (within 5
percent RMSE in 55 percent of strata, strictly better in 21 percent). This is the equation form
validation the constraint requires before generating arm 3 and 4 carbon numbers.

## What remains (compute gated, queued not done)

Arms 3 and 4 at the stand level are the long pole. The perseus drivers expose only default and calibrated
config switches; they have no species mode toggle and no fvs-conus equation projection path, so arms 3
(species dependent, FVS engine plus posterior draws plus residual variance) and 4 (species free, new
standalone projector adapted from R/17_stand_projection_engine.R fed by the species free fits via
R/50sf_extract_speciesfree_residuals.R) require a new projection driver plus multi hour CONUS plus AK
compute. This is explicitly a multi session build (FVS_FOURARM_CONUS_PLAN Phase 2). The final harmonized
integration is additionally gated on CEM reaching 48. Neither was forced in this run; the watchers
(fvs-rerun-driver, cem-48-catch-and-integrate, harmonized-carbon-monitor) carry the cadence.

## Footer

```
[DATA_STATE]: base CONUS FVS reserve aggregated and FIA anchored, both configs, 48 states; 26.6M projected rows reduced to per state per ha trajectories; no low match states.
[OUTCOME_VERIFICATION]: 2100 reserve 40,085 Tg C calibrated, +24.5% vs buggy v4 (32,207), matching the predicted direction of the SDIMAX fix; component-level four-arm DG validation independently confirms the fvs-conus equation forms.
[IMPACT_UTILITY]: feeds build_crossmodel_ci.R + build_ensemble_estimate.R as the corrected FVS member (arms 1-2); staged to repo results_snapshot/ and local outputs. Zenodo corrected version pending Aaron's go.
[NEXT_AUTONOMOUS_STEP]: build the fvs-conus stand-level projection driver (Phase 2) for arms 3 and 4, validate one variant against output/sf_bench, then run CONUS+AK; final harmonized integration once CEM hits 48.
```
