# Harmonized session handoff — 2026-06-07g

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-07f
**Focus:** first real LANDIS output through the harmonized pipeline, and the plot-linkage finding that scopes the next step.

---

## 1. LANDIS adapter built and validated

`harmonized/landis_adapter.R` converts per-plot LANDIS output to the common schema. It reads `runs/plot_*/biomass_trajectory.csv` (plot_id, year, TotalBiomass_gm2), maps plot_id to plt_cn via `perseus/plot_ics_full/_summary.csv`, and converts units: agc_MgC_ha = TotalBiomass_gm2 * 0.01 (g/m2 to Mg/ha) * 0.5 (carbon fraction). Output: model, scenario, PLT_CN, year (calendar 2025 to 2100), agc_MgC_ha.

WA validation: 1,351 of 1,354 plots resolved, year-0 mean 90.7 Mg C/ha, which matches the FIA design density for WA (~92 Mg C/ha). Six states have these per-plot runs (WA, MN, WI, MI, IN, OH); ME and GA do not.

## 2. First real LANDIS harmonized output

WA reserve (no harvest, current climate) painted and anchored: `harmonized/harmonized_WA_landis.csv`. Anchored to the FIA design total at year 0 (818.67 +/- 8.27 Tg C) and projecting to 1,976 Tg C by 2100, roughly +141% over 75 years under no harvest, plausible for unharvested PNW forest. The full chain (adapter to painter to anchor-rescale to SE) runs end to end on real model output.

## 3. Key finding: LANDIS-to-TreeMap plot linkage (scopes the next step)

The paint-by-CN join has low coverage as currently keyed, and diagnosing it precisely is the main result of this session.

Raw CN match: only 48 of 1,351 WA LANDIS plots. The CNs differ by inventory cycle: LANDIS CNs end in 010497, TreeMap CNs in 010661. Same physical plots, different measurement control numbers.

Physical-plot match (STATECD + COUNTYCD + PLOT, via ENTIRE_PLOT.csv): 447 of 1,351 (33%). This is the correct join key and lifts coverage, but the remaining gap is structural: TreeMap imputes pixels from its own donor-plot pool, and LANDIS's calibration plots overlap that pool only partially.

Implication for the architecture. To paint TreeMap completely and keep the comparison apples-to-apples, the common plot universe should be the TreeMap donor plots per state, and every model (LANDIS included) should be run on that universe, joined on physical plot identity rather than raw CN. The harmonized anchored trajectories already shown are valid in shape and level (the FIA anchor fixes the level), but the painted spatial coverage and any non-anchored absolute totals are partial until the plot universe is aligned.

## 4. Next steps (priority order)

1. Define the common plot universe as the TreeMap donor set per state (the CNs in plt_area_treemap, mapped to physical plots), and add a physical-plot join (STATECD_COUNTYCD_PLOT) to `treemap_paint.R` / `harmonized_aggregate.R` in place of the raw-CN join.
2. Run LANDIS (and each model) on that donor universe so painting coverage is complete; for plots a model did not run, impute from the most similar run plot within the same ecoregion or forest type.
3. Run the three remaining LANDIS scenarios (BAU, conservation, intensive) per plot with the HCS per-state harvest rate, to complete the four-scenario set beyond reserve.
4. Bring FVS, CEM, CBM, yield curves onto the same donor universe and schema.
5. Finer time resolution: rerun LANDIS output at 5-year intervals to match the harmonized step (current per-plot output is 25-year).

## 5. Files created or changed this session

Repo: `harmonized/landis_adapter.R`, `harmonized/harmonized_WA_landis.csv`, `harmonized/harmonized_landis_6state.csv` (WA only, illustrates the coverage issue), `docs/SESSION_HANDOFF_2026-06-07g.md`. Cardinal: `FIA/landis_adapter.R`, `FIA/landis_{WA,MN,WI,MI,IN,OH}_reserve.csv`, `FIA/xwalk_test.R` (physical-plot coverage test), `FIA/submit_landis_harm.slurm`.
