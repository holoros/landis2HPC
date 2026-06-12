# Multi-criteria metrics for the harmonized assessment: carbon, economics, ecosystem services

**Date:** 2026-06-08
**Purpose:** extend the harmonized cross-model assessment from carbon alone to a metric vector covering economics (NPV / stumpage) and ecosystem services (LSOG, habitat quality, biodiversity), resolve the open NPV/stumpage questions, and specify what each metric needs from the pipeline.

## 1. Where carbon stands (reference)

Live aboveground carbon is the headline metric, FIA-anchored per state with design standard errors, four scenarios (reserve, conservation, BAU, intensive) computed for LANDIS (WA, MN, IN, OH so far). Every other metric below attaches to the same model x scenario x domain x year spine and is painted onto TreeMap by plot CN.

## 2. Economics: NPV and stumpage (questions resolved)

The economic layer already exists and does not need rebuilding. `ecoregion_npv_by_rate.csv` (79 EPA Level III ecoregions x 4 scenarios) carries, per ecoregion and scenario, annual timber revenue, annual carbon value change, annual cost, area, and NPV of revenue and of net (timber plus carbon) at discount rates 0.03, 0.05, 0.07, and 0.10. It is built by `cbm_conus/10_economics/02_npv.R` from a stumpage panel (`conus_hcs/outputs/phase1_partial_conus/synthetic_stumpage_panel.csv`) imputed by `conus_hcs/models/stumpage_imputation.qs`. The scenario names align exactly with the harmonized set (reserve, managed conservation, managed harvest = BAU, managed intensive).

Three questions are resolved as follows.

Revenue versus net. `npv_rev` is timber stumpage revenue only; `npv_net` subtracts the carbon value change (the `ann_carbon` column, negative under harvest because standing carbon is drawn down). So `npv_net` already monetizes the carbon-timber tradeoff. The team should decide whether to report a monetized net at all, or to keep carbon (physical, Tg C) and NPV (timber, dollars) as separate axes, which avoids embedding a social cost of carbon and lets readers weigh the tradeoff. Recommendation: report timber NPV and physical carbon separately as the primary result, and show the monetized net only as a sensitivity with the assumed carbon price stated.

Discount rate. Four rates are already carried. Recommendation: headline 0.03 and 0.05 (the policy-relevant range), with 0.07 and 0.10 as sensitivity, matching the Daigneault framing.

Stumpage prices (the real open question). The panel is explicitly synthetic ("SYNTHETIC public Q4 2025 anchor"), a 2005-anchored series in 2020 USD per cubic meter, split by product (saw, pulp), species group, and state. Current real stumpage benchmarks for 2024 to 2025: southern pine sawtimber about 22 to 25 USD per ton (down from a ~26 plateau), hardwood sawtimber about 16 to 35 USD per ton (volatile; South Carolina Q2 2025 near 16), and Pacific Northwest Douglas-fir roughly 42 to 55 USD per ton. The synthetic southern-pine value (16.1 per ton, 2005) is a plausible base given inflation, but two corrections are needed before publication: replace the synthetic series with a real regional series (TimberMart-South for the South, state extension quarterly reports for the East and Lake States, Washington DNR and Oregon for the Pacific Northwest), and ensure the strong regional differential is preserved, since PNW conifer stumpage runs roughly two to three times southern pine. Until then the synthetic panel is a defensible placeholder for relative scenario comparison but not for absolute dollar claims.

Integration. NPV attaches to the harmonized scenario table by joining `ecoregion_npv_by_rate` to each state through its L3 ecoregions (area-weighted per-ha NPV aggregated to state), keyed by scenario. The LANDIS removals that drive revenue come from the same expected-value harvest flux already used for the carbon scenarios, so the economic and carbon results are internally consistent.

## 3. Ecosystem services: LSOG, habitat, biodiversity

These share one dependency that the current pipeline does not yet retain: stand age and species structure. The build-fresh runner extracts only total biomass per plot and deletes the per-species and cohort outputs. The container does provide the needed extensions (Output CohortStats for age and richness, Output Biomass per species, Output MaxSpeciesAge, and the WildlifeHabitat and LocalHabitat extensions). So the ecosystem-service metrics require a metrics-output rerun that enables and retains those, then extracts age-class, richness, and structure trajectories per plot and paints them like carbon.

