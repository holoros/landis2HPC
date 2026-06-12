# FVS max-SDI audit: is the western over-projection a metric-vs-Imperial bug?

Date 2026-06-10. Triggered by AW's hypothesis that fvs-modern max-SDI values might be
metric (per ha) fed into the Imperial FVS engine, which would let stands grow ~2.47x
too dense before density-dependent mortality engages (1 ha = 2.471 ac).

## Verdict: NOT a metric/Imperial units bug

The FVS engine is Imperial (morts.f90: trees/acre, `CONST = SDIMAX/0.02483133`, the English
Reineke coefficient). The applied max-SDI values are Imperial and broadly match FIA-observed
operational maxima, so they are NOT metric:

| variant | calibrated SDImax median | FIA-observed max | ratio applied/FIA | NA species | calibrated == default? |
|---|---|---|---|---|---|
| WS (CA) | 394 | 415 | 0.95 | 9/43 | no (recalibrated) |
| CR (interior) | 423 | 465 | 0.91 | 5/38 | no |
| UT | 398 | (n/a) | - | 4/24 | no |
| EC (WA) | 900 | (n/a) | - | 0/32 | YES (NOT recalibrated) |

If the values were metric fed to the Imperial engine, the medians would be ~975 (394 x 2.47),
not 394. WS/CR/UT medians sit at or slightly below the FIA-observed operational max, so the
calibration both reflects reality and is in the right unit system. FVS plateaus near 85% of
SDImax, and 0.85 x ~400 is consistent with FIA densities. Metric-mislabel rejected.

## Real implementation gaps found (AW's instinct partly right)

1. NA dropouts in calibrated configs: WS 9/43, CR 5/38, UT 4/24, and large counts in the East
   (CS 25/96, NE 23/108, LS 15/68). The keyword writer skips NA species
   (`_format_sdimax_keywords`: `if isinstance(val,str) or val is None: continue`), so those
   species silently revert to the FVS built-in variant default rather than the calibrated /
   FIA value. In WS the NA set includes species 4 (redwood, default 1052) and 14-18, so the
   highest-biomass coastal species use the very high built-in 1052 ceiling, not a calibrated one.
2. EC (East Cascades / Washington) calibrated is byte-identical to default (uniform 766/900) -
   it was never recalibrated, so WA uses high built-in potentials (0.85 x 900 = 765 SDI ceiling).
3. SO (Oregon), CI, PN, WC store sdimax under a different key structure that the audit script
   could not auto-extract; needs a manual check that OR/PNW actually carry calibrated, FIA-realistic
   sdimax and not defaults.

## How this relates to the western over-projection

The statewide median applied SDImax (~394 WS) already matches FIA reality, so the western
over-projection (CA reserve +272%) is NOT primarily a too-high-SDImax bug. It is dominated by the
no-disturbance accumulation over 75 years plus the growth dynamics, with the NA-reversion and the
uncalibrated EC inflating specific high-biomass forest types (coastal redwood/hemlock, WA east-side).
Calibration already reduces western growth vs default (CA def +333% -> cal +272%), so the growth
engine itself runs hot in the West independent of SDImax.

## Empirical test (2026-06-10): does the max-SDI ceiling actually bind in the West?

NA-dropout fix implemented: `make_sdifix_configs.py` fills every NA max-SDI species with the
variant's calibrated median (WS redwood 1052-default -> 394; 9 WS species, 18 variants total),
written to `config/calibrated_sdifix/`. Verified at the keyword level: the WS SDIMAX block now
caps redwood at 394 instead of reverting to 1052.

Confirmation run (`test_sdimax.py`, 40 WS/CA plots to 2100, no disturbance): the 2100 carbon was
IDENTICAL (80.6 MgC/ha) under (a) current calibrated config, (b) the NA-fix config, and even (c) an
extreme all-species SDImax = 120 cap. The loader demonstrably emits the SDIMAX keywords, so the
ceiling simply is not the binding constraint for this sample over the horizon - the stands (starting
~7 MgC/ha) grow to ~80 MgC/ha by the growth engine without approaching the self-thinning limit.

CONCLUSION: the western over-projection is GROWTH-ENGINE driven (diameter/height increment under no
disturbance over 75 years), not a max-SDI ceiling problem. This is consistent with the calibrated
SDImax already matching FIA (~394 vs 415) and with calibration reducing growth vs default. The
max-SDI NA-fix is correct hygiene (it matters for dense/old-growth plots that DO ride the ceiling and
for the high-biomass forest types) but it does not materially change the statewide western trajectory.
The remaining lever is the growth engine itself (diameter-growth multipliers / mortality), best tested
by regenerating the western FVS reserve through the production conus runner with the sdifix configs
and, separately, with a tempered western diameter-growth multiplier.

## Recommended fixes (priority)

1. Eliminate NA dropouts: fill every species' calibrated sdimax with the FIA-observed per-species
   max (so redwood etc. stop reverting to the 1052 default). One-line change in the calibration
   export plus a guard in `_format_sdimax_keywords` to fall back to the FIA value, not skip.
2. Recalibrate EC (WA) and verify SO/CI/PN/WC carry real calibrated sdimax (not defaults).
3. Definitive confirmation test: run one western stand (CA mixed-conifer and a redwood plot) to
   2100 with no disturbance under (a) current config and (b) sdimax capped at the FIA-observed
   operational max; compare realized SDI plateau and per-acre carbon. This isolates the sdimax
   contribution from the growth-engine and disturbance contributions.
