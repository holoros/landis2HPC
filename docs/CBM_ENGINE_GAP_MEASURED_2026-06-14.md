# CBM engine gap finalized from the measured libcbm reference

Date 2026-06-14. The libcbm reference and the GCBM-vs-libcbm engine gap are now integrated from
the CBM team's cross-state work, replacing the regional defaults for every state where both
engines have run.

## The libcbm reference exists for all 48 states
cbm_states/cross_state/libcbm/<ST>/ holds the non-spatial libcbm SIT bundle and pools for all 48
states (libcbm_pools_<ST>_*.csv across scenarios and horizons). The spatially explicit GCBM side
(cbm_states/states/<ST>/10_outputs/gcbm_state_aggregate.csv) has run for 6 states: GA, IN, ME, MN,
OR, WA. The engine gap can therefore be MEASURED for those 6; for the other 42 libcbm exists but
GCBM does not yet, so the gap stays at the regional default until GCBM runs.

## Measured gaps (latest density_gap_matrix, b13fia, 2026-05-31)
Comparing aboveground live C density at year 5 (Mg/ha), gcbm_over_libcbm = (gcbm/libcbm - 1):

| State | GCBM (Mg/ha) | libcbm (Mg/ha) | GCBM over libcbm |
|-------|--------------|----------------|------------------|
| ME    | 306.6        | 218.4          | +40.4%           |
| MN    | 209.2        | 208.9          | +0.1%            |
| WA    | 283.8        | 340.5          | -16.7%           |
| IN    | 211.8        | 282.8          | -25.1%           |
| OR    | 279.9        | 385.9          | -27.4%           |
| GA    | 124.9        | 189.3          | -34.0%           |

These supersede the regional-default gaps for the 6 states in cbm_engine_gap.csv
(basis = measured_density_gap_b13fia_20260531; backup .bak_pre_measured_b13). build_crossmodel_ci.R
and build_ensemble_estimate.R were re-run; the CBM band now reflects the measured gaps (for example
WA CBM 2100 widens to about [849, 1197] Tg C, IN to [228, 385]).

## Important caveat: the gap is calibration-sensitive
The measured gap shifts substantially with libcbm calibration. The same six states under the v6
calibration (Boudewyn + LCMS) gave ME +27%, MN +24%, GA -5%, WA +26%, OR +21%, versus the b13fia
(FIA expansion factor) values above. The sign even flips for several states. This spread is itself a
real component of CBM structural uncertainty: the GCBM-vs-libcbm difference depends on how the
non-spatial engine is calibrated (Boudewyn expansion versus FIA expansion factors). We adopt the
latest (b13fia) as the current measured reference and carry the magnitude as the CBM engine band;
the cross-calibration spread should be noted when CBM uncertainty is reported.

## GCBM expansion (next)
Extending the measured gap to more states requires running the GCBM spatial side for them via
cbm_states/port_new_state.sh (FIA -> rasters -> libcbm bundle -> GCBM input -> moja run -> aggregate
+ per-owner + mosaics). 42 of 48 states remain. This is compute-bound and currently queued behind
the CEM array under the job-submit limit; the daily monitor will launch a priority wave (western
divergence states CA, CO, NM, NV and the eastern overlap states) as slots free, then measure each
new gap from the density-gap framework and update cbm_engine_gap.csv.
