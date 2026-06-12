# PERSEUS / harmonized session handoff — 2026-06-07

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-06
**Focus:** building the model-independent foundations for the harmonized cross-model assessment, plus a methodological decision on climate.

---

## 1. Design decision: climate is a sensitivity, not a core dimension

Agreed framing for the apples-to-apples assessment. The core comparison holds climate at "current" and varies only management (reserve / BAU / conservation / intensive) across all five models, because that is the only configuration where every model is capable and the spread reflects model structure rather than divergent climate or disturbance assumptions. Yield curves and CBM have no endogenous climate response or fire spread; CEM and FVS handle climate through different mechanisms; LANDIS disturbance is currently disabled. A climate-by-harvest-by-disturbance matrix would let assumptions dominate the result.

Climate (rcp45 and beyond) therefore belongs as a clearly labeled, capability-restricted sensitivity layer, run only on the subset of models that represent it (LANDIS, CEM, FVS), and reported separately, never blended into the core comparison. The config already treats `current` as headline and rcp45 as sensitivity; this formalizes it. Priority is to get each model calibrated and functional under the common protocol first.

## 2. Foundations delivered this session (both model-independent, both unblock all five models)

**HCS per-state harvest rate table.** The HCS rate array (job 11321433) had completed with 48 per-state files but was never consolidated. Assembled into the file the config references: `tools_conus/14_outputs/uncertainty/hcs_harvest_rate_by_state.csv` (48 states). Columns: state, forest_ha, clearcut_ha_yr, partial_ha_yr, total_ha_yr, harvest_rate_pct_yr, clearcut_frac. Rates span 0 to 5.19 %/yr (median 0.11): near zero across the arid West (AZ, CO, NV), high in the Southeast (AL 1.39, 73 % clearcut). This is the single harvest driver every model's BAU/conservation/intensive scenarios scale from. Note: states with zero modeled harvest report clearcut_frac 1.0 as a degenerate default; treat as 0/0.

**FIA year-0 live AGC anchor (interim).** Computed per-state live aboveground carbon from the FIA TREE and COND tables on Cardinal: `FIA/fia_agc_anchor_interim_by_state.csv` (48 states). Method is mean live AGC per forested acre (live trees, forested conditions, CARBON_AG times TPA_UNADJ) converted to Mg C/ha and multiplied by state forest area. Results are ecologically coherent: NV 11.5, AZ 18, MN 33, ME 44, GA 45, WV 68, CA 71, OR 85, WA 90 Mg C/ha. CONUS total 12.73 Pg C live AGC, which matches the published FIA figure for the lower 48 and validates the pipeline. Reproducible R script committed at `harmonized/build_fia_agc_anchor.R` (also on Cardinal in FIA/).

## 3. Anchor caveat and the path to the publication version

The interim anchor is a transparent per-acre-mean times area estimate, adequate to start anchoring model dynamics. It is NOT the design-based stratified estimator. The proper version multiplies tree carbon by stratum EXPNS via `POP_PLOT_STRATUM_ASSGN`, which is absent from the FIA cache (`ENTIRE_EVALIDATOR_POP_ESTIMATE.csv` turned out to be the EVALIDator SQL dictionary, not estimates). To publish, either download `POP_PLOT_STRATUM_ASSGN` (per-state or ENTIRE) from the FIA Datamart and switch the estimator, or run `rFIA::carbon()` (not yet installed on Cardinal). The interim and refined numbers should be cross-checked before any paper uses them.

## 4. Where things stand overall

Eight states LANDIS-calibrated. Scenario generator patched (calibrated params, IC guard, Duration 100) and committed at `pipeline/scenario_factorial.sh`; statewide-raster LANDIS still blocked on a statewide Universal-format IC (per-plot is the recommended path for harmonized output). HCS harvest table and interim FIA anchor now in hand. No LANDIS scenario jobs running; the WA pilots failed earlier on the IC format issue (see 06-06 handoff).

## 5. Next steps (priority order)

1. Stand up the harmonized aggregation layer: one tidy long table keyed by model, state, scenario, year, carrying per-ha live AGC, removals, and stand age distribution, with the FIA anchor rescale applied and the acceptance checks automated.
2. Add a harmonized mode to the LANDIS pipeline: four Daigneault scenarios, per-plot, current climate, HCS per-state rate as the harvest driver, FIA-anchored per-ha AGC. Validate on ME first, then the other seven calibrated states.
3. Refine the FIA anchor to the stratified EXPNS estimator once `POP_PLOT_STRATUM_ASSGN` is available, and cross-check against the interim table.
4. Confirm the other four models (yield curves, CBM, CEM, FVS) emit the common schema under the same anchor and HCS harvest.
5. Continue the 48-state LANDIS rollout per `docs/CONUS_rollout_roadmap_v2.0.md` (freeze N4 and S2 blend references; pilot NH/VT/NY off N1).
6. Scope the climate sensitivity layer separately for the capable models only.

## 6. Files created or changed this session

Repo: `harmonized/hcs_harvest_rate_by_state.csv`, `harmonized/fia_agc_anchor_interim_by_state.csv`, `harmonized/build_fia_agc_anchor.R`, `docs/SESSION_HANDOFF_2026-06-07.md`. Cardinal: consolidated `hcs_harvest_rate_by_state.csv` under tools_conus 14_outputs/uncertainty; `FIA/fia_agc_anchor_interim_by_state.csv`; `FIA/anchor_interim.sh` and `FIA/build_fia_agc_anchor.R`.
