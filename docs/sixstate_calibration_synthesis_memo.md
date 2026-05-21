# PERSEUS six-state calibration synthesis

**Date:** 2026-05-21
**Data:** production theta vectors for ME, GA, WA, MN, WI, MI (`states/{ST}/perseus/bayesian/.../theta_best_production.csv`) and the ME atlas multipliers.
**Figures:** `perseus/figures/sixstate_literature_bias_gradient.png` (regional gradient),
`perseus/figures/greatlakes_per_species_structure.png` (per-species ANPP vs ceiling: Maine up, Great Lakes moderate down),
`perseus/figures/wa_statewide_carbon_trajectory.png` (Washington statewide carbon: literature overstates the year-100 stock 3x, 264 vs 87 Mg C/ha)

## Production calibration table

| State | Region | Production vector | Per-plot LL | n |
|---|---|---|---|---|
| Maine | Northeast | T2 per-species (26 params) | +0.056 | 612 |
| Georgia | Southeast | T1 uniform θ = 0.30 (T2 archived) | +0.024 | 218 |
| Washington | West | T2 per-species (50 params) | −0.217 | 805 |
| Michigan | Great Lakes | T2 per-species (iter7_cand5) | −0.1292 | 562 |
| Wisconsin | Great Lakes | T2 per-species (iter2_cand11) | −0.6470 | 916 |
| Minnesota | Great Lakes | T2 per-species (iter7_cand0) | −0.9325 | 2741 |

Per-plot log-likelihood is not directly comparable across states because the residual scale tracks the biomass regime: lower-biomass forests (Michigan) produce smaller residuals and a higher per-plot LL than high-biomass forests (Minnesota, Washington). The fit metric is meaningful within a state, across tiers; across states, read the correction factor below instead.

## The headline: a regional gradient in literature bias

Expressed as the ANPP correction factor (calibrated divided by literature), the six states sort into three coherent regimes that follow a productivity and moisture gradient rather than a single global offset:

- **Northeast (Maine): scale up.** Median ANPP multiplier 1.31, with 85 percent of species above 1.0. The literature underpredicts productivity here.
- **Great Lakes (Minnesota, Wisconsin, Michigan): scale down moderately.** Median multipliers 0.60, 0.65, and 0.63. The literature overpredicts, but only by a third to a half.
- **West and Southeast (Washington, Georgia): scale down hard.** Washington's Tier 1 optimum is θ = 0.20 and Georgia's per-species median is 0.31. The literature overpredicts standing productivity by a factor of three to five.

A framework that pulled every state the same direction would be easy to dismiss as a units or convention artifact. Six states sorting into up, moderate-down, and strong-down along a recognizable biogeographic gradient is direct evidence that the off-the-shelf literature parameterization carries genuine, regionally structured bias, and that region-specific calibration is necessary rather than cosmetic. This is the strongest single result in the framework and the natural headline for the methods paper.

## Caveats

The Maine, Georgia, Minnesota, Wisconsin, and Michigan values are per-species ANPP multipliers; Washington is shown at its Tier 1 uniform optimum because its production vector is Tier 2 but its per-plot multiplier vector was not exported into the atlas in the same form. The robust claim is the three-regime ordering of the correction factor, not a precise per-state magnitude on a single common scale. Georgia's production tier remains provisionally Tier 1 pending the matched-n Tier 1 versus Tier 2 evaluation; the per-species median quoted here is from the archived Tier 2 vector and agrees with the Tier 1 optimum.

## Next

Redraw with Washington's Tier 2 per-species multipliers once exported, fold the table and the gradient figure into Methods Section 3, and generate the per-plot trajectory exports so the GUI shows measured curves and statewide carbon for all six states.
