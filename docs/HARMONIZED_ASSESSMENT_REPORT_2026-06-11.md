# Harmonized multi-model CONUS forest carbon assessment

Refreshed synthesis, 2026-06-11. Aaron Weiskittel, CRSF / OSC Cardinal (PUOM0008).

> ADDENDUM 2026-06-12 (harvest recalibration, supersedes the harvest-scenario numbers below).
> A cross check against Nash and Domke 2026 (Carbon Balance and Management) showed the TM2016 derived HCS
> common harvest systematically under detected removals, badly in the West (Oregon near zero vs FIA 1.06
> %/yr) and severalfold in the East. The common harvest was recalibrated to the FIA NFI removal benchmark
> (rFIA growMort REMV_PERC, all 48 states; the same base method as Nash) and PROMOTED to canonical. The
> reserve backbone is unchanged; the managed scenarios fall and scale with intensity. New CONUS 2100
> ensemble median (Tg C, nodisturb): reserve 24,294 / conservation 20,188 / BAU 15,929 / intensive 11,056
> (was 24,294 / 22,261 / 20,218 / 17,860). Stress test passes; pre calibration canonical backed up in
> FIA/precal_backup_20260612. Full method + a survey (WOODCARBII) sensitivity bracket are in
> HARVEST_RECALIBRATION_PLAN_2026-06-12.md and HWP_BENCHMARK_NASH_DOMKE_2026-06-12.md. The harvest-scenario
> figures in the body below are pre calibration and should be read with this addendum.

## 1. Design

Five independent forest-carbon models (FVS, LANDIS-II, CBM, yield curves, CEM) are placed on
one common pipeline so that model structure is the only thing that differs between them.
Every model trajectory is (a) anchored to the same FIA design estimate of 2025 live aboveground
carbon by state (total(t) = FIA_2025 x perha(t)/perha(2025), so units and carbon fraction cancel),
and (b) driven by the same HCS common harvest under four scenarios (reserve 0x, conservation 0.6x,
business-as-usual 1x, intensive 2x), with a first-order HWP pool. The reserve (no harvest, no
disturbance) is the comparison backbone. FVS additionally spans a 2x2 of default vs Bayesian-calibrated
parameters and FIADB vs TreeMap allocation.

Coverage: FVS, yield curves, CBM = 48 states; CEM = 26; LANDIS = 9 (WA MN OH IN WI MI ME + NH VT, the
last two added this cycle). Full-model overlap (all five): IN, OH, NH.

## 2. Refinements applied this assessment cycle

1. CBM eastern under-initialization corrected. The CBM spin-up started many eastern states at ~40%
   of FIA stocking, so the no-disturbance reserve "regrew" 150-207%. An entry-point correction
   (`build_cbm_reserve.R --align`) enters CBM's own carrying-capacity curve at the FIA stocking,
   cutting eastern growth to a plausible 50-87% and the under-init flags from 30 states to 5.
2. Disturbance/climate overlay (`apply_disturbance_overlay.R`). The reserve is a no-disturbance
   ceiling; the overlay subtracts a state fire-mortality rate (base from the CBM LCMS-natural runs,
   ramped per the Oregon report). Disturbance-aware CONUS 2100 reserve median 24.3 -> 23.1 Pg C, and
   inter-model CV 21.5% -> 19.3%.
3. FVS diameter-growth calibration adopted for all 18 unadopted variants (it had reached only 7).
   This was a genuine deployment gap, now fixed in-pipeline. IMPORTANT: re-running the western FVS
   reserve with the adopted DG showed the western over-projection is NOT a calibration bug - it barely
   moved (CA 272->254%). It is intrinsic to FVS individual-tree no-disturbance dynamics.
4. Western harvest data limitation documented. The TM2016 harvest-probability product assigns harvest
   to 31% of GA forest pixels but 0.03% of OR, so the common harvest under-represents western harvest;
   western scenario contrast is muted by construction (a data-acquisition fix, not a code fix).

## 3. Cross-model comparison with confidence intervals

2100 reserve carbon (Tg C) with 90% CIs, full-model overlap states (`harmonized_crossmodel_ci.csv`).
Each CI combines the FIA anchor SE with the model's intra-model band where available: FVS Bayesian
posterior, CBM OAT envelope, yield-curve rcp + simulation CI; LANDIS and CEM carry anchor SE only.

  IN:  LANDIS 583 [561,605] > FVS_def 359 > FVS_cal 313 ~ CBM 307 > YieldCurve 231 > CEM 126
  OH:  LANDIS 784 > FVS_def 606 > FVS_cal 511 > CBM 409 > YieldCurve 366 > CEM 156
  NH:  FVS_def 408 > FVS_cal 291 > LANDIS 271 > CBM 215 > YieldCurve 178 > CEM 78

