# PERSEUS LANDIS-II calibration: stress + validation test framework

**Date:** 2026-05-16
**Purpose:** Verify the calibration's robustness, defend against reviewer overfitting concerns, identify per-species/per-ecoregion weak spots, and refine the models where needed.

## Why this matters

The Tier 0 → Tier 1 → Tier 2 calibration framework reduces residuals dramatically, but reviewers will ask three questions:

1. **How do you know this isn't overfit?** (especially Tier 2 with 50+ parameters)
2. **Will the calibration hold in time periods or geographic areas not used in fitting?**
3. **How sensitive is your conclusion to the specific assumptions of the calibration setup?**

Without explicit stress + validation tests, the calibration LL improvements look impressive but cannot be defended as evidence of model improvement vs evidence of overfitting. The six tests below address each concern directly.

## Test design

### Test 1: K-fold cross-validation (built)

**What it tests:** Whether the Tier 2 θ vector generalizes to held-out plots.

**Implementation:** Random 5-fold split of plots, stratified by L3 ecoregion. Refit Tier 2 on 4 folds, evaluate LL on held-out 5th fold.

**Status:** Built (`cross_validate_tier2.py`) and run on WA T1 θ=0.50 (LL/cell −0.624 ± 0.079 across folds vs full-data −0.630 — no overfitting at uniform θ).

**Standard for the paper:** Run on Tier 2 (the parameter-dense tier) for all three states once CMA-ES converges. Report as Table S2 in supplementary materials.

### Test 2: Time-out-of-sample validation

**What it tests:** Whether the calibration generalizes to inventory cycles not used in fitting. This is the strongest test against overfitting.

**Implementation:**
- Train: Use only FIA `BIOM_<year>_Mgha` columns for years 2001–2015 in the calibration LL.
- Test: Hold out years 2016–2022. Re-run Tier 2 CMA-ES on the train set. Evaluate test-set LL on the held-out 2016–2022 observations.
- Compare to the full-data fit. If test LL is comparable to full LL, the model generalizes temporally. If test LL is much worse, the calibration is exploiting features of the specific years it was trained on.

**Status:** To build. Requires a `--year-cutoff 2015` argument to `likelihood_<state>.py` and a one-shot rerun of CMA-ES. Compute: ~12 hr per state.

**Standard for the paper:** Report train vs test LL/cell as Figure S2. Discussion gets an explicit "no temporal extrapolation problem" paragraph.

### Test 3: Leave-one-ecoregion-out CV

**What it tests:** Spatial transferability — whether the calibration learned in one ecoregion generalizes to ecoregions held out.

**Implementation:**
- For each L3 ecoregion in each state, hold out all plots in that ecoregion as the test fold.
- Refit Tier 2 on the remaining ecoregions; evaluate LL on the held-out ecoregion.
- A small handful of plots in held-out ecoregion (e.g., GA ecoregion 68 with only 29 plots) get low-power CV; flag those.

**Why this is stronger than random 5-fold:** Random folds break spatial autocorrelation, which biases CV LL optimistic. Leave-one-ecoregion-out preserves the spatial structure that mattered for parameter inference.

**Status:** To build. Implementation parallels `cross_validate_tier2.py` but groups plots by ecoregion instead of randomly. Compute: 7 refits for WA (one per ecoregion), 6 for GA, 3 for ME. ~3 days Cardinal time per state.

**Standard for the paper:** Heatmap (state × ecoregion) showing LL/cell drop for each leave-one-out. Discussion: identify the ecoregion most over-predicted by neighbors' parameters.

### Test 4: Cross-state generalization

**What it tests:** How badly does a state's calibrated θ vector fit a different state? Establishes upper bound on how much state-specific calibration matters.

**Implementation:**
- Apply ME's Tier 2 θ vector to WA's plots (species-only intersection; ME has 13 species, WA has 25, so this is partial).
- Apply WA's Tier 2 θ vector to ME's plots (same partial).
- Apply GA's Tier 2 θ vector to WA's plots (almost no species overlap; expect large error).
- Compute LL/cell for each combination and compare to in-state Tier 2 LL/cell.

**Why this matters:** If cross-state LLs are within 10% of in-state, regional parameter transfer is defensible. If they're 10× worse, state-specific calibration is essential — which is the strongest argument for the methods paper's regional approach.

**Status:** To build. Requires a `--theta-from-state` flag in `apply_theta_<state>_perspecies.py`. Compute: 4-6 forward runs (one per cross-state cell). ~12 hr.

**Standard for the paper:** 3×3 cross-state heatmap (Figure 6 in the outline). Numbers in Table 4.

### Test 5: Bootstrap parameter uncertainty

**What it tests:** Confidence interval on each calibrated multiplier. Distinguishes "well-identified" parameters from "barely-constrained" ones.

**Implementation:**
- Bootstrap resample plots (with replacement) 1000 times.
- For each bootstrap sample, re-fit Tier 1 θ (cheap — single value).
- For Tier 2, re-fit a subset of multipliers (e.g., the species-by-species multiplier for the 5 most abundant species) in each bootstrap. Don't run full 50-dim Tier 2 in each bootstrap; that would be 12,000 hours.