Late-successional and old-growth (LSOG). Define LSOG as the fraction of forest area in a late-successional or old-growth condition, by a stand-age threshold (regionally set, for example greater than 120 to 150 years) combined with a large-tree structural criterion (biomass or quadratic mean diameter above a regional cutoff). A biomass-threshold proxy is computable now from the existing per-plot biomass trajectory (fraction of painted area above a late-successional biomass level), which gives a first LSOG signal and the expected scenario ordering (reserve highest, intensive lowest). The rigorous version needs the cohort-age output from the metrics rerun.

Biodiversity. Use tree species richness and a Shannon diversity index per plot, area-weighted to the domain, plus optionally a functional or structural diversity measure. Initial (year-0) richness is available now from the IC summary (species present per plot in `plot_ics_full/_summary.csv`). Projected richness through time needs the per-species biomass output, which is the metrics rerun. Harvest scenarios affect richness through composition shifts and the loss of late-successional associates, so the dynamic version is where the cross-scenario signal lives.

Habitat quality. Habitat is intrinsically multi-species, so define a small set of focal indicators rather than one index: a late-successional or interior-forest associate (favored by reserve), an early-seral or edge associate (favored by intensive harvest), and a generalist. Build habitat suitability from structure (age and size class), composition (host species presence), and dead wood, using the WildlifeHabitat or LocalHabitat extension outputs. This deliberately shows that no single scenario maximizes all habitat values, which is the point of a multi-criteria assessment.

## 4. The metric vector and the tradeoff frontier

Per model x scenario x domain x year, the target output vector is: live AGC (Mg C/ha, FIA-anchored, with SE), harvest removals (m3/ha/yr), timber NPV (dollars/ha, by discount rate) and optionally monetized net, LSOG fraction, species richness or Shannon diversity, and the focal habitat suitabilities. The headline product is the cross-scenario tradeoff: carbon and LSOG and interior-habitat decline from reserve to intensive while timber NPV and early-seral habitat rise, and the cross-model spread under identical inputs frames the uncertainty on each axis. This is the multi-criteria version of the apples-to-apples comparison.

## 5. What is computable now versus what needs a rerun

Now, from existing outputs: carbon (done), removals and timber NPV (from the existing harvest flux and `ecoregion_npv_by_rate`), an LSOG biomass-threshold proxy, and initial-year biodiversity from the IC. Needs the metrics rerun (enable and retain CohortStats, per-species biomass, MaxSpeciesAge, habitat extensions): age-based LSOG, dynamic biodiversity, and habitat suitabilities. The metrics rerun is the single gating compute item for the full ecosystem-service suite, and it is a configuration change to the per-plot scenario builder plus a re-extraction, not new science.

## 6. Open decisions for the team

Whether to monetize carbon in a net NPV or keep carbon and dollars as separate axes (recommended separate, with monetized net as sensitivity). The headline discount rate. The real stumpage source per region and whether to refit `stumpage_imputation.qs` to it. The regional LSOG age and structure thresholds. The focal habitat species set. And whether to commit the metrics-output LANDIS rerun now (it roughly doubles per-plot output volume but unlocks LSOG, biodiversity, and habitat).

## 7. Next steps (priority order)

1. Replace the synthetic stumpage panel with real regional series (TimberMart-South, state extension, WA/OR DNR), refit the imputation, and regenerate `ecoregion_npv_by_rate`; keep the synthetic version as a labeled placeholder for relative comparison.
2. Join NPV to the harmonized scenario table (ecoregion to state, area-weighted) so carbon and economics sit side by side per scenario.
3. Add the LSOG biomass-threshold proxy to the harmonized table from the existing biomass trajectories.
4. Commit the metrics-output LANDIS rerun (CohortStats + per-species biomass + habitat extensions) to unlock age-based LSOG, dynamic biodiversity, and habitat suitability.
5. Assemble the per-scenario metric vector and the cross-scenario tradeoff frontier, then extend to the other models.

## Sources

- [Timber Situation and 2025 Outlook, UGA CAES Field Report](https://fieldreport.caes.uga.edu/publications/AP130-3-13/timber-situation-and-2025-outlook/)
- [Stumpage Price Trends in South Carolina Q2 2025, Clemson Extension](https://blogs.clemson.edu/fnr/2025/08/07/stumpage-price-trends-in-south-carolina-for-q2-2025-industry-update/)
- [TimberMart-South State Stumpage Prices](https://timbermart-south.com/resources/state-stumpage-prices/)
- [NC State Extension Forestry Price Data](https://forestry.ces.ncsu.edu/forestry-price-data/)
