# GCBM finalization, corrected: cbm_states is a running per-state production pipeline

Date 2026-06-14. A material correction to the earlier "GCBM gated on per-state growth-curve
databases" framing. The per-state GCBM is NOT a from-scratch build; it is an established
production pipeline at /users/PUOM0008/crsfaaron/cbm_states/ that has already run for six states.

## What exists
cbm_states/states/<ST>/ is a full 10-stage per-state chain (02_yield_curves, 03_biomass_expansion,
04_disturbance_history, 05_aidb_params, 06_hwp_module, 07_scenarios, 08_cbm_runs, 09_validation,
10_outputs) with a per-state runner cbm_states/port_new_state.sh. The harmonized CBM reserve
already reads each state's 10_outputs/gcbm_state_aggregate.csv.

COMPLETED (spatial GCBM, 10_outputs present): GA, IN, ME, MN, OR, WA (6 of 48). Each has:
- gcbm_state_aggregate.csv: AG_Biomass_C, Total_Biomass_C, Total_Ecosystem_C, Dead_Organic_Matter_C,
  Soil_C, NPP, NEP, NBP, by 5-yr step, with area_ha, mean_per_ha, total_TgC.
- gcbm_state_mosaics/: spatial VRT rasters per variable per step (GA 400, IN/MN/OR/WA 40 each).
- gcbm_state_per_owner.csv: carbon STRATIFIED BY OWNERSHIP CLASS (Family, Corporate, State, Federal,
  Local, Tribal, Unknown) per variable per step.
- 10_outputs/perseus/: a PERSEUS-specific output directory.

## Six-state GCBM result (aboveground live C, Tg C; first -> last 5-yr step)
GA 21.3 -> 34.7 | IN 125.1 -> 133.1 | ME 442.7 -> 457.6 | MN 254.8 -> 267.8 |
OR 859.2 -> 876.5 | WA 626.3 -> 639.2. Total ecosystem C roughly 3-4x these (e.g. OR 2815 -> 2830).

## The per-owner output IS the PERSEUS strata format
gcbm_state_per_owner.csv is already the stratified, decision-support representation recommended for
PERSEUS. MN aboveground live C by owner (last step): Family 52.6, State 30.3, Corporate 20.9,
Federal 20.8, Local 1.6, Unknown 0.6, Tribal 0.0 Tg C, each with its forest area. Ownership is the
decision-relevant stratum (different owners, different management options), so PERSEUS should ingest
gcbm_state_per_owner.csv (owner x variable x step) directly, complemented by forest-type x ecoregion
x age strata where finer resolution is needed. This supersedes the earlier age-class-only demo: the
production pipeline already emits owner-stratified carbon.

## What GCBM finalization actually needs
Run cbm_states/port_new_state.sh for the remaining 42 states. This is the established chain (yield
curves from FIA, biomass expansion, disturbance history, AIDB params, scenarios, CBM run, validation,
spatial aggregate + per-owner + mosaics), not a bespoke database build. Per-state runtime is the gate
(compute), not missing methodology. Engine-gap measurement (GCBM vs libcbm) needs the libcbm pool
reference, which is empty in the current 10_outputs/libcbm_pools and should be populated from the
state's libcbm run for a clean per-state gap.

## Implication for the assessment
The harmonized CBM member is, for these six states, the spatially explicit GCBM aggregate (not just
libcbm). GCBM coverage is therefore 6/48 and growing via port_new_state.sh, with spatial rasters and
owner strata already produced. This is a much more advanced status than the cbm_maine-only view
implied, and it directly answers the PERSEUS ingestion question with a production format.
