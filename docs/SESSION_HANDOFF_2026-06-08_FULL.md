# Harmonized cross-model assessment — FULL state handoff (2026-06-08)

**Repo:** github.com/holoros/landis2HPC (harmonized work in `harmonized/`, docs in `docs/`)
**Cardinal:** OSC, project PUOM0008. Scratch root `/fs/scratch/PUOM0008/crsfaaron`.
**Purpose:** consolidated state of the apples-to-apples multi-model, multi-criteria forest assessment.

---

## 1. Architecture (locked)

One spatial substrate: TreeMap. Every model is run per FIA plot, and TreeMap's plot-to-pixel imputation paints plot-level results onto the landscape, aggregated to state/county/ecoregion/hex. FIADB is the statistical truth set and year-0 anchor, not a parallel initialization. The harmonized comparison holds climate at "current" and varies management (reserve, conservation, BAU, intensive); climate is a separate capability-restricted sensitivity. Plot linkage is by physical plot identity (STATECD_COUNTYCD_PLOT), not raw control number, because sources carry different inventory-cycle CNs. Full design: `docs/treemap_substrate_plan.md`, `docs/dual_initialization_plan.md` (superseded), `docs/multicriteria_metrics_framework.md`.

## 2. Shared foundations (complete)

HCS per-state harvest rates, 48 states (`harmonized/hcs_harvest_rate_by_state.csv`). FIA design-based year-0 anchor with standard errors, 48 states, EVALIDator-mirroring estimator (`harmonized/fia_design_estimate.R`, `harmonized/fia_agc_anchor_design_by_state.csv`; CONUS 15.28 Pg C, per-state CV ~1% large states to ~7% sparse). CN-to-physical-plot crosswalk (`FIA/cn2pid.csv`, ~2M rows). TreeMap painter (`harmonized/treemap_paint.R`) and the aggregation/rescale/acceptance layer with SE propagation (`harmonized/harmonized_aggregate.R`). Multi-resolution FIA estimator for state/county/ecoregion (`harmonized/fia_domain_estimator.R`).

## 3. Harmonized scenario + metric machinery (complete)

`harmonized/apply_harvest_scenarios.R` applies deterministic expected-value harvest to an anchored reserve trajectory and computes, per scenario: forest carbon, HWP carbon (first-order pool, long/short in-use + landfill), total carbon, and timber NPV (from the same removals, at 3% and 5%). `harmonized/lsog_proxy.R` adds a biomass-threshold LSOG proxy. Scenario multipliers reserve 0, BAU 1, conservation 0.6 (partial), intensive 2 (clearcut). Harvest driver is the calibrated HCS per-state rate (not the raw 0.65 to 0.98 propensity raster, which is uncalibrated).

## 4. LANDIS status

Calibrated statewide per-plot projections: WA and MN complete (1354/1354, 1147/1147). IN, OH, WI, MI were stuck partial because the statewide plotlist included plots with no per-plot IC csv (`build_plot_scenario` failed silently on them). Fixed this session: `run_statewide_buildfresh.sh` now filters the plotlist to IC-having plots; the four drivers were resubmitted (jobs 11387312-15) and are running (OH array ~84 tasks active). ME and GA have no per-plot runs at all and need their statewide runs built.

Second LANDIS fix (root cause of the IN/OH/WI/MI shortfall): array tasks were hitting the 20-minute wall under %150 concurrency and leaving header-only trajectory stubs, and the runner's skip check (`[ -f trajectory ]`) treated those stubs as complete, so resubmits never retried them. LANDIS itself runs fine per plot (verified: 567 biomass tifs on a WI plot). Fixed `run_statewide_buildfresh.sh`: skip check now requires a data row (`wc -l > 1`), per-task wall time raised to 1 h; 1,054 header-only stubs deleted; drivers resubmitted (11395435-38). These should finally complete IN/OH/WI/MI, after which the six-state harvest (per-ha anchoring) runs cleanly.

State-level reserve now uses plot-mean per-ha anchored to the FIA total (`build_landis_reserve_perha.R`), not painted donor-subset aggregation; this removes a donor-selection bias, uses all of each state's plots, and drops the painting dependency (painting reserved for sub-state maps). It also lets WI/MI in (their plots resolve in cn2pid but did not overlap TreeMap donors). Refreshed de-biased 2100 totals (reserve): MN 838, OH 768, IN 565, WA 1371 Tg C; harvest ordering and HWP offset unchanged. WI and MI await the running drivers (their run dirs are mid-rewrite); re-harvest all six when the jobs finish.

Multi-criteria results exist for WA, MN, IN, OH (`harmonized/harmonized_carbon_npv_4state.csv`, `harmonized_lsog_proxy_4state.csv`, trajectories in `harmonized_landis_4scenario.csv`). Example, 2100 reserve to intensive: total carbon falls (MN 704 to 551 Tg with HWP), timber NPV rises (MN $0 to $202/ha at 5%), LSOG proxy falls (MN 0.56 to 0.43). HWP recovers ~20 to 25% of harvest-driven forest carbon loss. WA is nearly flat on all axes because its HCS rate is ~0.01%/yr. Caveats: IN/OH rest on sparse painted coverage (improving with the resubmit); LSOG is a biomass surrogate for age.

## 5. FVS status (RESOLVED)

