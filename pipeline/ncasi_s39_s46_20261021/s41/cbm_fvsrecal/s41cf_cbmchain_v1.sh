#!/bin/bash
# s41 cbm_fvsrecal: the FVS_FIAW_NEW cell of run_2x2_curves_inventory_DRAFT_2026-09-22.sh (curves=FVS, inventory=FIAW,
# binning=NEW, i.e. the current corrected files) for one state, run in a SANDBOX root so nothing in the shared
# cbm_states tree is written. The sandbox has a copy of states/<ST>/config, symlinks to every top level entry of
# states/<ST>/data/processed EXCEPT sit_yield.csv (the curve input, copied in) and gcbm_input_<ST>.db (written fresh),
# and its own cross_state/libcbm/<ST>. The four pipeline scripts are the shared ones, read only, pointed at the sandbox
# through CBM_STATES_ROOT, with the same arguments as the 2x2 driver.
# usage: s41cf_cbmchain_v1.sh <ST> <sit_yield.csv> <outdir>
set -uo pipefail
ST=$1; SY=$2; OUT=$3
C=/users/PUOM0008/crsfaaron/cbm_states
[ -e "$OUT/$ST" ] && { echo "ABORT: $OUT/$ST exists"; exit 1; }
R=$OUT/$ST/root
mkdir -p $R/states/$ST/config $R/states/$ST/data/processed $R/cross_state/libcbm/$ST
cp -p $C/states/$ST/config/* $R/states/$ST/config/
for f in $C/states/$ST/data/processed/*; do
  b=$(basename "$f")
  [ "$b" = sit_yield.csv ] && continue
  [ "$b" = "gcbm_input_${ST}.db" ] && continue
  ln -s "$f" "$R/states/$ST/data/processed/$b"
done
cp -p "$SY" $R/states/$ST/data/processed/sit_yield.csv
ln -s $C/shared $R/shared
for f in $C/states/$ST/*; do b=$(basename "$f"); [ "$b" = config ] || [ "$b" = data ] || ln -s "$f" "$R/states/$ST/$b"; done
for f in $C/states/$ST/data/*; do b=$(basename "$f"); [ "$b" = processed ] || ln -s "$f" "$R/states/$ST/data/$b"; done
P=$R/states/$ST/data/processed
PIX=$(ls -t $C/states/$ST/data/processed/pixel_attributes_fia_*.csv | head -1)
AREA=$(awk -F, 'NR>1{s+=$2}END{printf "%.0f", s}' "$P/fia_expns_grp_areas_${ST}.csv")
echo "### $ST curves $(md5sum < $SY | cut -c1-32) area $AREA pix $(basename $PIX)"
export CBM_STATES_ROOT=$R
cd $C
python3 -u shared/tools/build_gcbm_input_state.py "$ST" > $OUT/$ST/gcbm.log 2>&1; echo "gcbm rc=$?"
grep -E "^Resolved|WARN" $OUT/$ST/gcbm.log
grep -q "$R/states/$ST/data/processed/gcbm_input_${ST}.db" $OUT/$ST/gcbm.log || { echo "ABORT: gcbm db not written in sandbox"; exit 1; }
BD=$OUT/$ST/bundle; mkdir -p $BD
python3 -u cross_state/libcbm/build_libcbm_state_bundle.py "$ST" --total-area-ha "$AREA" --age-distribution auto \
  --pixel-attrs-csv "$PIX" --fia-expns-csv "$P/fia_expns_grp_areas_${ST}.csv" > $OUT/$ST/bundle.log 2>&1; echo "bundle rc=$?"
grep -E "GCBM input db|Loaded age|Wrote .*sit_inventory" $OUT/$ST/bundle.log
grep -q "GCBM input db: $R/" $OUT/$ST/bundle.log || { echo "ABORT: bundle did not read the sandbox gcbm db"; exit 1; }
for f in sit_classifiers.csv sit_yield.csv sit_events.csv sit_inventory.csv; do cp -p $R/cross_state/libcbm/$ST/$f $BD/$f; done
AD=$OUT/$ST/adapted_FVS_FIAW_NEW
python3 -u cross_state/libcbm/adapt_state_to_libcbm.py "$ST" "$AD" --bundle-dir "$BD" --total-area-ha "$AREA" > $OUT/$ST/adapt.log 2>&1; echo "adapt rc=$?"
grep -E "yield strata|inventory rows|events:" $OUT/$ST/adapt.log
python3 -u cross_state/libcbm/run_libcbm.py "$AD/sit_config.json" "$OUT/$ST/libcbm_pools_${ST}_FVS_FIAW_NEW_50yr.csv" --years 50 \
  --db-path "$C/states/$ST/data/processed/cbm_defaults_${ST}.db" > $OUT/$ST/run50.log 2>&1; echo "run50 rc=$?"
