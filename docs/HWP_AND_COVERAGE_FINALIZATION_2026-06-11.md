# Product-carbon accounting and CEM/LANDIS finalization

Date 2026-06-11. Answers three questions: (1) is long-term product storage handled apples-to-apples,
(2) how is CEM finalized, (3) how is LANDIS finalized.

## 1. Long-term carbon storage in products (HWP) — yes, common and apples-to-apples

The harmonized scenario engine (`apply_harvest_scenarios.R`) applies ONE first-order, IPCC Tier-2-style
harvested-wood-products model to EVERY model's removed carbon, so the product accounting is identical
across all five models. This is exactly what makes the comparison apples-to-apples: we deliberately do
NOT use each model's idiosyncratic native HWP module (CBM, the yield curves, and CEM each have different
ones), which would confound the structural comparison.

Parameters: of removed carbon, 50% enters products (HWP_FRAC=0.5; the rest is slash/mill loss, emitted);
products split 65% long-lived sawnwood/panels (half-life 35 yr) and 35% short-lived paper (half-life 4 yr);
20% of decayed long-lived carbon enters a landfill pool (half-life 100 yr), the rest emitted. Reported
total carbon = standing forest AGC + in-use HWP + landfill HWP. Reserve scenarios have zero HWP (no
harvest); the pool grows with harvest intensity (e.g. OH: reserve 0, conservation 1.6, BAU 4.0,
intensive 9.3 Tg C at 2100).

The in-use + landfill pools capture LONG-TERM storage (35 yr and 100 yr half-lives). The HWP pool is
modest in absolute terms because (a) the common HCS harvest rate is low, especially in the West where the
TM2016 harvest product under-detects removals, and (b) it is the STANDING pool at 2100, not cumulative
gross production. NOT included: the wood-products SUBSTITUTION benefit (displacing concrete/steel
emissions), which the American Forests reports add; that is a climate-benefit term beyond on-site carbon
storage and could be layered on as an optional extension if the assessment scope requires it.

## 2. CEM finalized

- Horizon: CEM ran 5-yr cycles to 2095 (15 cycles). Finalized to 2100 by linear extrapolation of the
  last cycle (per state), so it aligns with the common 2100 horizon. Flagged as extrapolated (one 5-yr
  step). The cleaner option remains a CEM-team 16-cycle re-run to a native 2100; the extrapolation is a
  small, defensible bridge.
- Coverage: 26 states (the CEM team's CONUS subset). CEM is a PARTIAL-COVERAGE model. It is scenario-
  responsive in the harvest pipeline but its reserve declines (-37% by 2100, a pessimistic-mortality
  signature) independent of harvest, which the harmonized reserve + common-harvest framing handles.
- Role: CEM enriches the per-state ensemble where present; it does not gate the CONUS total.
- Status: LOCKED at 26 states to 2100. Stress test passes.

## 3. LANDIS finalized

- Coverage: 9 states (WA, MN, OH, IN, WI, MI, ME, NH, VT) spanning the Northeast, Lake States, PNW, and
  Midwest. LANDIS-II is the most computationally expensive member (per-state IC build + ~20 h CMA-ES
  calibration + statewide build), so full 48-state coverage is impractical in this cycle.
- Finalization: LOCK LANDIS at 9 states as an INDEPENDENT REGIONAL CROSS-CHECK rather than a CONUS-wide
  layer. It sits mid-ensemble in the East (a useful sanity check on FVS/CBM/YC) and contributes to the
  per-state ensemble where present. Expansion is available any time via the documented recipe (build_plot
  scenario + apply_theta + baseline -> calibrate -> run_statewide_buildfresh -> add to the reserve), and
  the highest-value additions are CEM-covered states (KY, MD, WV, NJ) to widen the all-model overlap.
- Role: regional check; does not gate the CONUS total.

## 3b. CEM donor-pool scope — yes, it changes the projection (intra-CEM uncertainty)

CEM is a conditional empirical model: each subject plot's future is imputed from a DONOR POOL of
remeasured FIA plots matched on condition. The pool scope is configurable (R/00_config.R: "additional
states for donor plot pool, neighbors or ecologically similar"). The CEM team tested scope sensitivity
and the answer is that it matters:
- Same-state-only: too few donors, noisy/sparse matching.
- Full-CONUS (naive): cross-region contamination - e.g. dry interior-west donors (ID/MT) projecting wet
  PNW westside Douglas-fir/hemlock, or non-plantation donors projecting SE plantations. Biased.
- Production: a REGIONAL / ecologically-similar neighbor pool, STRATIFIED by stand origin and forest type.
  Examples: GA donors = FL+SC+NC+TN+AL; WA donors = OR(+ID+MT or westside-only).
Quantified biases (output/*donor_diagnostic*, multistate_donor_pool_comparison.csv): the GA regional pool
has STDORGCD (planted vs natural) coded as "unknown" while GA is ~31% planted, giving a ~+10% over-
projection bias - the documented driver behind the 3-way stratification fix
(CEM_3WAY_STRATIFICATION_20260517) and the `--untreated_donors` clean-growth-signal filter. The WA
west-of-Cascades prototype showed forest-type composition differs by donor config (full OR+ID+MT vs OR
westside only vs OR-west+WA-west), which shifts the Douglas-fir/hemlock projection.
Bottom line: our harmonized CEM reflects the production regional+stratified pool; donor-pool scope is a
real intra-CEM structural uncertainty (~10%+ in mismatched cases) that the anchor-only CEM band does not
capture. A full-CONUS pool would NOT be apples-to-apples better - it would bias compositionally distinct
states unless stratified.

## 4. Consequence for the CONUS-wide projection

The CONUS-wide projection is COMPLETE and rests on the three full-coverage models (FVS, yield curves, CBM
= 48 states each), across all four scenarios and both disturbance modes, with the ensemble median and
envelope in `harmonized_conus_by_scenario.csv`. CEM (26) and LANDIS (9) are partial-coverage and enrich
the per-state ensemble (`harmonized_ensemble_by_scenario.csv`) where they exist, with credible intervals
that widen appropriately when fewer models are present. This is the honest, apples-to-apples CONUS
finalization: a complete three-model CONUS backbone plus two partial-coverage independent checks, all on
the same FIA anchor, the same common harvest, the same HWP model, and the same disturbance overlay.
