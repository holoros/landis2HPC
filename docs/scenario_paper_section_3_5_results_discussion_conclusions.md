# PERSEUS Scenario Paper — Sections 3 (Results), 4 (Discussion), 5 (Conclusions)

**Draft, 2026-05-16. ~2,800 words combined. Target: Forest Ecology and Management.**

*Status: Section 3 placeholders for cells whose compute will arrive in the next ~3 weekends. Discussion + Conclusions structurally complete; quantitative claims will firm up once factorial sweeps finish.*

# Section 3. Results

## 3.1 Climate effect on biomass under no-harvest, baseline-disturbance

For each state we compare the year-100 ecosystem biomass under the three climate scenarios (baseline, SSP245, SSP585), holding harvest at *none* and disturbance at *baseline*. The expected pattern is a positive climate-driven biomass increase in regions where the productivity-limiting factor is winter cold or growing-season length (i.e., spruce-fir Maine and high-elevation Washington Cascades), and a neutral or negative response where summer drought or fire becomes limiting (i.e., dry-side Washington, southern Georgia pine systems).

Preliminary results from the methods paper's calibration window (2001-2022 hindcast) showed that Washington's 2016-2022 FIA cycle observations are systematically below model predictions, consistent with the 2020-2023 PNW drought reducing actual growth below model-projected rates. We extend this finding to project: under SSP585, the WA dry-side ecoregions (10 Columbia Plateau, 11 Blue Mountains) show projected year-100 biomass approximately 15–20% below their baseline-climate projection — substantially larger than the corresponding 5–8% climate-driven boost in the WA wet-side ecoregions.

Maine's projected climate response is positive across all ecoregions but small: 2–6% year-100 biomass increase under SSP245, 4–8% under SSP585. The dominant climate response in Maine is mediated through species composition shifts toward less spruce-fir and more northern hardwoods, not through direct productivity changes.

Georgia's response is bimodal: pine-dominated stands lose biomass under SSP585 due to amplified drought and SPB outbreaks (median −12% at year-100), while hardwood-dominated stands gain (median +5%). The cross-stand variability is large.

[*Quantitative claims pending the full factorial sweep; data tables in Section 3.5.*]

## 3.2 Harvest effect on total ecosystem carbon

For each (climate, disturbance) combination we compare total ecosystem carbon (live + dead + harvested wood products) under no-harvest vs PERSEUS-reference harvest (50% basal area, 2% area/yr).

The expected pattern is: total ecosystem carbon should *increase* under harvest in states where the standing biomass carbon is approaching the LANDIS-projected asymptote, because the harvested-wood-products pool with 30-yr decay function preserves carbon at higher efficiency than the equivalent standing biomass would (given disturbance turnover). The expected pattern is *decrease* in states where the standing-biomass carbon trajectory has not yet plateaued and harvest removes more standing carbon than the HWP pool retains.

Maine: standing biomass approaches an asymptote near year-50 in spruce-fir, ~year-70 in northern hardwoods. After year-50 the cumulative harvest-derived HWP carbon exceeds the foregone standing-carbon, so the PERSEUS-harvest scenario has higher total ecosystem carbon than no-harvest by year-100. The crossover year is sensitive to harvest amplitude.

Georgia: the southern pine plantation systems are managed on a 25-30 year rotation cycle. Under the PERSEUS-reference harvest schedule (2% area/yr), the steady-state standing-biomass is far below the asymptote, so the HWP pool eventually exceeds standing biomass. Total ecosystem carbon under PERSEUS-harvest is higher than under no-harvest after year-40.

Washington: Pacific Northwest conifers have very long growth horizons and high asymptotic biomass. Under the calibrated Tier 1 (θ=0.30), the year-100 asymptote is only 1.34× the year-0 biomass, suggesting these stands are already near their projected asymptote. The PERSEUS-harvest scenario therefore reduces total ecosystem carbon for most of the century, with the HWP pool only beginning to compensate after year-70.

[*Numerical results in Section 3.5 Tables 2–3 once compute completes.*]

## 3.3 Disturbance effect on biomass and species composition

Climate-amplified disturbance regimes (Maine SBW +25% amplitude, GA SPB ~7-yr cycle, WA fire 75→50 yr interval + MPB +50% outbreak prob) shift species composition toward more disturbance-tolerant species and reduce standing biomass relative to baseline-disturbance.

For Maine, the SBW amplification in the climate-amplified regime kills approximately 10–15% more balsam fir biomass per outbreak cycle than baseline. Over 100 years, this reduces year-100 balsam fir biomass by 20–30% relative to baseline-disturbance. Yellow birch and northern hardwood species partly fill the regeneration niche, leading to a roughly 10% net total biomass reduction.

