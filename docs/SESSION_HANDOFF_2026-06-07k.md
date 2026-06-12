# Harmonized session handoff — 2026-06-07k

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-07j
**Focus:** located the 30 m HCS harvest-probability rasters, built the per-plot harvest driver, and found the value-calibration issue that gates the harvest scenarios.

---

## 1. HCS 30 m harvest rasters located

`conus_hcs/output/phase5_v1/` holds the harmonized harvest driver (hcs_phase5_v1), on the TreeMap 2016 grid at 30 m: `p_harvest_any_TM2016_v1.tif`, `p_harvest_partial_TM2016_v1.tif`, `p_harvest_clearcut_TM2016_v1.tif`. terra and sf are installed (the earlier batch install succeeded), so raster sampling and the ecoregion crosswalk are both unblocked.

## 2. Per-plot harvest driver built and run

`harmonized/extract_hcs_plot_prob.R` samples the three rasters at each FIA plot location (reproject plot lon/lat to the raster CRS, terra::extract). Run for WA, MN, IN, OH, WI, MI; output `plot_hcs_prob.csv` (~26k plots: state, PLT_CN, lon, lat, p_any, p_partial, p_clearcut).

## 3. KEY FINDING: the raster values are propensity, not usable probability

The `p_harvest_any` raster ranges 0.655 to 0.981 (even the minimum is 0.66, mean among sampled plots ~0.9). That cannot be a 10-year harvest probability; it would imply two-thirds or more of all forest harvested per window, versus the ~1 to 2 %/yr the calibrated per-state HCS rates show. The raster is a propensity/suitability surface, and `hcs_harvest_rate.py` is what converts it to an actual rate (rate = sum(p * pixel_ha)/obs_window/forest_ha). Using the raw 0.9 to drive Biomass Harvest would harvest nearly everything. So the per-plot harvest must be driven by a CALIBRATED rate, not the raw propensity.

Recommended approach: drive per-plot harvest with the already-computed calibrated rate (`hcs_harvest_rate_by_state.csv`, per-state, or a per-ecoregion version), scaled by the scenario multiplier (BAU 1x, conservation 0.6x partial, intensive 2x clearcut). The 30 m propensity raster is then used only to allocate WHERE harvest falls within a domain (spatial pattern), with the calibrated rate setting HOW MUCH. This matches the harmonized config, which already names the per-state rate as the driver.

Also: IN returned NaN and the first WA plots are NaN, so the v1 raster has partial coverage / nodata at some plot locations; needs a nodata and extent check (and possibly the phase5 non-v1 raster as fallback).

## 4. Open design decision: per-plot harvest representation

The per-plot LANDIS landscape is one cell, and the builder currently wires no harvest (Biomass Succession + Output Biomass only). Two defensible ways to represent harvest at the plot scale, a genuine method choice for the next session:
1. Stochastic Biomass Harvest: each plot, per timestep, draws against the calibrated rate; clearcut or partial per the scenario prescription. The ensemble across painted plots reproduces the domain rate. Most faithful to LANDIS; more wiring.
2. Expected-value removal: reduce each plot trajectory by the expected harvested biomass per step from the calibrated rate and prescription. Simpler, deterministic, easier to reconcile with the harmonized rate exactly.

## 5. Donor constraint guidance (recorded for the coverage step)

For painting the unrun TreeMap donor plots, donors should be drawn from the same or a neighboring state or ecoregion, casting a wider net only if no near match exists. This bounds the imputation geographically (a Lake States plot is imputed from Lake States, not from the Southeast) while still guaranteeing a donor. To implement in the painter: restrict the donor search to same-ecoregion-then-neighboring-state candidates, ranked by similarity (forest type, year-0 biomass), with a global fallback.

## 6. Status

Reserve harmonized table exists for four states (WA, MN, IN, OH; 06-07j). The harvest scenarios are blocked on (a) calibrating the harvest driver from propensity to rate (use the existing per-state rate), (b) choosing the per-plot harvest representation, and (c) resolving the raster nodata coverage. None should be run until the driver is calibrated, to avoid an over-harvest artifact.

## 7. Next steps (priority order)

1. Drive per-plot harvest with the calibrated per-state (or per-ecoregion) HCS rate x scenario multiplier, not the raw propensity raster; resolve raster nodata for IN and edge plots.
2. Choose the per-plot harvest representation (stochastic vs expected-value) and wire it into build_plot_scenario_{ST}.sh, then run BAU, conservation, intensive.
3. Implement the ecoregion/neighbor-constrained donor imputation in the painter for full coverage.
4. Re-harvest after the IN/OH/WI/MI statewide resumes finish; fix WI/MI zero-paint.
5. Bring FVS, CEM, CBM, yield curves onto the pipeline.

## 8. Files created or changed this session

Repo: `harmonized/extract_hcs_plot_prob.R`, `docs/SESSION_HANDOFF_2026-06-07k.md`. Cardinal: `FIA/extract_hcs_plot_prob.R`, `FIA/submit_hcs_extract.slurm`, `landis2/tools/plot_hcs_prob.csv` (~26k plots), resumed statewide drivers 11366734/35/36/37.