Distinguishability (non-overlapping 90% CIs): 14/15 model pairs at IN (only FVS_cal ~ CBM overlap),
15/15 at OH and NH. The roughly 4-5x cross-model spread is statistically real, not sampling noise.

## 4. Uncertainty decomposition

Inter-model (structural) uncertainty dominates. Mean state-level component SD (Tg C):
structural rises 0 (2025) -> 98 (2050) -> 200 (2100); FVS parameter ~21/44/60; FIA sampling ~5/6/6.
On states with a real Bayesian posterior, structural SD is 11x the parameter SD by 2050 and ~40x by
2100. Intra-model bands are uniformly small (FVS ~3%, CBM ~3.2-3.5%, yield curves ~8%), so which model
you choose dominates parameter and sampling error by more than an order of magnitude.

CONUS reserve total (full-coverage FVS/YC/CBM): 2025 15.3 Pg C (shared anchor), 2100 ensemble median
24.3 Pg C no-disturbance / 23.1 Pg C disturbance-aware; full-model envelope 22.3-32.2 Pg C.

## 5. External benchmark validation

Validated against the American Forests state CBM reports (CBM-CFS3 family, same as our CBM): MN, OR
(2026), CA (2025), MD, PA (2023). The reports project the western forest declining (Oregon flips to a
net source by 2029, +825% high-severity fire) and the eastern forest as a near-saturated sink. Our
no-disturbance reserves grow everywhere, which is what exposed the CBM under-initialization and the
need for the disturbance overlay. Direction and order of magnitude now agree where the overlay applies.

## 6. Key scientific findings

- The cross-model divergence is real structural uncertainty, attributable to specific, documented
  causes rather than irreducible noise or pipeline error.
- FVS is the high-biomass-potential end-member: as an individual-tree model it lets western conifers
  aggrade toward their real 400-1000 MgC/ha old-growth potential absent disturbance. Calibration and
  max-SDI are correct; the divergence is structural.
- Adding realistic disturbance both lowers the central estimate and tightens inter-model disagreement,
  because the divergence lived in the no-disturbance ceiling.
- LANDIS sits mid-ensemble in the East (IN/OH/NH), a useful independent check.

## 6b. Finalized CONUS projection matrix (all scenarios x disturbance modes)

All five models run all four harvest scenarios across CONUS, in both no-disturbance and disturbance-
aware modes. Consolidated in `harmonized_master_all_scenarios.csv` (model x mode x state x scenario),
`harmonized_ensemble_by_scenario.csv` (per-state ensemble best estimate + 90% CI), and
`harmonized_conus_by_scenario.csv`. Ensemble median CONUS 2100 total carbon (standing + HWP, Tg C):

  scenario       no-disturbance   disturbance-aware
  reserve            24,294           23,074
  conservation       22,261           21,061
  BAU                20,218           19,040
  intensive          17,860           16,714

The harvest gradient is monotonic (more harvest -> less total carbon), about a 26% reserve-to-intensive
drop; the disturbance overlay lowers each scenario a further ~5%. Per state the scenario response scales
with harvest intensity: strong in heavily harvested states (GA reserve 962 -> intensive 163 Tg C) and
near-flat in the West (CA ~1,750 across scenarios), the latter reflecting the documented western harvest
under-detection. Full-coverage ensemble uses FVS/YC/CBM (48 states); the per-state ensemble adds LANDIS
and CEM where present.

## 7. Caveats and refinement queue

- Western common harvest under-represents real harvest (data product); a better layer (LCMS/FIA TPO)
  would make western management benchmarks testable.
- CBM eastern correction is an interim entry-point method; a true FIA-initialized CBM run is cleaner.
- Disturbance rates are LCMS-historical + a literature ramp; MTBS/LANDFIRE calibration would firm them.
- LANDIS and CEM intra-model bands are not yet quantified (LANDIS replicate runs; CEM is scenario-invariant).
- Full-CONUS DG-adopted FVS re-extract is in flight (eastern variants); the western result implies the
  headline spread is robust to it.
- A formal ensemble weighting (down-weighting models that fail benchmarks) would yield a single
  best-estimate trajectory with a credible interval.

## 8. Reproducibility

All scripts and outputs in `landis2HPC/harmonized/` and `/fs/scratch/PUOM0008/crsfaaron/FIA/`.
Stress test (`stress_test_harmonized.py`) and benchmark/CI checks (`benchmark_validation.py`,
`build_crossmodel_ci.R`) pass with the documented results. See SESSION_HANDOFF_2026-06-09_MASTER.md,
BENCHMARK_VALIDATION_2026-06-10.md, FVS_SDIMAX_AUDIT_2026-06-10.md, FVS_DG_ADOPTION_GAP_2026-06-10.md.
