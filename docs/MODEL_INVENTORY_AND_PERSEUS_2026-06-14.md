# Harmonized assessment: full model inventory, stress test, and PERSEUS resolution plan

Date 2026-06-14. A step-back across the five-model harmonized CONUS carbon assessment: where
each model stands, a state x scenario x model stress test, refinement recommendations, and the
spatial / temporal / strata resolution at which the spatial members can feed PERSEUS without
losing decision-relevant information.

## 1. Model inventory (reserve, no-disturbance, 2100)

| Model       | States | Scenarios | Horizon | Median state 2100 (Tg C) | Intra-model band | Status |
|-------------|--------|-----------|---------|--------------------------|------------------|--------|
| FVS (cal)   | 48     | 4         | 2100    | 529                      | Bayesian posterior ~3% | calibrated; West over-projects (intrinsic) |
| FVS (def)   | 48     | 4         | 2100    | 702                      | posterior ~3%    | default params (high end-member) |
| CBM         | 48     | 4         | 2100    | 508                      | OAT + GCBM engine gap | libcbm; eastern entry-point corrected; ME engine gap now measured (-10% at 2050) |
| YieldCurve  | 48     | 4         | 2100    | 431                      | rcp + sim ~8%    | re-anchored to common harvest |
| CEM         | 36->48 | 4         | 2100    | 120                      | anchor SE        | 33 states native-2100; 15 relaunched (48h wall); low end-member |
| LANDIS-II   | 9      | 4         | 2100    | 838                      | anchor SE        | per-plot; 270m spatial deck reconstructed (1 keyword block from running) |

Full SIX-model overlap: IN, NH, OH, WA (4 states). Five-model: 37 states. Coverage limiter is
LANDIS (9) and CEM (36->48); CEM completion lifts the six-model overlap toward 9.

## 2. Stress test (model x state x scenario)

Source: harmonized_master_all_scenarios.csv (6 models x 2 disturbance modes x state x 4 scenarios).

- ANOMALIES: zero. 0 negative/zero carbon rows; 0 non-monotonic harvest gradients (reserve >=
  conservation >= BAU >= intensive holds for every model x state x mode); 0 reserve-with-HWP rows.
  The harmonized scenario engine is internally consistent everywhere.
- SCENARIO GRADIENT (CONUS 2100 Pg C, no-disturbance): every model is monotone reserve->intensive,
  e.g. FVS_cal 32.2/27.4/22.3/16.0; CBM 24.3/20.2/15.9/11.1; YC 22.3/18.0/13.5/8.7. The ~26-50%
  reserve->intensive drawdown is consistent across models.
- CROSS-MODEL DIVERGENCE (reserve 2100): median across states CV = 45.8%, median fold-range 3.9x.
  Divergence is CONCENTRATED IN THE WEST: NV 8.2x, NM 10.7x, CA 8.6x, CO 7.5x, WA 6.0x, OR 3.3x.
  Eastern states are tighter (IN/OH/NH fold ~2-3x). This is the known structural signal: FVS
  individual-tree no-disturbance growth diverges most where stands are old and disturbance-prone
  (the West), while CBM/YC/CEM sit lower. It is real model-structure spread, not error.

## 3. Per-model refinement recommendations (priority)

1. CEM completion (IN FLIGHT): 15 states relaunched with a 48 h wall (timed out at 20 h). Finishing
   them brings CEM to 48 native-2100 and the six-model overlap to ~9. Highest near-term value.
2. FVS West (structural, documented): the West fold-range is intrinsic to no-disturbance individual-
   tree growth. Refinement is not recalibration but DISTURBANCE: the disturbance overlay already
   pulls it down; the better fix is the measured western fire/harvest layer (LCMS/MTBS + FIA TPO) so
   the western scenario contrast and the OR net-source benchmark become testable.
3. CBM engine gap: the Maine GCBM run MEASURED the gap at -10% by 2050 (vs the +21% regional
   default), because the entry-point correction closed most of it. Re-measure for the other states
   (MN/WA/OR/CA/GA stacks tiled) to replace the regional defaults; this likely NARROWS CBM
   uncertainty in the corrected-libcbm states.
