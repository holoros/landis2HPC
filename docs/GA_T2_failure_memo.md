# GA Tier 2 calibration failure memo

**Date:** 2026-05-17
**Status:** GA T2 attempt complete; production GA calibration remains Tier 1 θ=0.30
**Recommendation:** flag GA Tier 2 as future work, document the failure mode in the paper

## Summary

A CMA-ES Tier 2 per-species calibration was attempted for Georgia (54 parameters: ANPP and BMAX multipliers for 27 species). The chain ran to completion (8 iterations × 14 candidates = 112 evaluations), producing what the optimizer reported as a best vector at negLL=−15.75 (LL=+15.75). On post-hoc inspection, the LL was computed over only **n=2** valid (predicted, observed) plot pairs out of a 779-plot target subset. The "best" calibration is therefore not credible at the state scale.

## Diagnostic distribution of plot success

Across all 112 GA T2 candidates:

| Quantile | n_pairs |
|---|---|
| min | 0 |
| 25th percentile | 0 |
| median | ~3 |
| mean | 10.3 |
| max | 82 |
| n_pairs ≥ 100 | **0 (0%)** |
| n_pairs ≥ 300 | 0 |

For contrast, the WA T2 chain (same code, same pipeline architecture):

| Quantile | n_pairs |
|---|---|
| max | 5278 |
| mean | 1346 |
| n_pairs ≥ 300 | 104 / 112 (93%) |
| n_pairs ≥ 500 | 103 / 112 (92%) |

## Root cause hypothesis

The GA per-plot scenario builder (`build_plot_scenario_GA.sh`) or the GA aggregator pairing logic appears to fail for the vast majority of GA plots. Three candidate explanations:

1. The GA initial-condition file mapping (`plot_ics_full/_summary.csv`) is incomplete or has a plot_id ↔ FIRST_PLTCN encoding mismatch that worked for WA but not GA.

2. The GA `untreated_plots_GA.csv` observation file uses different column naming (`BIOM_yrN_Mgha` style) than the WA file, causing the LL pairing step to find no matches.

3. The GA SspEcoregionData filter step in the runner removes too many rows when the candidate θ is applied, leaving plots with no valid species data and triggering silent LANDIS failures.

A targeted diagnostic run (single GA candidate at θ=0.30, with full verbose logging at each pipeline stage) is the next investigative step.

## Implications for the v1.0 release

1. **Production GA calibration remains Tier 1 uniform θ=0.30** — derived from the WA-equivalent T1 ladder applied to GA's 779-plot subset, with LL=+5.26 over the plot-paired sample (a defensible calibration with adequate evidence).

2. **The methods paper Section 3 framing** changes from "three states get Tier 2 calibration" to "two states (ME, WA) get Tier 2 per-species calibration; GA receives Tier 1 uniform calibration with Tier 2 flagged as future work after a pipeline diagnostic". This is a stronger and more honest framing.

3. **The cross-state directional asymmetry finding** is unchanged: GA at Tier 1 θ=0.30 still gives 35% asymptote reduction vs literature, which is the headline result.

4. **The calibration degeneracy / sample-size pathology** finding is *reinforced* by the GA T2 failure — it demonstrates a complementary failure mode (low plot success rate yielding trivially small LL magnitudes) and motivates the addition of the n_pairs minimum guard to the CMA-ES drivers.

## Production calibration table

| State | Production calibration | LL | n_pairs | Status |
|---|---|---|---|---|
| Maine | T2 per-species | +34.2 | 612 | manuscript-final |
| Georgia | T1 uniform θ=0.30 | +5.26 | 218 | manuscript-final |
| Washington | T2 per-species iter1_cand11 | −174.4 (per-plot −0.217) | 805 | manuscript-final |

GA T2 attempt (LL=+15.75 over n=2) is *not* the production calibration.

## Patches added to drivers for future runs

```python
# In cma_es_optimize_WA.py and cma_es_optimize_GA.py evaluate():
MIN_N_PAIRS = 300  # require >= 300 paired plots before accepting LL
...
# After reading LL, also read launch.log or recompute n from per_plot.csv:
n_pairs = count_per_plot_rows(per_plot_csv)
if n_pairs < MIN_N_PAIRS:
    sys.stderr.write(f"DEGEN {tag}: n_pairs={n_pairs} < {MIN_N_PAIRS}; penalized\n")
    return DEGENERACY_PENALTY
```

A patched driver is committed to `perseus/tools/` for the next T2 run attempt.

## Lessons for the paper

This adds a third entry to the calibration pathology catalog (Methods Section 2.4):

1. Active-growth degeneracy (low θ → zero-growth trivial fit) — primary degeneracy
2. Empty-aggregator degeneracy (per_plot.csv empty → LL=0 default) — secondary degeneracy
3. **Sample-size degeneracy** (very few plots succeed → trivially small LL magnitude → CMA-ES selects this as "best") — tertiary degeneracy

All three demonstrate the importance of sample-size-aware optimization in landscape-scale model calibration. The per-plot LL (LL/n) or BIC-style normalization is the recommended fitness target rather than total LL.
