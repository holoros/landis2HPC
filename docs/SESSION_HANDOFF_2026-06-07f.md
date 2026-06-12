# Harmonized session handoff — 2026-06-07f

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-07e
**Focus:** standard errors on the FIA design anchor and propagation through the aggregation layer.

---

## 1. Design anchor now carries standard errors (48 states)

`fia_design_estimate.R` now computes the FIA design-based variance alongside the total, using the stratified estimator (Bechtold and Patterson 2005, fpc ignored): for each stratum, V_h = A_h^2 * s2_yh / n_h with A_h = EXPNS_h * n_h and s2_yh the sample variance of per-plot live AGC including the zero-value (nonforest / no-live-tree) plots; SE = sqrt(sum V_h), CV% = 100*SE/total. ADJ_FACTOR is applied per tree (microplot for DIA < 5, subplot otherwise).

Output `harmonized/fia_agc_anchor_design_by_state.csv` now has columns: state, evalid, n_plots, agc_TgC_design, se_TgC, cv_pct.

Validation and pattern: CONUS 15,279 +/- 32 Tg C (national CV 0.21%, errors aggregated in quadrature across states). Per-state CVs follow the expected forest-density gradient: lowest in heavily forested states (WI 0.8%, OR 0.88%, MN 0.89%), highest in sparse-forest plains (ND 7.25%, DE 6.21%, NE 5.73%). Spot checks: ME 374.02 +/- 3.45 (CV 0.92%), WA 818.67 +/- 8.27 (1.01%), RI 12.75 +/- 0.68 (5.32%). These match published FIA precision.

## 2. SE propagated through the aggregation layer

`harmonized_aggregate.R` now reads the anchor CV and writes `agc_TgC_anchored_se = agc_TgC_anchored * anchor_cv/100` on every anchored value. This is the FIA-anchor sampling uncertainty carried onto the model trajectories (ME anchored 374.02 +/- 3.44, WA 818.67 +/- 8.27). It is explicitly the anchor-derived component only; model projection uncertainty (across runs or parameter draws) is separate and will be added per model where replicate runs exist.

Behavioral note confirmed in the self-test: a pure constant (multiplicative) difference between models is removed by the anchor rescale, so post-anchor differences reflect trajectory shape, i.e. genuine dynamics, not level offsets. This is the intended property of anchoring.

## 3. Where SEs can and cannot be included

Can, and now done: the FIA year-0 anchor (design-based sampling SE per state, propagated). Can, with more work: per-state county/ecoregion domain SEs (same stratified estimator at the sub-state domain once the domain is the grouping unit), and the painted TreeMap totals (a model-allocation uncertainty, estimable from donor-plot dispersion within each hex). Cannot from a single deterministic run: model projection SE; that needs replicate runs or a parameter ensemble per model, which is a per-model design choice.

## 4. Status

The harmonized spine is complete and now uncertainty-aware on the anchor: HCS harvest driver (48 states), FIA design anchor with SEs (48 states), TreeMap painter, and the aggregation/rescale/acceptance layer carrying anchor SE. Still need real model output in the common per-plot schema; the LANDIS per-plot adapter is the first step.

## 5. Next steps (priority order)

1. LANDIS per-plot adapter: emit (PLT_CN, year, agc_MgC_ha) per scenario, run through `harmonized_aggregate.R`, first real harmonized table (eight calibrated states), with anchor SEs attached.
2. Certify the anchor against published EVALIDator for one or two states (the no-macroplot approximation is expected to be a few percent high).
3. Domain-level SEs for county and ecoregion (stratified estimator at the domain grouping).
4. Adapters for FVS, CEM, CBM, yield curves; where a model has replicate runs, attach a model projection SE alongside the anchor SE.
5. Decide ecoregion route (sf install vs L3 raster overlay).

## 6. Files changed this session

Repo: `harmonized/fia_design_estimate.R` (adds SE), `harmonized/harmonized_aggregate.R` (SE propagation), `harmonized/fia_agc_anchor_design_by_state.csv` (48 states with se_TgC, cv_pct), `docs/SESSION_HANDOFF_2026-06-07f.md`. Cardinal: same scripts; anchor job 11322285 (completed).