4. LANDIS: finish the 270m spatial deck (one trailing-keyword block) for the spatial-vs-plot ME
   check, and add the measured replicate band; LANDIS remains a 9-state regional cross-check.
5. YieldCurve: lowest-effort full-coverage member; consider a stand-origin (planted/natural) split
   to reduce its SE in plantation-heavy SE states.

## 4. PERSEUS ingestion: spatial / temporal / strata resolution (GCBM Maine, AG live C)

Analysis on the retained GCBM Maine aboveground-live-C map (28 m native, 123.5 M forest cells),
resolution_strata_gcbm.R. Goal: the coarsest representation that keeps decision-relevant signal.

### Temporal: coarsen aggressively (biggest, cheapest win)
The reserve trajectory is nearly linear (444.98 -> 459.94 Tg C, 2030-2050). Reconstructing the full
5-yr series from 10-yr steps gives <=0.04% error; from 15-yr steps <=0.02%. RECOMMENDATION: store
PERSEUS carbon at 10-year steps (2030, 2040, ... 2100). That is a 2-3x reduction in temporal volume
with no meaningful loss. (Disturbed/managed scenarios are less smooth; keep 5-yr where harvest or
fire pulses occur, 10-yr for reserve and conservation.)

### Spatial: 250 m is the practical floor; total needs a forest-fraction layer
| Resolution | Spatial variance retained | Total-C inflation if treated as fully forest |
|-----------|---------------------------|----------------------------------------------|
| 28 m (native) | 100%                  | 0%                                           |
| 83 m      | 63%                       | +11%                                         |
| 250 m     | 47%                       | +19%                                         |
| 750 m     | 38%                       | +25%                                         |
| ~1 km     | 37%                       | +26%                                         |
Two findings: (a) pixel-scale heterogeneity falls fast (half lost by 250 m) because forest carbon
varies at stand scale; (b) coarsening the DENSITY map alone inflates total carbon via forest-edge
blurring. RECOMMENDATION: do not ship a coarse density map alone. Either keep a co-coarsened
forest-FRACTION (area) layer so totals stay conserved, or summarize by strata (below). For PERSEUS
display, 250 m is a reasonable visual grain; for accounting, use strata.

### Strata: the right representation for PERSEUS (huge compression, signal-preserving)
Decision-support operates at management-unit / forest-type scale, not pixels. Stand-age class alone
(8 classes) already explains 46% of pixel variance, the same as a 250 m raster, but as EIGHT
numbers instead of 1.8 M cells. The standard CBM/FIA stratification (forest-type group x ecoregion
x age class, ~ tens to low hundreds of strata) captures the between-unit signal that PERSEUS needs
while compressing 123 M pixels to a small table per scenario per year. RECOMMENDATION: ingest the
spatial members into PERSEUS as STRATUM x YEAR carbon tables (forest-type x ecoregion x age-class
mean C + area), at 10-yr steps, with the forest-area layer retained for exact totals. Keep the
full-resolution rasters archived (Zenodo) for mapping, but drive the tool from strata.

### Net PERSEUS recommendation
Feed PERSEUS: (1) state x scenario x model x year carbon + NPV (the master matrix, already compact),
plus (2) for the spatial members, forest-type x ecoregion x age-class stratum tables at 10-yr steps
with stratum area. This preserves total carbon exactly, preserves the between-stratum signal
managers act on, and reduces the spatial data from hundreds of millions of pixel-steps to small
tables, while the native rasters stay archived for visualization.

## 5. Artifacts
Inventory: inv_model_summary.csv, inv_coverage_matrix.csv, inv_crossmodel_divergence.csv.
PERSEUS: perseus_spatial_resolution.csv, perseus_temporal_steps.csv, perseus_age_strata.csv.
Scripts: inventory_stress.R, resolution_strata_gcbm.R (landis2HPC/harmonized/).
Caveat: the resolution/strata numbers are from Maine GCBM (the only retained spatial member); the
qualitative conclusions (coarsen time hard, stratify space) generalize, but per-region strata counts
should be re-derived as the other GCBM states and the LANDIS 270m run land.
