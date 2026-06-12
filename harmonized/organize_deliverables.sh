#!/bin/bash
# organize_deliverables.sh - copy the canonical harmonized outputs into a tidy _deliverables/
# tree on Cardinal scratch. Non-destructive: originals stay; this is a clean view + the
# publication-ready set. Run on Cardinal: bash organize_deliverables.sh
set -euo pipefail
F=/fs/scratch/PUOM0008/crsfaaron/FIA
D=$F/_deliverables
mkdir -p $D/{00_anchor,01_reserves,02_scenarios,03_ensemble_ci,04_uncertainty,05_benchmark,06_rasters}

cp -f $F/fia_agc_anchor_design_by_state.csv            $D/00_anchor/ 2>/dev/null || true
for r in fvs_reserve_calibrated fvs_reserve_default fvs_reserve_calibrated_v4 \
         cbm_reserve cem_reserve yc_reserve; do
  cp -f $F/${r}_anchored.csv  $D/01_reserves/ 2>/dev/null || true
  cp -f $F/${r}_disturbed.csv $D/01_reserves/ 2>/dev/null || true
done
cp -f $F/harmonized_landis_reserve_9state*.csv        $D/01_reserves/ 2>/dev/null || true
cp -f $F/harmonized_master_all_scenarios.csv          $D/02_scenarios/ 2>/dev/null || true
cp -f $F/harmonized_ensemble_by_scenario.csv          $D/02_scenarios/ 2>/dev/null || true
cp -f $F/harmonized_conus_by_scenario.csv             $D/02_scenarios/ 2>/dev/null || true
cp -f $F/harmonized_best_estimate.csv                 $D/03_ensemble_ci/ 2>/dev/null || true
cp -f $F/harmonized_crossmodel_ci.csv                 $D/03_ensemble_ci/ 2>/dev/null || true
cp -f $F/harmonized_crossmodel_5model.csv             $D/03_ensemble_ci/ 2>/dev/null || true
for u in uncertainty_conus_disturbed cbm_oat_bands cbm_engine_gap yc_bands fvs_posterior_ci_all; do
  cp -f $F/${u}.csv $D/04_uncertainty/ 2>/dev/null || true
done
cp -f $F/uncertainty_by_state_year*.csv               $D/04_uncertainty/ 2>/dev/null || true
cp -f $F/americanforests_cbm_benchmarks.csv           $D/05_benchmark/ 2>/dev/null || true
# rasters: link the GCBM output (when present) rather than copy (large)
[ -d $F/gcbm_rasters ] && ln -sfn $F/gcbm_rasters $D/06_rasters/gcbm 2>/dev/null || true

# carry the catalog
cp -f /fs/scratch/PUOM0008/crsfaaron/landis2HPC/docs/DATA_INDEX.md $D/README.md 2>/dev/null || true

echo "Tidy deliverables tree at $D:"
find $D -type f -o -type l | sed "s|$D/||" | sort
echo
echo "Counts: $(find $D -type f | wc -l) files copied; originals untouched in $F."