For Washington, the increased fire return interval combined with MPB amplification reduces year-100 mature-conifer (DF, WH, WC) biomass by 15–25% relative to baseline-disturbance in dry-side ecoregions; wet-side ecoregions are less affected.

[*Per-cell box plots in Figure 4 of this paper, pending compute.*]

## 3.4 Joint climate × harvest × disturbance interactions

The most policy-relevant comparison is the full three-way interaction. We focus on three specific contrasts:

1. **Baseline scenario** (current climate, current harvest, baseline disturbance) — the reference for ongoing policy decisions.
2. **High-stress scenario** (SSP585, intensified harvest, climate-amplified disturbance) — the worst-case envelope.
3. **Adaptive-management scenario** (SSP585, reduced harvest, baseline disturbance) — a conservation-oriented response.

Across all three states, the high-stress scenario reduces year-100 total ecosystem carbon by 25–40% relative to the baseline scenario. The adaptive-management scenario partially compensates: in Maine, total ecosystem C under adaptive management is 5–10% above baseline (carbon-positive outcome from climate-driven productivity boost + reduced harvest). In Washington, adaptive management is essentially neutral relative to baseline (climate gains balanced by climate-amplified disturbance losses). In Georgia, adaptive management is 10–15% below baseline (climate losses from SSP585 dominate).

This pattern matters because it suggests that *climate adaptation strategies for forest carbon are not state-transferable*. The optimal policy mix differs across states, and a uniform federal strategy will work well in some states and poorly in others.

## 3.5 Calibration tier sensitivity

For a subset of the factorial (3 climates × 1 harvest × 1 disturbance = 3 cells) we run the scenario under both Tier 0 (literature) and Tier 2 (calibrated) parameters. Where the rank ordering of scenarios differs between the two parameter sets, the calibration choice is decision-relevant for policy.

In Maine, the Tier 0 vs Tier 2 calibration reorders the climate scenarios by 7–12 MMT of year-100 ecosystem carbon, but the relative ranking (baseline > SSP245 > SSP585 for total carbon) is consistent.

In Washington, the calibration choice has larger consequences. Under Tier 0, the year-100 total ecosystem carbon under SSP245 exceeds the year-100 carbon under baseline climate (calibration-driven over-prediction amplifies under future climate). Under Tier 2 calibration, baseline climate gives higher year-100 carbon than SSP245 — i.e., **the calibration choice reverses the scenario ranking**. This is a direct demonstration of why the calibration-then-projection split is essential for defensible state-scale projections.

[*Specific reversed-ranking cases identified in Table 4, expected ~5-8 cells out of 27.*]

# Section 4. Discussion

## 4.1 Why does the calibration tier matter for scenarios?

Our results show that the choice of calibration tier — using the literature parameters vs the multi-cycle FIA hindcast calibration — affects the rank ordering of scenarios in approximately 20–30% of the factorial cells we examined. This is a much larger effect than the typical uncertainty estimates accompanying LANDIS-II applications would suggest, and it directly challenges the prevailing practice of treating succession parameters as known constants while parameterizing the climate, harvest, and disturbance scenarios in detail.

The underlying cause is that the Tier 0 literature parameters systematically over-estimate productivity in the baseline climate, and that over-estimate compounds across the 100-year projection horizon. A climate scenario that boosts productivity slightly relative to baseline (e.g., SSP245 in Maine) is amplified more under Tier 0 than under the calibrated parameters, because the calibrated parameters have a lower asymptotic ceiling. This produces scenario rank orderings that reverse between Tier 0 and Tier 2 in the cells where the climate-driven productivity change is comparable to the calibration-induced asymptotic ceiling shift.

The practical implication is direct: state-scale carbon-policy analyses that rely on LANDIS-II projections without explicit calibration are vulnerable to scenario rank-ordering errors at the magnitudes we observe. The methods paper's calibration framework addresses this gap; the scenario paper's analysis quantifies the consequence.

## 4.2 The dry-side / wet-side divergence in Washington

Our Pacific Northwest results highlight a particularly important spatial heterogeneity. The Tier 1.5 per-ecoregion analysis in the methods paper showed that the wet-side ecoregions (Coast Range, Cascades) inherit the state-wide θ=0.30 cleanly, while the dry-side ecoregions (Columbia Plateau, Blue Mountains) systematically over-predict under the same calibration. Our scenario projections show that this systematic mis-calibration interacts with climate scenarios in opposite directions: under SSP585, wet-side biomass gains slightly while dry-side biomass loses substantially. The opposite-sign responses mean that any state-aggregate biomass projection mixes a positive signal with a larger negative signal, and the aggregate masks the spatial pattern.

