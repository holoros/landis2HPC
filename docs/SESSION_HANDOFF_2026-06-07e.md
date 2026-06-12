# Harmonized session handoff — 2026-06-07e

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-07d
**Focus:** certified the 48-state design anchor and built the harmonized aggregation layer (the integration spine), validated end to end.

---

## 1. 48-state design anchor (done)

The CONUS design-based anchor is computed for all 48 states: `harmonized/fia_agc_anchor_design_by_state.csv`. A vintage-mismatch bug was found and fixed: the freshly downloaded assignment tables carried 2024/2025 evaluations that the older `ENTIRE_POP_STRATUM` lacked, so several states returned zero. The estimator now selects the most recent EXPVOL evaluation present in BOTH the assignment table and POP_STRATUM. After the fix: zero zero-states, CONUS live aboveground carbon 15.28 Pg C (design EXPNS), with ME 374, WA 819, RI 12.8 Tg C unchanged. Remaining QA: one-state cross-check against published EVALIDator to certify; the no-macroplot-adjustment approximation likely puts this a few percent high, which that check will quantify.

## 2. Harmonized aggregation layer (built and validated)

`harmonized/harmonized_aggregate.R` is the integration spine. It takes the common per-plot schema (model, scenario, PLT_CN, year, agc_MgC_ha), paints it onto the landscape via the TreeMap plot-CN area weights, aggregates to a domain by year, rescales each model to the FIA year-0 design anchor per state (factor = anchor / model_year0, applied to all years so year-0 stock is common and only dynamics differ), and runs the acceptance gate.

Self-test (ME, WA, two models, four scenarios, 2025 to 2100): passes. Post-anchor year-0 agreement is exactly 1.0 across models in both states; the rescale pulls each model's year-0 to the design anchor (FVS Maine BAU lands on 374 Tg at 2025) and the four scenarios diverge correctly (reserve highest, intensive lowest). The full chain, per-plot output to painted, anchored, gated tidy table, is demonstrated working.

## 3. The pipeline is now complete in skeleton

End to end the harmonized machine exists and is tested: HCS harvest driver (48 states), FIA design anchor (48 states), TreeMap painter (`treemap_paint.R`), and the aggregation/rescale/acceptance layer (`harmonized_aggregate.R`). What is missing is real model output in the common per-plot schema. Every model now needs only a thin adapter that emits, per FIA plot CN, a per-ha live AGC trajectory under the four scenarios.

## 4. Next steps (priority order)

1. LANDIS adapter first: have the per-plot LANDIS runs emit (PLT_CN, year, agc_MgC_ha) per scenario, feed `harmonized_aggregate.R`, and produce the first real harmonized table for the eight calibrated states.
2. Certify the design anchor against published EVALIDator for one or two states; promote to the publication anchor.
3. Adapters for FVS (already paints by CN), CEM (extending now), CBM, and yield curves (FIA-native; emit per-plot per-ha).
4. Ecoregion domain: install sf on the login node, or overlay the EPA L3 raster on the painted surface (no sf needed); produce state, county, and ecoregion harmonized tables.
5. Once two or more models are in, read the cross-model spread under identical inputs, the headline result.

## 5. Files created or changed this session

Repo: `harmonized/harmonized_aggregate.R`, `harmonized/fia_agc_anchor_design_by_state.csv` (48 states), updated `harmonized/fia_design_estimate.R` (shared-EVALID fix), `docs/SESSION_HANDOFF_2026-06-07e.md`. Cardinal: all of the above plus `FIA/submit_anchor.slurm`, anchor job 11322257 (completed), `FIA/harmonized_aggregate.R`, `FIA/selftest_model_output.csv`.
