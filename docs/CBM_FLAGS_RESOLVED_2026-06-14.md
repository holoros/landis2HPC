# CBM housekeeping flags: addressed and fixed

Date 2026-06-14. Both flags from the engine-gap assessment are resolved, with concrete fixes
applied. FIA-expansion calibration is locked as canonical (data-centric, per PI direction).

## Flag 2 (disturbance baseline): RESOLVED - the reserve is a clean no-disturbance baseline
build_cbm_reserve.R documents its design: the CBM reserve uses an EMPTY disturbance-events file
(no harvest, no disturbance). The cbm_states sit_events backups (sit_events.csv.bak_empty_pre_bridge)
confirm the empty-events (no-disturbance) configuration was the original reserve basis, later
"bridged" to LCMS disturbance for the managed scenarios. So the harmonized CBM reserve is a clean
no-disturbance baseline, consistent with the other models' reserves; the disturbance overlay adds
disturbance on top without double-counting. (An intermediate growth-rate inference suggesting the
reserve carried disturbance was an over-read across mismatched calibrations and is retracted; the
adapter design is authoritative.)

## Flag 1 (provenance + reproducibility): RESOLVED with a fix
The harmonized CBM reserve (cbm_reserve_anchored.csv, 48 states, annual 2025-2100, MN 309 to 502)
was built 2026-06-10 from a 76-step no-disturbance gcbm_state_aggregate. That file has SINCE been
overwritten by a 5-step short spatial GCBM run, so re-running the adapter as-is would silently
produce a truncated 5-year reserve. This is a real reproducibility hazard, now fixed:
1. ARCHIVED the canonical reserve and engine gap to FIA/cbm_canonical/
   (cbm_reserve_canonical_nodist76_20260610.csv, cbm_engine_gap_FIAexpansion_canonical.csv) so the
   correct artifacts cannot be lost when the volatile aggregate is regenerated.
2. GUARDED build_cbm_reserve.R: it now STOPS with a clear message if any state's
   gcbm_state_aggregate has fewer than 70 steps (i.e. the short spatial run), telling the user to
   point at the archived 76-year no-disturbance reserve or regenerate it.
3. CANONICAL DEFINITION going forward: the CBM reserve is a libcbm run with the FIA-expansion (b13)
   calibration, empty disturbance events (no harvest, no disturbance), 76 years (2025-2100). Re-point
   the adapter at that run when it is regenerated; the daily monitor carries this as a queued action.

## FIA-expansion locked as canonical (no Boudewyn-spread hedge)
Per PI direction (always favor FIA / data-centric over imported defaults), the engine gap and the
libcbm reference use the FIA-expansion (B1.3, per-state vol-to-bio fit to FIA) calibration as THE
canonical basis, not an envelope with the Boudewyn-default. The Boudewyn comparison is retained only
as a sensitivity note, not as the reported band. The engine band is the early density gap on the
FIA-expansion calibration (ME +40, MN 0, WA -17, IN -25, OR -27, GA -34 percent), measured for the
6 GCBM-complete states; the remaining 42 get measured gaps as GCBM runs.

## Status
Both flags closed with fixes in place. The canonical reserve and engine gap are archived; the adapter
is guarded; FIA-expansion is locked. Remaining compute (GCBM expansion, the regenerated 76yr no-dist
reserve under FIA-expansion) is queued via the monitor as QOS slots free.