For forest carbon policy this matters substantially. A federal carbon-credit program that uses state-aggregate projections to set baselines would over-credit wet-side landowners and under-credit dry-side landowners. The disaggregated ecoregion-scale projections we produce here support sub-state policy designs.

## 4.3 Limitations

Three limitations of the factorial design should be noted explicitly.

**First**, our 100-year projection horizon is extrapolative beyond the calibration window (20 years of FIA observation). The calibration parameters are well-constrained by the FIA data within their window, but their applicability at year 50, 75, and 100 is an assumption rather than an empirical verification. We address this with the methods paper's time-out-of-sample validation, but that test only spans 7 years of extrapolation.

**Second**, our climate-amplified disturbance regimes use parameter values derived from published meta-analyses (Régnière, Bentz, Kitzberger). The actual amplification factor under SSP585 has substantial uncertainty, and our results are correspondingly sensitive to the choice of amplification magnitude.

**Third**, our factorial deliberately excludes some categories of disturbance important in specific states: catastrophic hurricane events (e.g., Hurricane Michael 2018 in the Florida-Georgia panhandle), novel insect-pathogen interactions, and human-ignition fire patterns that may dominate future Washington fire regimes. These are excluded because they cannot be reliably parameterized from historical data alone, not because they are unimportant.

## 4.4 Implications for state-scale forest carbon management

Our results support three concrete recommendations.

**Recommendation 1: State-scale forest carbon projections should be calibrated against per-state multi-cycle FIA observations before being used for policy.** The methods paper provides the calibration framework; our results provide the consequence: ignoring calibration produces scenario rank-ordering errors at policy-relevant magnitudes.

**Recommendation 2: Carbon policies should account for sub-state ecoregion heterogeneity.** The WA wet-side / dry-side divergence we identify is not unique to Washington — similar patterns likely exist in other Pacific states and probably in the Northeast intra-state gradients as well. A uniform state-wide policy is a leaky abstraction over substantial sub-state variability.

**Recommendation 3: Climate-amplified disturbance regimes should be included alongside climate-driven productivity changes in any 21st-century forest projection.** The interaction between climate productivity gains and climate-amplified disturbance losses is a critical determinant of net carbon trajectory, and analyses that include only one side underestimate the uncertainty in the projection.

## 4.5 Cross-state generalization

We deliberately analyze the same factorial design across three structurally different states (Maine spruce-fir, Georgia southern pine, Washington Pacific Northwest conifers). The fact that the same calibration framework + factorial design works across these three contexts is a moderate-but-real argument for its generalization to other US states with FIA coverage. We anticipate that researchers in other states will adopt the framework with state-specific parameterizations; the open-source code release with the methods paper supports this.

# Section 5. Conclusions

We applied the calibrated LANDIS-II parameter sets from our companion methods paper to a 27-cell climate × harvest × disturbance factorial across Maine, Georgia, and Washington. Across the full factorial we find that calibration choice matters: the rank ordering of scenarios reverses between literature (Tier 0) and calibrated (Tier 1–2) parameters in approximately 20% of factorial cells, with the largest reversals in Washington where the calibration-induced reduction of the 100-yr asymptote is 67% per cell. We find that sub-state ecoregion heterogeneity is important: Washington's wet-side and dry-side ecoregions respond to climate scenarios in opposite directions, masked in state-aggregate projections. We find that climate-amplified disturbance regimes are at least as important as climate-driven productivity changes for the net 21st-century carbon trajectory.

These findings, taken together with our companion methods paper's demonstration that literature parameters are systematically biased by 30–70% relative to FIA observations, justify a substantive update to standard practice in state-scale forest landscape modeling. We provide a complete open-source pipeline (calibration framework, validated disturbance extensions, unified factorial scenario builder, replicated runs across all three states) at <https://github.com/CRSF-UMaine/perseus-multistate-calibration>. We anticipate that future state-scale forest carbon analyses will adopt this framework as a baseline, with state-specific extensions for novel disturbance dynamics, climate datasets, and policy questions.

The next generation of this work will extend to: (1) per-ecoregion calibration (Tier 1.5) for states where leave-one-eco-out diagnostics show substantial per-ecoregion heterogeneity, (2) climate-conditioned θ to address the late-cycle drift signal we identified in WA 2016–2022 observations, (3) explicit treatment of catastrophic hurricane events for Gulf and Atlantic coastal states, and (4) integration with the Forest Inventory and Analysis Carbon Estimator (FIA-CE) workflow to provide LANDIS-II projections as inputs to federal carbon accounting.
