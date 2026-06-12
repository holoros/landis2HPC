# Dual-initialization cross-model assessment: FIADB and TreeMap

**Date:** 2026-06-07
**Purpose:** flesh out the idea of running the harmonized assessment twice, once initialized from FIADB and once from TreeMap, so the comparison separates how much projected-carbon spread comes from model structure versus from the input data that initializes the models. Plus an assessment of where each component stands and a plan to get there.

## 1. The idea, stated as an experiment

The harmonized framework already removes every confound except the model: same scenarios, horizon, carbon fraction, forest area, harvest driver, and FIA anchor. That isolates one factor, model structure. Your proposal adds a second deliberately varied factor, the initialization data, turning the study into a clean two-factor design:

* Factor A, model: yield curves, CBM, CEM, FVS, LANDIS (5 levels).
* Factor B, initialization: FIADB (plot tree lists and the design-based estimate) versus TreeMap (the 30 m imputed-plot raster). (2 levels.)
* Held constant: the four Daigneault scenarios (reserve, BAU, conservation, intensive), current climate, the single HCS harvest rate, the FIA year-0 anchor, and per-ha live AGC as the output.

Running the full set, 5 models by 2 initializations by 4 scenarios, lets the projected-carbon variance be decomposed into a model main effect, an initialization main effect, and their interaction. The model main effect is the apples-to-apples result you already wanted. The initialization main effect answers a question the single-initialization design cannot: how much of the disagreement between forest-carbon models is really disagreement about the starting forest rather than about forest dynamics. The interaction tells you whether some models are more sensitive to input data than others.

This is worth doing because the field routinely attributes model disagreement to structure when much of it may be initialization. A model that starts from a TreeMap pixel inherits one imputed plot's species and size structure; the same model started from the design-based FIADB tree list for the same area starts from a statistically representative draw. If the two give very different 2100 carbon, the lesson is about data, not dynamics.

## 2. Why FIADB and TreeMap are the right two poles

FIADB is the statistically rigorous, plot-based truth with known design-based uncertainty, but it is not spatially continuous. TreeMap is spatially complete at 30 m but each pixel is a single imputed FIA plot, so it is precise-looking and statistically thin. They are the two honest end members of the initialization spectrum: maximum statistical rigor with no spatial continuity, versus full spatial continuity with attenuated statistical support. Your own constraint is the key: TreeMap is only defensible aggregated to roughly the FIA hexagon support (about one plot per 2,400 ha), not at the pixel. So the TreeMap arm should be aggregated to hexes before it initializes any model, which makes the two arms comparable in information content while still differing in spatial structure.

For LANDIS specifically this maps onto something concrete you have already hit. The per-plot LANDIS pipeline is initialized from FIA tree lists (the FIADB arm), and it works. The statewide-raster LANDIS path is initialized from TreeMap and is currently blocked on building a Universal-format statewide initial-communities file. The dual-initialization design is therefore not extra work bolted on; it is the explicit, principled version of the two initialization paths LANDIS already straddles.

## 3. Where each component stands today

The shared spine is mostly built. The harmonized scenario protocol is fixed in `harmonized_scenarios.yml`. The single HCS harvest driver is computed and consolidated for all 48 states (`hcs_harvest_rate_by_state.csv`). The FIA anchor exists in two forms: an interim per-acre-times-area table for all 48 states, and now a design-based EVALIDator-mirroring estimator validated on ME, WA, RI (`fia_design_estimate.R`). The design estimator is the publication path and is the FIADB arm's truth set. The plot-to-stratum assignment tables that the design estimator needs are downloadable onto Cardinal one state at a time (confirmed for RI, ME, WA); a full 48-state pull plus a digit-for-digit check against published EVALIDator output is the remaining QA.

The estimation framework spans the three spatial domains you want, state, county, and EPA Level III ecoregion, in `fia_domain_estimator.R`. State and county run now; ecoregion needs a plot-to-L3 crosswalk built with `sf` against `us_eco_l3.shp`, and `sf` is not yet installed on Cardinal.

