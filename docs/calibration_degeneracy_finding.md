# Critical methods finding — calibration degeneracy at very low θ

**Date:** 2026-05-16 PM
**Significance:** Modifies the WA Tier 1 recommendation from θ=0.20 (LL minimum) to **θ=0.30 (active-growth optimum)**.

## The finding

Examination of per-plot 100-year trajectories across the full WA Tier 1 θ ladder reveals that at θ ≤ 0.20, LANDIS-II produces **zero net biomass change over 100 years** for the majority of plots. The model is effectively turned off — productivity is reduced to roughly equal mortality, and each plot remains at its initial biomass.

Quantitatively, for WA plot 1 (initial biomass 83.29 Mg/ha):

| θ | Year 0 | Year 100 | % growth |
|---:|---:|---:|---:|
| 1.00 | 83.29 | 398.49 | +378% |
| 0.75 | 83.29 | 303.98 | +265% |
| 0.50 | 83.29 | 199.09 | +139% |
| 0.40 | 83.29 | 162.88 | +96% |
| 0.30 | 83.29 | 117.56 | +41% |
| 0.25 | 83.29 | 100.94 | +21% |
| 0.20 | 83.29 | 83.29 | 0% |
| 0.15 | 83.29 | 83.29 | 0% |
| 0.10 | 83.29 | 83.29 | 0% |

The transition is abrupt between θ=0.25 (still growing) and θ=0.20 (static).

## Why the LL "optimum" at θ=0.20 is degenerate

The likelihood objective rewards small residuals. FIA observations on most untreated plots show slow biomass change over the 20-year inventory cycle (since untreated plots are by definition not subject to large disturbance). When LANDIS predicts zero biomass change at θ ≤ 0.20, the predicted trajectory stays at the IC value, which happens to be close to the FIA observations — by construction, because the IC was *set* from FIA Round 1.

The LL is therefore artificially good at θ ≤ 0.20 because:
1. Predicted Year 0 = FIA Round 1 (by construction, IC)
2. Predicted Year 5, 10, ... = also Year 0 value (no growth)
3. FIA Round 2, 3, ... show slow change
4. Residuals are small because both prediction and observation hover near IC

This is not a calibration of growth dynamics — it's the model being turned off and matching by coincidence.

## How to detect calibration degeneracy

We recommend two diagnostic checks for any Tier 1 ladder analysis:

**Diagnostic 1: Per-plot trajectory growth fraction**
For each θ, compute the fraction of plots showing non-trivial growth (e.g., >5% biomass change between year 0 and year 100). Calibrations where >50% of plots are static represent degenerate solutions.

**Diagnostic 2: State-aggregate growth ratio**
For each θ, compute the year-100 / year-0 state-aggregate biomass ratio. Calibrations producing ratio ≤ 1.05 represent degeneracy. Realistic forest succession produces ratios in the range 1.3–4.0 depending on stand maturity and species composition.

Applying these diagnostics to the WA ladder:

| θ | Plot 1 growth | Likely active fraction | Diagnostic |
|---:|---:|---:|---|
| 0.30 | +41% | ~100% | ACTIVE |
| 0.25 | +21% | ~50% | borderline |
| 0.20 | 0% | ~0% | DEGENERATE |
| 0.15 | 0% | 0% | DEGENERATE |
| 0.10 | 0% | 0% | DEGENERATE |

## Revised WA Tier 1 recommendation

The recommended WA Tier 1 calibration is **θ=0.30** (LL/cell = −0.544, mean residual +0.011). At this θ, LANDIS-II produces realistic active succession dynamics that match FIA observations.

The LL minimum at θ=0.20 (LL/cell = −0.530, ΔLL +0.014 over θ=0.30) should be flagged as a degenerate solution in any methods paper Section 3.2 and not used as the production calibration.

## Implications for the methods paper

This finding strengthens the methods paper substantially in two ways:

**First**, it identifies a calibration pathology that has *not been discussed in the LANDIS-II calibration literature to our knowledge*. The standard approach (optimize LL) can produce degenerate solutions when the model's productivity multiplier is pushed low enough that growth ≈ mortality. Any future regional calibration should include the activity diagnostics we propose.

**Second**, it explains why the leave-one-ecoregion-out CV in our earlier validation showed Coast Range and Cascades fitting near-perfectly at θ=0.30 but worse at lower θ. The "improvement" at θ < 0.30 in the aggregate LL is not real — it's the model collapsing into the degenerate state.

## Modifications to the methods paper

1. **Section 3.2** (Tier 1 ladder): Recommend θ=0.30 as the WA Tier 1 calibration (not the raw LL minimum at θ=0.20). Add a sentence: "The LL curve continues to decrease below θ=0.30, but per-plot trajectory analysis reveals that the model produces zero net growth at θ ≤ 0.20, a degenerate solution where the calibration's apparent success arises from the model being turned off rather than from genuine fit to growth dynamics. We therefore identify θ=0.30 as the active-growth optimum and recommend it as the production calibration for Washington."

2. **Section 4.4** (Limitations): Add a paragraph on calibration degeneracy: "Our framework assumes that the likelihood maximum corresponds to the best calibration. We discovered during this analysis that very low productivity multipliers can produce degenerate solutions in which LANDIS-II generates near-static trajectories whose residuals against FIA observations are small by construction. We address this by requiring that the recommended calibration produce active succession dynamics, defined as >5% per-plot biomass change over 100 years. Future calibration studies should include analogous activity diagnostics."

3. **Methods paper Figure 5** (Tier 1 θ ladder): Add a shaded region indicating the "degenerate zone" at θ ≤ 0.20.

## Numerical impact

The recommended WA calibration changes from:
- θ=0.20: LL/cell = -0.530, Plot 1 growth = 0%
- to **θ=0.30**: LL/cell = -0.544, Plot 1 growth = +41%

ΔLL: -0.014 per cell (-130 LL total) — modest cost. In exchange we gain a calibration that actually simulates growth, which is the entire point.

For the WA per-cell year-100 biomass asymptote:
- Tier 0: 562 Mg/ha (literature)
- Tier 1 θ=0.20 degenerate: ~140 Mg/ha (no growth)
- **Tier 1 θ=0.30 active**: 185 Mg/ha (realistic)

The state-aggregate carbon implication: the recommended calibration produces ~125 MMT lower year-100 biomass than literature default, much more biologically reasonable than the θ=0.20 degenerate value of ~95 MMT.
