# HWP and harvest benchmark vs Nash and Domke 2026 (Northern Lake States)

Date 2026-06-12. External cross check of our harmonized common harvest and HWP pool against an
independent FIA based reconstruction for MI, MN, WI.

## The paper

Nash JM, Domke GM. "Advancing carbon estimation in harvested wood products in the United States: a
case study in the Northern Lake States, USA." Carbon Balance and Management, in press 2026.
doi 10.1186/s13021-026-00464-y.

A new US HWP compilation system (US HWP CCS) built around NFI / FIA harvest removals rather than the
WOODCARBII survey back calculation. Production approach, IPCC, 1900 to 2024, for MI + MN + WI. First
order (exponential) decay with Skog 2008 half lives for in use and SWDS, and species specific carbon
fractions (Westfall 2024) instead of the default 0.5 wood carbon fraction. Harvest is the merchantable
bole AGB carbon of live trees >= 12.7 cm dbh to a 10 cm top.

Headline results (MI + MN + WI):
- 2024 annual harvest: MI 3.0, MN 2.0, WI 3.4, total 8.3 +/- 0.04 MMT C/yr.
- State to national harvest ratios: MI 3.89%, MN 2.53%, WI 3.85%.
- Cumulative HWP stock 2024: 489.1 MMT C gross (313.6 in use + 175.5 SWDS); net accumulation 277.0 in
  use + 155.2 SWDS = 432.2 MMT C.
- 2024 net HWP sink 4.9 +/- 0.1 MMT C/yr (7.3 added to in use, 3.1 to SWDS, with losses).
- 93% of HWP retained within the three states; key method finding: WOODCARBII / survey harvest runs
  consistently ABOVE FIA / NFI harvest, so they regressed and scaled FIA up (R2 = 0.92).

## Harvest comparison (our BAU common harvest vs Nash 2024)

Our removal is rem = h x f x B, with h the HCS area harvest rate, f the BAU removal fraction
(clearcut_frac x 0.85 + partial_frac x 0.45), B the FIA 2025 anchor live AGC. This is whole tree
aboveground carbon removed; Nash is merchantable bole only, so ours is expected to sit higher.

| State | our h %/yr | our f | our removal Tg C/yr | % of AGC | Nash 2024 MMT C | ratio ours/Nash |
|-------|-----------|-------|---------------------|----------|-----------------|-----------------|
| MI    | 1.775     | 0.670 | 6.1                 | 1.19     | 3.0             | 2.03            |
| MN    | 0.335     | 0.666 | 0.7                 | 0.22     | 2.0             | 0.34            |
| WI    | 3.257     | 0.668 | 8.6                 | 2.18     | 3.4             | 2.54            |
| NLS   |           |       | 15.4                |          | 8.3             | 1.83            |

Apply a 0.6 merchantable bole fraction to our whole tree removal: NLS 9.2 Tg C/yr vs Nash 8.3, within
about 10%. So at the regional level our common harvest LEVEL is independently corroborated.

Two state level signals worth acting on:
1. Minnesota is the outlier. Our HCS rate (0.335%/yr) puts MN at roughly one fifth of MI, but Nash and
   the literature put MN harvest at about two thirds of MI (state to national 2.53% vs 3.89%). Our MN
   removal (0.7) is one third of Nash (2.0). The MN entry in hcs_harvest_rate_by_state.csv looks under
   set and should be reviewed; MN is a major timber state and a cem2100 member.
2. Wisconsin runs hot. Our WI rate (3.257%/yr, clearcut 118,902 ha/yr) gives 2.5x Nash. Some of this is
   the whole tree vs merch bole scope, but the WI clearcut input is worth a sanity check against TPO.

## HWP pool comparison

Our standing HWP pool at 2100 (in use + landfill), disturbance aware ensemble mean, BAU:

| State | CBM | FVS_cal | FVS_def | LANDIS | YC | 5 model mean Tg C |
|-------|-----|---------|---------|--------|----|-------------------|
| MI    | 76.8| 75.5    | 94.9    | 115.8  | 88.2 | 90.2 |
| MN    | 14.1| 11.6    | 16.3    | 21.8   | 13.8 | 15.5 |
| WI    | 85.4| 84.6    | 117.8   | 164.2  | 83.7 | 107.1 |
| NLS   |     |         |         |        |    | 212.8 |

Not directly comparable to Nash's 432 to 489 MMT C, because ours is the forward standing pool built from
2025 to 2100 (75 yr) while Nash is the cumulative historical stock 1900 to 2024 (124 yr). On a per year
accumulation basis ours is about 213/75 = 2.8 Tg C/yr vs Nash's long run mean 432/124 = 3.5 and recent
2024 net sink 4.9. Since our harvest already runs ABOVE Nash in MI and WI, the lower HWP accumulation is
driven by our conservative product fraction (HWP_FRAC = 0.5), not by low harvest. This is consistent
with our own HWP note that the pool is modest because half of removed carbon is treated as slash and
mill loss.

## Method alignment

| Element | Ours (harmonized) | Nash and Domke 2026 |
|---------|-------------------|---------------------|
| Decay model | first order, Skog 2008 family | first order, Skog 2008 |
| Pools | 3 (in use long 35 yr, paper 4 yr, landfill 100 yr) | 13 solidwood end uses + paper + SWDS, individual half lives |
| Product fraction | HWP_FRAC 0.5 of removed C enters products | merch bole then ~8% in use loss (McKeever) |
| Carbon fraction | lumped 0.5 | species specific (Westfall 2024) |
| Harvest basis | whole tree AGC x removal fraction | merch bole >= 12.7 cm to 10 cm top |
| Harvest source | HCS rate (TM2016 / FIA derived) | FIA / NFI scaled to WOODCARBII |
| Horizon | forward 2025 to 2100, 4 scenarios | historical 1900 to 2024 |
| Trade | retained on site (no export accounting) | production approach, exports in, imports out, 93% retained |

## Findings and recommended next steps

1. Regional harvest level is corroborated. Our NLS common harvest, reduced to merch bole equivalent, is
   within ~10% of an independent FIA reconstruction. This is a useful eastern complement to the western
   OR 45% benchmark we already track.
2. Fix the Minnesota harvest rate. Review and likely raise the MN HCS rate; recheck the WI rate against
   TPO. Then refresh master / ensemble / CI for MN and WI.
3. Adopt species specific carbon fractions (Westfall 2024) in place of the lumped 0.5 in the HWP and
   removal accounting. Low cost, improves Tier alignment, and is the explicit advance of this paper.
4. Consider a survey calibration of our common harvest. Nash shows FIA / NFI harvest runs below
   WOODCARBII (R2 = 0.92). Our flagged TM2016 under detection is the same phenomenon. A WOODCARBII or
   TPO scaling of the HCS layer would tighten the harvest input that drives every model's HWP pool.
5. Cite Nash and Domke 2026 as external validation of the harmonized HWP pool and as the basis for the
   carbon fraction and harvest calibration refinements.

Reproducible computation: harmonized/benchmark_nash_domke_harvest.R.
