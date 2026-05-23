# Methods Section 3 results update: six-state production calibration

Paper-ready replacement for the three-state production results in Section 3. Drop in over the prior production table and add the regional-gradient paragraph as the new lead result. Numbers are the v1.2 production calibrations.

## 3.x Production calibrations across six states

We carried the calibration ladder to production for six states spanning three forest regions. Each production vector is the per-species Tier 2 result selected by the highest per-plot log-likelihood among candidates evaluated on a near-complete plot set (n at least 0.85 of the chain maximum), the selection rule that guards against the sample-size degeneracy described in Section 2.

Table 3.x. Production calibrations.

| State | Region | Production tier | Per-plot LL | Paired plots n |
|---|---|---|---|---|
| Maine | Northeast | Tier 2 per-species | +0.056 | 612 |
| Washington | West | Tier 2 per-species | −0.217 | 805 |
| Georgia | Southeast | Tier 2 per-species | −0.887 | 1255 |
| Michigan | Great Lakes | Tier 2 per-species | −0.129 | 562 |
| Wisconsin | Great Lakes | Tier 2 per-species | −0.647 | 916 |
| Minnesota | Great Lakes | Tier 2 per-species | −0.933 | 2741 |

Per-plot log-likelihood is interpreted within a state across tiers, not compared across states, because the residual scale tracks the biomass regime: lower-biomass forests yield smaller residuals and a higher per-plot value than high-biomass forests. For the cross-state comparison we use the correction factor below.

For Georgia, a matched sample-size evaluation confirmed the Tier 2 vector over the earlier Tier 1 uniform optimum: scored on the same plot subset, Tier 2 gave a per-plot log-likelihood of −0.887 against −0.960 for the uniform multiplier of 0.30, so all six states are reported at Tier 2.

## 3.x The headline result: a regional gradient in literature bias

Expressed as the ratio of the calibrated to the literature aboveground net primary productivity multiplier, the six states do not sort into a single global offset but into three coherent regimes that follow a productivity and moisture gradient (Fig. sixstate_literature_bias_gradient).

In the Northeast, Maine, the literature underpredicts: the median per-species ANPP multiplier is 1.31 and 85 percent of species exceed 1.0. In the Great Lakes, Minnesota, Wisconsin, and Michigan, the literature overpredicts moderately, with median multipliers of 0.60, 0.65, and 0.63. In the West and Southeast, Washington and Georgia, the literature overpredicts strongly, with a Tier 1 optimum of 0.20 for Washington and a per-species median of 0.31 for Georgia.

A calibration that pulled every state the same direction would be hard to distinguish from a units or convention artifact. Six states sorting into scale-up, moderate-scale-down, and strong-scale-down along a recognizable biogeographic gradient is direct evidence that the off-the-shelf parameterization carries genuine, regionally structured bias, and that region-specific calibration is necessary rather than cosmetic.

The per-species corrections are also internally coherent. Plotting each species by its ANPP multiplier against its maximum-biomass multiplier (Fig. greatlakes_per_species_structure; Fig. me_tier2_multiplier_structure) separates the two corrections and recovers ecologically sensible groups: in Maine most species are scaled up on both axes, while balsam fir alone receives a sharp productivity increase (2.26) with a reduced biomass ceiling (0.54), the expected signature of a fast-growing, short-lived species, recovered from data without prior life-history input.

## 3.x Consequence for statewide carbon

The level correction propagates directly to carbon accounting. For Washington, the calibration lowers the median year-100 aboveground biomass from a literature value of 562 to 185 Mg per hectare, a 67 percent reduction, which translates to roughly 264 versus 87 Mg of carbon per hectare at the century mark (Fig. wa_statewide_carbon_trajectory). An uncalibrated application of the literature parameters would therefore overstate the standing carbon stock at year 100 by about a factor of three. The reduction is a correction of the asymptote rather than a suppression of growth: 53 percent of Washington plots still accrue biomass over the century, 44 percent hold steady, and only 3 percent decline.

Maine runs the other way. There the calibration lifts the median year-100 carbon from a literature 103 to 136 Mg per hectare, a 32 percent increase that matches the median ANPP multiplier of 1.31, because the literature underpredicts productivity in the Northeast. The two states bracket the regional gradient at the carbon-accounting level: uncalibrated literature parameters overstate the Western stock by roughly threefold and understate the Northeastern stock by about a third (Fig. statewide_carbon_WA_ME). Both trajectories come from real 100-year LANDIS runs over the state plot sets (Washington n=4429, Maine n=1220), not from the modeled envelope.

## Figures referenced

`perseus/figures/sixstate_literature_bias_gradient.png`, `perseus/figures/greatlakes_per_species_structure.png`, `perseus/figures/me_tier2_multiplier_structure.png`, `perseus/figures/wa_calibration_effect_year100.png`, `perseus/figures/wa_statewide_carbon_trajectory.png`.

## Note on remaining work for the final figure

Washington is shown at its Tier 1 uniform optimum in the gradient figure because its production vector is Tier 2 but its per-plot multiplier vector was not exported into the atlas in the same per-species form as the other states. The final camera-ready gradient figure should use Washington's Tier 2 per-species multipliers once exported, which will not change the three-regime ordering.
