# CBM team action: re-point the reserve adapter at the libcbm 76yr no-disturbance run

Date 2026-06-14. Owner: CBM team. Status: recommended, not yet applied. A guard is in place so
nothing breaks silently in the meantime.

## What to change and why

`build_cbm_reserve.R` currently reads the CBM reserve trajectory from `gcbm_state_aggregate`. That
file was a 76-step (annual 2025 to 2100) no-disturbance run when the canonical reserve was built on
2026-06-10, but it has since been overwritten by a 5-step short spatial GCBM run (years 2025 to 2029).
Re-running the adapter against it now would silently produce a truncated 5-year reserve. The 5-year
spatial run serves a different purpose (the GCBM-vs-libcbm engine-gap measurement and the PERSEUS
per-owner strata); it is not the 2100 CBM member of the ensemble.

The fix is to point the adapter at a stable, purpose-built reserve rather than the volatile spatial
aggregate. The canonical reserve is a libcbm run with the FIA-expansion (b13) calibration, an empty
disturbance-events file (no harvest, no disturbance), 76 annual steps (2025 to 2100), 48 states.

## Interim protection already in place

`build_cbm_reserve.R` now stops with a clear message if any state's input has fewer than 70 steps, so
the short spatial run cannot be mistaken for the reserve. The validated artifacts are archived at
`FIA/cbm_canonical/`:

- `cbm_reserve_canonical_nodist76_20260610.csv` (the reserve to reproduce; MN runs 309 to 502 Tg C)
- `cbm_engine_gap_FIAexpansion_canonical.csv` (the locked FIA-expansion engine gap)

## Steps for the CBM team

1. Regenerate the reserve as a libcbm run, not a GCBM spatial run:
   - calibration: FIA-expansion (B1.3, per-state vol-to-bio fit to FIA TREE data via
     `build_vol_to_bio_state.R`), the locked canonical basis.
   - disturbances: empty `sit_events` (the `sit_events.csv.bak_empty_pre_bridge` backups are the
     correct no-disturbance template; do not use the LCMS-bridged events here).
   - horizon: 76 annual steps, 2025 to 2100, all 48 states.
   - write the output to a stable path, for example
     `FIA/cbm_canonical/cbm_reserve_nodist76_libcbm_b13.csv`, never back to `gcbm_state_aggregate`.

2. Edit `build_cbm_reserve.R` to read that stable path. Keep the year mapping as `year = 2024 + step`
   (annual) and keep the <70-step guard.

3. Verify the regenerated reserve against the archived canonical before adopting it: compare per-state
   2025 and 2100 totals to `cbm_reserve_canonical_nodist76_20260610.csv` (spot-check MN 309 to 502 Tg
   C and a western state). Differences should be at floating-point level, since both use FIA-expansion.

4. Leave the engine gap as is. The CBM band stays the year-5 GCBM-vs-libcbm density gap on the
   FIA-expansion calibration (ME +40, MN 0, WA -17, IN -25, OR -27, GA -34 percent for the six
   GCBM-complete states). The remaining 42 states receive measured gaps as their GCBM runs land; until
   then they carry the regional median as a placeholder.

## What not to do

Do not re-point the adapter at any GCBM spatial aggregate, and do not fold the LCMS disturbance events
into the reserve. The reserve must stay a clean no-disturbance baseline so the disturbance overlay
adds disturbance once, without double-counting, consistent with the other models' reserves.

## Downstream

After the reserve is regenerated and the adapter re-pointed, re-run the standard chain
(`apply_disturbance_overlay.R` then `apply_harvest_scenarios.R`, `build_master_scenarios.R`,
`build_ensemble_estimate.R`, `build_crossmodel_ci.R`, `uncertainty_ensemble.R`) so the CBM member and
the ensemble pick up the reproducible reserve. The numbers should not move materially, since the
archived canonical is already the basis for the current results; this step makes the pipeline
reproducible from source rather than from a frozen CSV.
