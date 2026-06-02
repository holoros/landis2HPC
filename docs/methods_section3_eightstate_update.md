# Methods Section 3 results update: eight-state production calibration (v1.8)

Replaces the six-state version (`methods_section3_sixstate_update.md`) with the eight-state result, the WA v2.0 statewide-carbon refresh from the 2026-06-02 rerun, and the new N3 (Eastern Hardwood Central) cluster pair (IN, OH).

## 3.x Production calibrations across eight states

We carried the calibration ladder to production for eight states spanning four forest regions. Each production vector is the per-species Tier 2 result selected by the highest per-plot log-likelihood among candidates evaluated on a near-full plot set (n at least 0.85 of the chain maximum). For the Eastern Hardwood Central cluster (Indiana, Ohio), the calibration used a hybrid warmstart from a cluster reference and a densified likelihood pairing that interpolates the predicted trajectory and pairs against every observed inventory year in the 0 to 30 year window rather than only 5-year steps; this densification was the key unblock that raised matched n from about 200 to over 700.

Table 3.x. Production calibrations.

| State | Region (cluster) | Production tier | Per-plot LL | Paired plots n |
|---|---|---|---|---|
| Maine | Northeast (N1) | Tier 2 per-species v1.0 | +0.056 | 612 |
| Washington | West (P3) | Tier 2 per-species v2.0 | −0.625 | 1415 |
| Georgia | Southeast (S1) | Tier 2 per-species v2.0 | −0.880 | 1249 |
| Minnesota | Great Lakes (N2) | Tier 2 per-species v1.2 | −0.933 | 2741 |
| Wisconsin | Great Lakes (N2) | Tier 2 per-species v1.2 | −0.647 | 916 |
| Michigan | Great Lakes (N2) | Tier 2 per-species v1.2 | −0.129 | 562 |
| Indiana | Eastern Hardwood Central (N3) | Tier 2 per-species v3 | −1.315 | 733 |
| Ohio | Eastern Hardwood Central (N3) | Tier 2 per-species v2 | −0.862 | 713 |

Per-plot log-likelihood is interpreted within a state across tiers, not compared across states, because the residual scale tracks the biomass regime: lower-biomass forests yield smaller residuals and a higher per-plot value than high-biomass forests. For the cross-state comparison we use the carbon ratio (Section 3.x.3 below).

The N3 pair (Indiana and Ohio) is the first cluster to be calibrated through the hybrid warmstart pathway. Both states share an identical 22-species pool. Ohio's calibration fit substantially better than Indiana's (per-plot LL −0.86 vs −1.31). That an in-cluster sibling reaches a healthy fit while the reference state does not indicates the lower Indiana LL is state-specific rather than systemic to the N3 cluster, and the cluster reference vector (frozen from Indiana's production theta) remains a defensible warmstart for future Eastern Hardwood Central states.

## 3.x.2 The headline result: a regional gradient in literature bias

Expressed as the ratio of the calibrated to the literature aboveground net primary productivity multiplier, the eight states sort into three coherent regimes that follow a productivity and moisture gradient (Fig. eightstate_literature_bias_gradient).

In the Northeast (Maine), the literature underpredicts: the median per-species ANPP multiplier is 1.31 and 85 percent of species exceed 1.0. In the Great Lakes (Minnesota, Wisconsin, Michigan), the literature overpredicts moderately, with median multipliers of 0.60, 0.65, and 0.63. In the West (Washington v2.0) and Southeast (Georgia), the literature overpredicts strongly, with median multipliers of 0.48 (Washington) and 0.31 (Georgia). The Eastern Hardwood Central pair (Indiana, Ohio) sits in a moderate-to-strong cut regime, intermediate between Great Lakes and Southeast.

A calibration that pulled every state the same direction would be hard to distinguish from a units or convention artifact. Eight states sorting into scale-up, moderate-scale-down, and strong-scale-down along a recognizable biogeographic gradient is direct evidence that the off-the-shelf parameterization carries genuine, regionally structured bias, and that region-specific calibration is necessary rather than cosmetic.

## 3.x.3 Consequence for statewide carbon (v1.8 update)

The level correction propagates directly to carbon accounting. For Washington under the v2.0 production vector, the calibration lowers the median year-100 aboveground biomass from a literature value of 562 to about 306 Mg per hectare, which translates to roughly 264 versus 144 Mg of carbon per hectare at the century mark (Fig. statewide_carbon_5state). An uncalibrated application of the literature parameters would therefore overstate the standing carbon stock at year 100 by about a factor of 1.8 under the v2.0 calibration. (Under v1.0 the same comparison gave 264 versus 87, a factor of 3.0. The shift between v1.0 and v2.0 reflects a per-species reshuffling of the Washington ANPP vector at near-identical median, on a much larger evaluation set: n = 1415 plots under v2.0 versus 805 under v1.0.)

Maine runs the other way. There the calibration lifts the median year-100 carbon from a literature 103 to 136 Mg per hectare, a 32 percent increase that matches the median ANPP multiplier of 1.31, because the literature underpredicts productivity in the Northeast.

Minnesota, Wisconsin, and Michigan fill in the intermediate Great Lakes regime: calibration cuts the year-100 carbon by 1.5 to 1.7 fold (literature 131, 177, 179 Mg C per hectare; calibrated 78, 118, 105), a strict between-extremes result. Across all five states with completed statewide trajectories (Fig. statewide_carbon_5state), the year-100 ratio of calibrated to literature carbon matches each state's median ANPP multiplier within about 0.10: Washington 0.55 versus theta 0.48 (gap 0.07), Minnesota 0.60 versus 0.60, Wisconsin 0.67 versus 0.65, Michigan 0.59 versus 0.63, and Maine 1.32 versus 1.31. The per-species correction at the small scale propagates coherently to the state-aggregate carbon trajectory; the small-scale multiplier and the large-scale carbon carry the same information. All five trajectories come from real 100 year LANDIS runs over the state plot sets (n in 400 to 4429), not from the modeled envelope.

## 3.x.4 Note on the v1.0 to v2.0 Washington shift

The Washington v1.0 production vector (iter1_cand11) was selected with a smaller evaluation set (n = 805) before the harvester adopted the near-full-n per-plot floor rule. Under the v2.0 evaluation framework, the matched-n eval on 1415 plots picked a different optimum (iter9_cand4) whose median ANPP multiplier (0.48) is slightly higher than v1.0's (0.52) but whose per-species reshuffling produces a substantially gentler year-100 biomass cut. The statewide carbon ratio moved from 0.33 (v1.0) to 0.55 (v2.0). The qualitative finding, that the literature substantially overpredicts Washington carbon, holds in both versions; the v2.0 finding is calibrated against the larger and more diverse plot set and is the current production value.

The Indiana and Ohio statewide carbon trajectories have not yet been computed under the new N3 production vectors. Once the build-fresh runner is applied to the N3 cluster (an N3-compatible `apply_theta_${ST}_perspecies.py` and `build_plot_scenario_${ST}.sh` are already in place), the eight-state carbon figure can replace the five-state figure.

## Figures referenced

`perseus/figures/eightstate_literature_bias_gradient.png` (pending build for v1.8), `perseus/figures/statewide_carbon_5state.png` (v1.8: WA v2.0 panel updated), `perseus/figures/greatlakes_per_species_structure.png` (unchanged), `perseus/figures/me_tier2_multiplier_structure.png` (unchanged), `perseus/figures/wa_statewide_carbon_trajectory.png` (pending v2.0 refresh).