The models are at very different stages. CEM is mid-CONUS-extension right now (the `cem_conus` array is running). LANDIS is calibrated for eight states and its scenario generator is patched, but no LANDIS scenario has completed because the statewide-raster initial-communities path is blocked; the per-plot (FIADB) path is the proven one. CBM, FVS, and yield curves still need confirmation that they emit the common schema under the shared anchor and harvest. None of the five has yet been run under the harmonized protocol end to end, and none has been run under both initializations.

TreeMap exists on Cardinal and there are prior FIADB-versus-TreeMap comparisons (`FIA/Output`, `ME_AGB_Map_Comparison`, `fvs_stress/treemap_conus`) that are the calibration evidence for the hex-aggregation step.

## 4. Aligning the planned LANDIS projections with the framework

The current LANDIS factorial is 3 climate by 4 harvest with flat literature harvest rates. To align it with the harmonized framework it should become four management scenarios at current climate, with harvest taken from the HCS per-state rate scaled by the scenario multiplier (reserve 0, BAU 1, conservation 0.6 with clearcut-to-partial, intensive 2 with clearcut emphasis), and output rescaled to the FIA year-0 anchor as per-ha live AGC. Climate moves to the separate, capability-restricted sensitivity layer. Each LANDIS scenario then runs twice: the FIADB arm from per-plot FIA tree lists aggregated to the state or domain, and the TreeMap arm from the hex-aggregated TreeMap initial communities. The latter is what finally motivates building the statewide Universal-format IC, now with a clear scientific purpose rather than as a generic capability.

## 5. Plan to get there

Phase 1, finish the shared spine. Pull the remaining POP_PLOT_STRATUM_ASSGN tables, run the design estimator for all 48 states, and cross-check one or two states against published EVALIDator carbon to certify the FIADB anchor. Install `sf`, build the plot-to-L3 crosswalk, and produce state, county, and ecoregion anchors. Define the TreeMap-to-hex aggregation and validate it against the existing FIADB-versus-TreeMap comparisons; this produces the TreeMap arm's initialization at defensible support.

Phase 2, stand up the harmonized aggregation layer. One tidy table keyed by model, initialization, state or domain, scenario, and year, carrying per-ha live AGC, removals, and stand age, with the anchor rescale applied and the acceptance checks automated. Build it so every model writes into the same schema.

Phase 3, run one model under both initializations on a pilot region. LANDIS on the eight calibrated states is the natural pilot because its two initialization paths already exist. Run the four scenarios from the FIADB per-plot initialization and from the hex-aggregated TreeMap initialization, and read the initialization main effect directly. This proves the two-factor design end to end before scaling.

Phase 4, bring the other four models into both arms. CEM (extending now), CBM, FVS, and yield curves each run the four scenarios under both initializations, writing the common schema. Some models will need an initialization adapter; yield curves and CBM are essentially FIADB-native and may need a TreeMap-derived starting state constructed for the TreeMap arm.

Phase 5, decompose and report. Fit the model-by-initialization-by-scenario decomposition of 2100 carbon, report the model main effect (the apples-to-apples result), the initialization main effect (the input-data result you are after), and the interaction. Map the national and regional gradients at state, county, and ecoregion, with TreeMap providing the within-domain spatial allocation at hex support.

## 6. Honest blockers and dependencies

Three external or setup items gate the rigorous version, all small and all flagged before: the full POP_PLOT_STRATUM_ASSGN pull plus an EVALIDator cross-check to certify the FIADB anchor; an `sf` install to unlock the ecoregion domain; and a statewide Universal-format initial-communities build for the LANDIS TreeMap arm. The deeper design question to settle with the team is how to construct a defensible TreeMap-based initialization for the models that are FIADB-native (yield curves, CBM), since for those the TreeMap arm is not automatic and its construction is itself a modeling choice that should be documented so it does not silently become another hidden assumption.
