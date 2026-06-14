# Reassessing the CBM engine band (corrected)

Date 2026-06-14. I pressure-tested my default (carry the GCBM-vs-libcbm density gap as the CBM
engine band). The first pass reached a wrong intermediate conclusion from a step-interval error;
this is the corrected assessment. Net: keep the density gap as the band, for the right reason.

## The error I caught
I initially computed an "anchored growth-shape gap" by annualizing the GCBM trajectory assuming
5-year steps, and concluded GCBM grows much slower than libcbm (implying a large growth-shape
divergence). That was wrong. build_cbm_reserve.R maps year = 2024 + step, so the cbm_states GCBM
aggregate steps are ANNUAL, and the aggregate has only 5 steps = years 2025 to 2029. A 5-year window
cannot support a 75-year growth-rate extrapolation. With the correct annual interval, MN GCBM grows
46.16 to 48.52 Mg/ha over 4 years (about 1.25%/yr), comparable to libcbm, not 5x slower. The
engine_gap_growth_vs_density.csv output is therefore SUPERSEDED and should not be used.

## What the pieces actually are
- cbm_states GCBM (6 states: GA, IN, ME, MN, OR, WA): SHORT 5-year spatially explicit runs
  (2025 to 2029), plus spatial mosaics and per-owner strata. These provide the engine-gap
  measurement and the PERSEUS-ready owner strata, not a 2100 trajectory.
- Harmonized CBM member (cbm_reserve_anchored.csv): a separate full 48-state annual 2025 to 2100
  trajectory (MN 76 rows, 309 to 502 Tg C, about 0.65%/yr), anchored to FIA 2025. This is the CBM
  central estimate; its long-horizon source is the 48-state CBM run, distinct from the 5-year
  cbm_states spatial runs.
- Engine gap (density_gap_matrix, year 5): GCBM-vs-libcbm aboveground density after 5 years. A
  short-horizon stock comparison.

## Recommendation (unchanged conclusion, corrected rationale)
1. KEEP the year-5 density gap as the CBM engine band (current cbm_engine_gap.csv, FIA-expansion
   calibration). At a 5-year horizon, growth and disturbance divergence are minimal, so the gap
   isolates the spatial-versus-stratum initialization and methods difference, which is exactly the
   intra-CBM engine uncertainty we want. It does not double-count disturbance, and there is no valid
   longer-horizon GCBM trajectory to prefer instead.
2. REPORT the cross-calibration spread (FIA-expansion vs Boudewyn) as the methodological band on the
   gap magnitude, as already decided.
3. Do NOT switch the band to a growth-shape gap: there is no multi-decade GCBM trajectory to compute
   one from, and the attempt above was invalid.

## Two real, separate flags for the team (not band issues)
1. Horizon mismatch: the cbm_states spatial GCBM runs are 5-year, while the harmonized CBM member
   runs to 2100 from a different source. Confirm the 2100 CBM trajectory's provenance and that the
   engine gap measured on the 5-year spatial run is the intended uncertainty proxy for it.
2. Disturbance consistency in the CBM central estimate: confirm whether the 2100 CBM reserve
   trajectory is a true no-disturbance baseline (consistent with the other models' reserves) before
   the disturbance overlay is applied, to avoid double-counting in the disturbed scenarios.

## Bottom line
My default stands: the FIA-calibrated year-5 density gap is the right CBM engine band. The
growth-shape alternative I floated was based on a step-interval error and is retracted. The
substantive open items are the 2100 CBM trajectory provenance and its disturbance baseline, which
are team verification items rather than band choices.
