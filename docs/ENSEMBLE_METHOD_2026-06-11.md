# Weighted multi-model ensemble: method outline

Date 2026-06-11. Defines how the five harmonized models are combined into a single best-estimate
forest-carbon trajectory with a credible interval. Implemented in `build_ensemble_estimate.R`
(output `harmonized_best_estimate.csv`).

## Inputs

Per state and year (2025, 2050, 2075, 2100), the disturbance-aware reserve trajectory from each model
that covers the state: FVS (calibrated), LANDIS, CBM, yield curves, CEM. All are already on the common
footing (same FIA 2025 anchor, same HCS harvest, same disturbance overlay), so they are directly
combinable. Each model value carries an intra-model relative SD where measured:
FVS Bayesian posterior (~3%), CBM OAT envelope (~3.2-3.5%), yield-curve rcp+simulation (~8%);
LANDIS and CEM use the FIA anchor CV only.

## Weighting schemes

1. EQUAL (primary; CMIP-style model democracy). Each available model gets weight 1. This is the
   default central estimate and makes no judgment about which model is "right."
2. BENCHMARK-INFORMED (sensitivity). Down-weight the documented structural outliers to 0.5:
   FVS in the 11 western states (the high no-disturbance biomass end-member, confirmed intrinsic, not
   a bug) and CEM everywhere (scenario-invariant and pessimistic relative to the American Forests CBM
   benchmarks). Weights are transparent and editable; this is a sensitivity, not the headline.

Best estimate = weighted mean of the model values. The two schemes agree closely at CONUS
(2100: equal 23.5, benchmark 23.5 Pg C) and differ mainly in the West per state (e.g. CA equal 1584 vs
benchmark 1468 Tg C; OR 1758 vs 1530), where down-weighting FVS lowers the estimate.

## Credible interval

The 90% credible interval combines the three uncertainty sources in quadrature:

  total_sd = sqrt( between_model_sd^2  +  mean(within_model_sd)^2  +  anchor_se^2 )
  90% CrI  = weighted_mean  +/-  1.645 * total_sd   (floored at 0)

between_model_sd (structural) dominates and is the spread across the models; within_model_sd is the
mean of each model's parameter band; anchor_se is the shared FIA sampling term. The interval is wide
where models disagree (CA crI +/-133%, OH +/-85%) and tight where they agree (GA +/-20%), which is the
honest expression of the structural uncertainty.

## Properties and rationale

- Equal weighting is the standard default in multi-model climate/carbon assessments; it avoids
  circular reasoning and lets the inter-model spread speak.
- The benchmark-informed scheme is offered because the validation gave defensible, documented reasons
  to discount specific models in specific regions; keeping it a separate sensitivity preserves
  transparency.
- The credible interval is structural-uncertainty-dominated by construction, consistent with the
  decomposition finding that model choice outweighs parameter and sampling error ~40x by 2100.

## Headline result

CONUS reserve best estimate (equal-weight, disturbance-aware): 2025 15.3, 2050 19.9, 2075 22.6,
2100 23.5 Pg C live aboveground. Per-state 2100 best estimates with 90% credible intervals are in
`harmonized_best_estimate.csv` (e.g. IN 310 [33, 587], OH 438 [65, 811], NH 202 [65, 340],
GA 951 [766, 1137], CA 1584 [0, 3683], OR 1758 [122, 3393] Tg C).

## Extensions (next)

- Bayesian model averaging with weights from benchmark skill (continuous, not 0.5 flags).
- Per-region rather than per-model weighting once more LANDIS states and the eastern FVS refresh land.
- Propagate the LANDIS replicate band and a CEM scenario-uncertainty term when available, so all five
  models contribute a measured within-model SD rather than the anchor CV floor.