FVS is now harmonized for all 48 states. The clean input is the per-stand FVS reserve densities `fvs_stress/out_gompit_v3/conus_*.csv` (STAND_CN, STATE, YEAR, CONFIG, AGB_TONS_AC; gompit config), not the partial treemap summary. `build_fvs_reserve_v2.R` builds state-mean per-ha carbon (AGB_TONS_AC x 2.2417 x 0.5), anchors year-0 to the FIA design total, and feeds `apply_harvest_scenarios.R`, so FVS runs the same common harvest as LANDIS. Output: `harmonized/harmonized_fvs_carbon_npv.csv` (48 states, carbon+HWP+NPV, 4 scenarios). FVS's native managed runs (`managed_calibrated/managed_<ST>.csv`) exist as a cross-check but use FVS's own harvest, not the common protocol.

FIRST CROSS-MODEL RESULT (`harmonized/harmonized_crossmodel_LANDIS_FVS.csv`): both anchored to the same FIA year-0, so 2100 divergence is pure model structure. 2100 total carbon (forest+HWP), LANDIS vs FVS: IN 565 vs 313, MN 838 vs 387, OH 768 vs 511, WA 1371 vs 2272 Tg C. The models disagree by ~2x and the direction flips (LANDIS higher in the East/Lake States, FVS far higher in the Pacific Northwest); scenario ordering holds in both. This structural divergence under identical inputs is the headline the harmonized design exists to quantify.

## 5b. FVS status (prior, superseded)

FVS has a CONUS projection painted to TreeMap and FIADB-validated across all 48 states plus forest-type and CONUS aggregates at 2030/2075/2125 (`fvs_stress/treemap_conus/fvs_treemap_vs_fiadb.csv`, ratios ~0.95 to 1.14). This is strong coverage but is NOT directly harmonizable: the `treemap_TgC` series is partial-coverage (WA reads 186 Tg at 2030 vs the 819 Tg FIA anchor) and shows non-physical growth when anchored (WA reserve inflated to ~4,800 Tg by 2100). The attempt this session (`harmonized/build_fvs_reserve.R` plus the apply step) is therefore INVALID and should not be used; the `FIA/harmonized_fvs_*.csv` and `fvs_reserve_anchored.csv` are quarantined as bad.

Clarified this session: the `treemap_vs_fiadb` columns are both FVS reserve carbon under two spatial allocations (TreeMap-spatial vs FIADB-uniform), not FVS-vs-FIA. Correct path for FVS: harmonize from a per-plot FVS carbon-BY-YEAR trajectory (per-plot to paint to anchor, exactly as LANDIS), not from this aggregate. That trajectory does NOT currently exist as a file: `fvs-conus/output/conus` holds FVS model-component fits (crown ratio, diameter and height growth, ingrowth, the gompit remodeling), `fvs-conus/runs` holds the fit runs, and `plt_area_treemap.csv` carries only a single year-0 `tm_carbon_L` per plot. So the per-plot FVS carbon trajectory must be extracted from the FVS run engine or regenerated (an FVS CONUS projection run that writes carbon per plot per cycle). The `treemap_vs_fiadb` summary remains useful only as a spatial-allocation benchmark. The quarantined `harmonized_fvs_*` outputs from the naive attempt are invalid.

## 6. Other models (running)

CEM is extending to CONUS (a `cem_rerun` array is active). Yield curves are fitting (`ycx_hfit4`). CBM is FIA-native and pending a per-plot per-ha adapter. None has yet produced the four harmonized scenarios through the common pipeline.

## 7. Key files

Scripts (`harmonized/`): fia_design_estimate.R, fia_domain_estimator.R, treemap_paint.R, harmonized_aggregate.R, landis_adapter.R, apply_harvest_scenarios.R, lsog_proxy.R, extract_hcs_plot_prob.R, build_fvs_reserve.R (FVS path needs the per-plot fix). Data (`harmonized/`): hcs_harvest_rate_by_state.csv, fia_agc_anchor_design_by_state.csv, harmonized_carbon_npv_4state.csv, harmonized_lsog_proxy_4state.csv, harmonized_landis_4scenario.csv. Docs (`docs/`): treemap_substrate_plan.md, multicriteria_metrics_framework.md, CONUS_rollout_roadmap_v2.0.md, and the dated session handoffs.

## 8. Open decisions

Monetize carbon in a net NPV or keep carbon and dollars separate (currently separate, recommended). Headline discount rate (3 and 5% carried). Real regional stumpage to replace the synthetic placeholder (southern pine ~22-25, hardwood ~16-35, PNW Douglas-fir ~42-55 $/ton). HWP storage-only versus a substitution credit. LSOG age and structure thresholds. Whether to commit the metrics-output LANDIS rerun (CohortStats, per-species biomass, habitat extensions) that unlocks age-based LSOG, biodiversity, and habitat.

## 9. Next steps (priority order)

1. Let the IC-filtered IN/OH/WI/MI drivers finish; re-harvest the LANDIS multi-criteria table across all completed states; fix the WI/MI zero-paint (cn2pid resolution for MN-family CNs).
2. Locate or generate per-plot FVS carbon output and harmonize FVS through the per-plot to paint to anchor pipeline (the summary file is not usable for this).
3. Build ME and GA statewide runs.
4. Commit the metrics-output rerun to unlock age-based LSOG, biodiversity, and habitat.
5. Replace synthetic stumpage with real regional series; refit and regenerate economics.
6. Bring CEM, CBM, yield curves onto the common pipeline, then assemble the cross-model multi-criteria comparison and tradeoff frontier.