**Why this matters:** Reviewers will ask "what's the uncertainty on each species multiplier?" Without bootstrap, we can only quote the CMA-ES point estimate.

**Status:** To build. Tier 1 bootstrap is fast (1000 evaluations × ~30 sec each = 8 hr on a single core). Tier 2 partial bootstrap: ~1000 × 30 min = 500 hr.

**Standard for the paper:** Table 3 shows per-species multiplier ± 95% bootstrap CI. Species whose CI crosses 1.0 (no significant deviation from literature) are reported separately.

### Test 6: Initial-condition perturbation stress test

**What it tests:** How sensitive is the 100-yr biomass trajectory to ±25% biomass uncertainty in the FIA-derived initial conditions? The FIA biomass is reported with ~10–15% measurement uncertainty.

**Implementation:**
- For 100 randomly selected plots per state (300 total), generate 10 alternative ICs:
  - 5 perturbations of biomass: ±5%, ±10%, ±25%
  - 5 perturbations of age structure: shift each cohort by ±1 age class
- Run LANDIS Tier 2 on each perturbed IC.
- Compute the coefficient of variation in year-100 total biomass across the 10 perturbations.

**Why this matters:** If a 25% IC perturbation produces only a 5% year-100 trajectory change, the model has internal stabilization. If it produces a 50% change, the projections are propagating IC uncertainty unbounded — a critical caveat for any scenario application.

**Status:** To build. Compute: 300 plots × 10 perturbations = 3,000 runs × 11 sec each = 9 hr.

**Standard for the paper:** Figure 8 (one of the eight listed in the outline). Discussion: trajectory uncertainty bounds for the scenario paper.

## Refinement decisions enabled by these tests

The tests don't just verify — they tell us how to refine the calibration:

1. **From CV (Test 1):** Identify plots that consistently contribute large residuals across all folds. These are likely sub-clinical disturbance plots that the "untreated" filter missed. Refine by excluding them from a v2 calibration.

2. **From time-OOS (Test 2):** If 2016–2022 residuals differ systematically from 2001–2015 (e.g., warmer years over-predict more), the model has a climate-sensitivity gap. Refine by adding a climate-conditioned θ tier.

3. **From leave-one-ecoregion-out (Test 3):** Ecoregions with bad held-out LL are candidates for Tier 1.5 per-ecoregion treatment (rather than the current state-wide single Tier 2 vector).

4. **From cross-state (Test 4):** If WA's vector applies poorly to ME-only species, it suggests the species-by-species multipliers are correlated with regional climate variables rather than species-intrinsic biology. Could motivate a meta-analysis tier combining all 3 states' species.

5. **From bootstrap (Test 5):** Species multipliers whose 95% CI is consistent with 1.0 should be re-parameterized at the literature default. This reduces the effective dimensionality without sacrificing LL — directly addressing the overfitting concern.

6. **From IC perturbation (Test 6):** Plots with high trajectory variance are unreliable for scenario inference and should be down-weighted in the factorial analysis.

## Compute budget for the full framework

| Test | Compute per state | All 3 states |
|---|---:|---:|
| K-fold CV | 0 hr (uses existing fit) | 0 hr |
| Time-out-of-sample | 12 hr | 36 hr |
| Leave-one-ecoregion-out | 36-72 hr | 108-216 hr |
| Cross-state | 12 hr | 12 hr total (shared) |
| Bootstrap Tier 1 | 8 hr | 24 hr |
| Bootstrap Tier 2 (subset) | 50 hr | 150 hr |
| IC perturbation | 9 hr | 27 hr |
| **Total** | | **~360-470 hr** |

That fits comfortably in 2-3 weeks of Cardinal time after Tier 2 base calibrations converge.

## Priority ordering for paper

For the methods paper as currently written, the minimum bar is:

1. K-fold CV (already have) — Table S2
2. Time-out-of-sample (12 hr × 3 = 36 hr compute) — Figure S2
3. Cross-state (12 hr total) — Figure 6 + Table 4

These three tests directly address the overfitting concern. The leave-one-ecoregion-out and bootstrap tests would strengthen the paper substantially but can be deferred to a revision response if reviewers ask.

The IC perturbation test belongs more naturally in the scenario paper than the methods paper — it caveats the *application* of the calibrated parameters, not the calibration itself.

## What this enables for refinement

Once we have time-out-of-sample residuals and cross-state residuals, we can identify a small set of "weak" parameters whose calibration is unstable. Re-running a final v2 Tier 2 with those parameters fixed at literature defaults (and only the remaining "robust" parameters free) gives us a defensible, defendable, reduced-dimensionality model that achieves nearly the same LL as full Tier 2 but with a substantially smaller overfitting argument surface.

The framework also gives us a defensible "halting criterion" for adding more calibration tiers. If Tier 2 cross-state generalizes well and time-out-of-sample residuals look like in-sample residuals, there's no evidence we need a more complex Tier 3 — we stop, ship the paper, and let readers replicate.
