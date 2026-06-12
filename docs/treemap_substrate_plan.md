# Harmonized assessment: single TreeMap substrate via plot-CN painting

**Date:** 2026-06-07
**Supersedes:** the dual-initialization design in `dual_initialization_plan.md` (kept for record). Decision: one spatial substrate (TreeMap), all models run per FIA plot and painted onto the landscape by plot CN.

## 1. The architecture in one paragraph

Every model is run once per FIA plot, producing a per-hectare trajectory keyed by the plot control number (PLT_CN). TreeMap imputes an FIA plot to every 30 m pixel of CONUS, so each plot CN already represents a known landscape area. Multiplying a plot's per-hectare output by the TreeMap area it represents, then summing over any domain, paints the plot-level results onto the landscape and aggregates them to state, county, EPA Level III ecoregion, or FIA hex. No model is ever run spatially; the spatial structure comes entirely from TreeMap's plot-to-pixel imputation. This is the same mechanism FVS already used (`fvs_treemap_vs_fiadb.csv`) and it generalizes to all five models.

## 2. Why this resolves the blockers

It dissolves the LANDIS statewide initial-communities blocker completely. LANDIS runs on the proven per-plot pipeline (FIA tree-list IC), and its outputs are painted via CN like every other model. There is no need to build a statewide Universal-format raster IC. The earlier segfaulting statewide-raster path is abandoned in favor of paint-by-CN.

It unifies all five models on one substrate. Yield curves, CBM, CEM, FVS, and LANDIS all run per FIA plot and paint through the same CN weights, so the spatial allocation is identical across models and any spatial difference between models reflects their plot-level dynamics, not different mapping choices.

It keeps the support honest. TreeMap pixels are not interpreted at 30 m; results are reported at the FIA hex and coarser, matching the inventory's information content, while still producing continuous maps.

## 3. The pieces, and their status

The painting weights exist CONUS-wide: `fvs_stress/plt_area_treemap.csv` gives PLT_CN to area_ha for 65,044 plots (TreeMap hectares imputed to each plot), and `me_treemap_donors.csv` is the TM_ID to PLT_CN raster linkage for pixel-level maps. The shared painter is built and validated: `harmonized/treemap_paint.R` takes any per-plot per-ha table keyed by PLT_CN and aggregates to a domain. ME validation painted 2,008 plots to 316 Tg C over 6.9 M ha (45.8 Mg C/ha); the area matches FIA Maine forest area closely, confirming the mechanism.

The FIA anchor and truth set: the design-based EVALIDator estimator is validated (`fia_design_estimate.R`, ME 374 Tg C, WA 819, RI 12.8) and the assignment tables are downloading for all 48 states. The painted plot-level FIA carbon and the design EXPNS total are two views of the same forest; their small difference quantifies how TreeMap area allocation departs from the FIA design, which is a documented property of the substrate rather than an error.

The harvest driver (HCS per-state rate) and the four-scenario protocol are fixed. Ecoregion aggregation needs a PLT_CN to ECO_L3 crosswalk; `sf` is installing now to build it from `us_eco_l3.shp` and plot coordinates. Alternatively, since painting is pixel-aware through the TM_ID raster, ecoregion totals can be produced by overlaying the ecoregion raster on the painted surface without per-plot assignment.

## 4. Pipeline

1. Plot-level model runs. Each model emits, per FIA plot CN, a per-hectare live AGC trajectory (2025 to 2100 by 5) under each of the four scenarios at current climate, harvest from the HCS per-state rate times the scenario multiplier, rescaled to the FIA year-0 anchor. LANDIS uses its per-plot pipeline; CBM and yield curves are FIA-native; CEM is extending now; FVS already runs this way.
2. Paint. Join each model-scenario-year per-plot table to `plt_area_treemap.csv` on PLT_CN and weight by area_ha.
3. Aggregate. Sum to state, county, ecoregion, and hex with `treemap_paint.R`. Per-ha equals painted total over painted area.
4. Anchor and check. Confirm year-0 painted AGC per state matches the design FIA anchor within tolerance; apply the rescale; run the acceptance gate.
5. Report. Model-by-scenario trajectories and 2100 stocks at each spatial resolution, plus continuous maps at hex support via the TM_ID donor raster. The headline is the cross-model spread under identical inputs.

## 5. Remaining dependencies (all in motion or minor)

The 48-state assignment-table pull is running, after which the design anchor runs CONUS-wide and gets a one-state EVALIDator cross-check for certification. `sf` is installing for the ecoregion crosswalk. The one design choice to settle with the team is how each FIA-native model (yield curves, CBM) emits a per-plot per-ha trajectory consistent with the others, since their native output is not always per-plot; the painter requires only a PLT_CN keyed per-ha value, so each model needs a thin adapter to that schema.

## 6. What changed from the prior plan

The dual FIADB-versus-TreeMap initialization comparison is dropped. TreeMap is the sole substrate; FIADB remains the statistical truth set and year-0 anchor, not a parallel initialization. This is simpler, removes the need to construct artificial TreeMap initializations for FIA-native models, and still yields spatially explicit CONUS projections at defensible support.
