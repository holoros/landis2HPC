# Measured Maine GCBM engine gap (resolves CBM vs GCBM for ME)

Date 2026-06-13. The Maine GCBM spatial run (moja FLINT, 20-tile statewide array, job 11505497)
completed through 2050 and the rasters were retained and mosaicked (FIA/gcbm_rasters/ME). We
aggregated the retained AG live C rasters to a state total (gcbm_me_spatial_summary.R, WGS84
cell-area weighted) and compared to the harmonized libcbm ME reserve.

## Result: the gap is time-varying and small, not the +21% we had assumed

GCBM aboveground live C vs libcbm (ME reserve), measured:

| Year | GCBM (Tg C) | libcbm (Tg C) | GCBM over libcbm |
|------|-------------|---------------|------------------|
| 2030 | 445.0       | 406.6         | +9.4%            |
| 2035 | 448.8       | 436.6         | +2.8%            |
| 2040 | 452.4       | 463.7         | -2.4%            |
| 2045 | 456.0       | 487.7         | -6.5%            |
| 2050 | 459.9       | 509.3         | -9.7%            |

GCBM starts ~9% above libcbm (spatial initialization), grows slower, and crosses below by 2040,
ending -9.7% at 2050. Mean over the window is near -1%. This is much smaller than, and opposite
in late-period sign to, the +21% regional default we had been carrying for ME.

## Why it differs from the prior +21% "measured" value

The prior +21% predates our eastern entry-point correction to libcbm. That correction RAISED
the libcbm ME reserve (it had been under-initialized), which is exactly the denominator here.
Correcting libcbm closed most of the apparent engine gap. The remaining difference is a slower
GCBM late-period growth, not a persistent stock-density inflation. So the engine gap for ME, on
an apples-to-apples basis (same TreeMap initial communities, same corrected libcbm), is modest.

## What we changed

- cbm_engine_gap.csv ME: 21 (regional/old) -> -9.7 (basis measured_gcbm2026_to2050). Backup at
  cbm_engine_gap.csv.bak_pre_me_measured.
- Re-ran build_crossmodel_ci.R + build_ensemble_estimate.R; ME's CBM within-model band narrows
  accordingly (the engine gap was the dominant CBM uncertainty term).

## Caveats and next step

- The GCBM run reached 2050, not 2100. The late trend is negative (GCBM falling below libcbm), so
  the 2100 gap could be larger in magnitude; the -9.7% is a 2050 value, flagged in the basis.
- This is ONE state. The +21-26% regional defaults for the other states are now suspect: if the
  entry-point correction similarly closed their gaps, the defaults OVERSTATE the engine
  uncertainty. The 5 source stacks (MN, WA, OR, CA, GA) are built; running those GCBM states will
  replace their defaults with measured, post-correction values and test this directly.
- Implication for the assessment: the CBM intra-model uncertainty (driven by the engine gap) is
  probably narrower than currently reported for the corrected-libcbm states. The headline
  cross-model divergence is unaffected (it is structural, between models).
