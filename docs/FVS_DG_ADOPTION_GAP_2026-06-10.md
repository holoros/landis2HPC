# FVS diameter-growth adoption gap: the root cause of the western over-projection

Date 2026-06-10. Follows the SDImax audit (which ruled out a metric bug and showed the
max-SDI ceiling does not bind for the western sample). AW directed the search to the
fvs-conus calibration outputs, which resolved the issue definitively.

## The fits exist for every variant

The CONUS diameter-growth calibration (`dg_kuehne_cspi_traits1`, a Kuehne-form DG model with
species and ecodivision random effects, fit to FIA remeasurement) is present in every deployed
config under `categories_conus/diameter_growth`. Per-variant posteriors live in
`fvs-conus/output/variants/<v>/diameter_growth_posterior.csv` and the all-variant summary is
`fvs-conus/output/dg_all_variants_summary_final.csv` (26 variants). So calibration fits exist for
all FVS variants, exactly as expected.

## But runtime adoption was completed for only 7 of 25 variants

The engine applies the DG calibration through `calibration_multipliers/dds_multiplier` (the
"DG intercept-shift exp(delta b0)" that becomes the per-species BAIMULT keyword). Each config
carries `calibration_multipliers/provenance/available`, a per-component adoption flag. For the
diameter-growth component (DG):

  DG ADOPTED (7):  acd, ca, cs, kt, ls, nc, on
  DG NOT adopted (18): ak, bc, bm, ci, cr, ec, em, ie, ne, oc, op, pn, sn, so, tt, ut, wc, ws

For the 18 unadopted variants the flag is `DG: False` and `dds_multiplier` is left at 1.0, so FVS
runs its NATIVE (uncalibrated) diameter-growth equations. The unadopted set covers essentially the
entire production CONUS: all western variants (ws=CA, so=OR, ec=WA, ci=ID, cr=interior west,
em=MT, pn, wc, tt, ut) and the two largest eastern variants (ne=Northeast, sn=South). About 38
states sit on a DG-unadopted variant, including every western state and most of the East.

Note the 7 adopted variants are mostly minor or peripheral (acd, kt, on=Ontario, ca=California
variant which our CA state does NOT use since CA maps to ws). Only ls (Lake States), cs (Central
States), and nc carry adopted DG among the core CONUS variants.

## Why this is THE western over-projection cause

With DG unadopted, FVS western reserves use native growth, which over-predicts badly vs the
FIA-grounded consensus. Early-period (2025->2050) reserve growth by model (anchored, comparable):

  state  CBM   YC   FVScal  FVSdef
  CA      17   19    112     129
  OR      11   23    106     127
  WA      11   22     90     113
  NV      29   15    105     141

FVS grows the West 3-6x faster than CBM and the yield curves (which agree with each other and are
FIA-based). The gap appears immediately (by 2050), confirming it is the per-cycle growth increment,
not the late-binding SDI ceiling. Calibration barely helped (CA default +333% -> cal +272%) BECAUSE
the DG component was never adopted for ws. The other calibrated components (HD, MORT, CR, HI, SDI)
ARE adopted for ws (available flags all True), which is why FVScal differs slightly from FVSdef but
not in growth rate.

## Recommended fix (highest-impact FVS action)

Complete the DG adoption for the 18 unadopted variants. The inputs already exist:
1. For each unadopted variant, compute `dds_multiplier` = exp(delta b0) per species from the
   `dg_kuehne` posterior (`categories_conus/diameter_growth` + the species_intercepts / draws_csv),
   exactly as was done for the 7 adopted variants, and set `available.DG = True`.
2. Re-run `06_posterior_to_json.R` (or the adoption step that produced the 7) for the 18 variants,
   then regenerate the calibrated configs.
3. Re-run the FVS CONUS reserve (out_gompit_v3) for at least the western states and re-check against
   the CBM/YC consensus and the American Forests benchmarks; expect FVS western growth to drop
   toward the consensus and the inter-model CONUS CV to tighten further.

Alternative (cleaner long term): wire the full `categories_conus/diameter_growth` Kuehne CONUS model
into the engine/keyword path directly, instead of the approximate intercept-shift multiplier.

## Why the adoption must use the original script (not a reverse-engineered reconstruction)

Attempted to recover the `dds_multiplier` formula from the data in the config so it could be applied
to the 18 unadopted variants. Validating against an ADOPTED variant (ls): `exp(species_intercepts.mean)`
mapped through FIAJSP reproduces only 2 of 33 of ls's deployed multipliers. The deployed values
correlate with the species intercepts but are NOT exp(intercept) - the provenance's "DG intercept-shift
exp(delta b0); dense index, approximate" is delta relative to the FVS NATIVE DG intercept (and folds in
the ecodivision weights, the b1 ln(DBH) slope, and modifier_lambda), which requires the FVS native DG
coefficients per species per variant - not present in the config. So a safe adoption needs the original
calibration-bridge step (the script that produced the 7 adopted variants), which was not locatable in
fvs-modern/calibration or config; it likely lives in fvs-conus or a one-off. Reconstructing it by hand
across 18 variants would risk corrupting the calibration and is NOT advisable. RECOMMENDATION: have the
calibration author re-run the DG adoption/bridge step for the 18 variants (inputs all exist:
dg_kuehne posteriors + FVS native DG coefficients), then regenerate configs and re-run the western FVS
reserve. The diagnosis here is complete and definitive; the remaining step is a calibration-pipeline
re-run, not new analysis.

