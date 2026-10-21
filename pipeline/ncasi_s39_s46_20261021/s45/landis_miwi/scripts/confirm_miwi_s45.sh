#!/bin/bash
# s45 Track M copy of ~/s34/confirm_mi_20261015.sh and confirm_wi_20261015.sh (session 40). Differences only:
# (1) the table is NOT written: the existing s40 table is used read only after an md5 check (s40 refused to run if it existed);
# (2) the run folder is in the s45 track folder, run name confirm_seed<SEED>; (3) RandomNumberSeed set from SEED env (s40: 1234 from copied scenario.txt).
# Usage: ST=MI|WI SEED=<int> bash confirm_miwi_s45.sh
set -uo pipefail
L=/fs/scratch/PUOM0008/crsfaaron/landis2; D=$L/states_fb_20260930; TK=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/landis_miwi
case "$ST" in MI) A=1; B=2.5; PE=0.1; M5=b8752e12bf80bacdfb319f5808b8c225;; WI) A=1.6; B=3.5; PE=0.1; M5=46aa9ec78d3b5b8d6e445ad2c8968fc5;; *) echo BAD_ST; exit 5;; esac
T=$D/$ST/inputs/SppEcoregionData_fia_20261015.csv
[ "$(md5sum $T | cut -c1-32)" = "$M5" ] || { echo "TABLE MD5 MISMATCH $T"; exit 4; }
echo "$ST table $(md5sum $T)"
RN=confirm_seed$SEED; SRC=$D/$ST/runs/smoke_20261001_d10; R=$TK/runs/$ST/$RN
[ -e "$R" ] && { echo "SKIP $R exists"; exit 0; }
mkdir -p "$R/output/biomass"
for f in scenario.txt biomass_succession.txt climate.csv climate-generator.txt species.txt SpeciesData.csv \
         ecoregions.txt ecoregions.tif initial-communities.tif output_biomass.txt build_summary.csv; do cp "$SRC/$f" "$R/$f"; done
sed -i -E "s/^(RandomNumberSeed[[:space:]]+)[0-9]+/\1$SEED/" "$R/scenario.txt"
grep -q "^RandomNumberSeed[[:space:]]*$SEED\$" "$R/scenario.txt" || { echo SEED_NOT_SET; exit 6; }
cp "$D/$ST/inputs/initial_communities_20261006/cohort_biomass_by_mapcode_fiadb.csv" "$R/initial-communities.csv"
awk -F, 'NR==FNR{if(FNR>1) e[$2]=1; next} FNR==1 || ($2 in e)' "$SRC/SppEcoregionData_fia.csv" "$T" > "$R/SppEcoregionData_fia.csv"
echo "rows src $(wc -l < $SRC/SppEcoregionData_fia.csv) run $(wc -l < $R/SppEcoregionData_fia.csv)"
echo "$ST $RN table=inputs/SppEcoregionData_fia_20261015.csv (filtered) anpp=$A bmx=$B pe=$PE ic=initial_communities_20261006 seed=$SEED (s45 copy)" > "$R/RUN_SPEC.txt"
cd "$R"
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
  --bind $L/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \
  --bind $L/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \
  --bind $R:$R --pwd $R \
  $L/images/landis-ii_v8_allext_v1.0.sif dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > landis_stdout.txt 2>&1
echo "$ST $RN LANDIS_EXIT=$? complete=$(grep -c 'Model run is complete' Landis-log.txt) $(date +%T)"