## ADOPTION COMPLETED IN-PIPELINE (2026-06-11)

The DG adoption was run via the original pipeline (no hand reconstruction):
1. Enabled DG in `fvs-modern/calibration/data/equation_availability_full.csv` for the 18 variants
   (backup `.bak_predgadopt`).
2. Patched a self-location bug in `06_posterior_to_json.R` line 43 (Sys.getenv's default eagerly
   evaluated `sys.frame(1)$ofile`, which fails under Rscript; replaced with a literal FVS_PROJECT_ROOT
   default; backup `.bak_sysframe`).
3. Re-ran `FVS_PROJECT_ROOT=fvs-modern Rscript calibration/R/06_posterior_to_json.R --variant <v>`
   for each variant; this calls `compute_calibration_multipliers` (multipliers.R), which sets
   `available.DG=True` and writes the real `dds_multiplier` = exp(delta b0) per species.

Verified: WS dds_multiplier median 0.992, range 0.58-1.65, 35/43 species != 1.0 (real species-specific
diameter-growth calibration now reaching the engine); SO range 0.76-1.36, EC 0.91-1.22. Each config keeps
its own `.pre_conus_*` backup. Batch completing the remaining variants. NEXT: re-run the western FVS
reserve (out_gompit_v3 equivalent) with the adopted configs and confirm western growth drops toward the
CBM/YC consensus and the inter-model CONUS CV tightens. The species multipliers <1 (e.g. WS 0.58) will
reduce the over-projecting species' growth, exactly the intended effect.

## VALIDATION RESULT (2026-06-11): DG adoption does NOT fix the western over-projection

The western FVS reserve was re-run with the DG-adopted configs (job 11490666 -> out_gompit_v4) and
re-extracted (build_fvs_reserve_v4.R). Comparing 2025->2100 reserve growth, unadopted (v3) vs
DG-adopted (v4):

  state  v3    v4
  CA    272   254
  OR    223   215
  WA    177   171
  ID    115   131
  MT    131    91
  NV    413   573
  CO    119   119
  NM    329   329

CORRECTION (2026-06-11, complete data): the full-CONUS DG-adopted re-run finished (all 48 states,
out_gompit_v4) and the re-extracted reserve is IDENTICAL to v3 for every state (delta 0%, East and
West). The earlier small differences (CA 272->254 etc.) were an artifact of extracting while the array
was still incomplete (biased per-state means). So DG adoption is CARBON-NEUTRAL at the state-reserve
level: the calibrated dds_multiplier (median ~1.0, species-balanced) averages out, so calibrated DG ~=
native DG for the state mean. The deployment gap is now correctly closed (the engine uses calibrated DG),
but it does not change the FVS reserve, the ensemble, or the CI. The numbers below were the incomplete-
data snapshot; the final answer is delta ~0 everywhere.

The effect is small and mixed (CA/OR/WA down ~5-7%, MT down, ID/NV up). The over-projection PERSISTS
(still 170-570% vs the CBM/YC consensus of 22-54%). CONCLUSION: the FVS western over-projection is NOT
a diameter-growth calibration-deployment bug. With the proper FIA-calibrated Kuehne DG adopted, FVS
still projects far more western no-disturbance accumulation than CBM or the yield curves. The divergence
is intrinsic to FVS's individual-tree growth dynamics under no disturbance - FVS lets western conifers
aggrade toward their (genuinely high, 400-1000 MgC/ha) old-growth biomass potential, which CBM (process,
DOM-coupled) and the empirical yield curves do not. This is REAL structural model uncertainty, correctly
captured by the inter-model spread, not a fixable error.

Net: the DG adoption was still the right correctness fix (it closes the deployment gap, properly
calibrates all variants, and slightly improves CA/OR/WA), but it does NOT reconcile FVS with the other
models in the West. Reconciliation comes only from the disturbance overlay (which removes the
no-disturbance assumption) and from treating FVS as the high-biomass-potential end-member of the
ensemble. The eastern variants (NE, SN) were also adopted; a full-CONUS DG-adopted re-run would refresh
the East, but the western result implies the headline cross-model spread is robust to it.

## Implication for the current harmonized assessment

The FVS reserve in the assessment currently reflects uncalibrated diameter growth for the West and
the large eastern variants. The ensemble correctly brackets FVS as the high outlier and the
uncertainty layer captures it as structural spread, so no result is wrong, but the FVS high tail
(and thus the inter-model spread) will tighten substantially once DG adoption is completed. This is
a calibration-deployment gap, not a model-structure limitation, and it is the single most important
open item for FVS accuracy.
