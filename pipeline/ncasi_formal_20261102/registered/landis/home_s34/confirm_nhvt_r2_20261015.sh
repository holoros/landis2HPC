#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s39_conf2 --time=01:30:00
#SBATCH --nodes=1 --cpus-per-task=8 --mem=48G --array=0-1
#SBATCH --output=/users/PUOM0008/crsfaaron/s34/conf39r2_%A_%a.out
# Session 39, 15 Oct 2026, retry of confirm_nhvt_20261015.sh. The first attempt failed in LANDIS because the full input
# table carries ecoregion rows (NH 82) that are not in the run's ecoregions.txt. The fitted tables written then are kept
# as is (md5 checked below). This run filters the table to the ecoregions in the source run copy, exactly as
# smoke_build_fb_20261001.sh does, and writes into new run folders (_r2).
set -uo pipefail
L=/fs/scratch/PUOM0008/crsfaaron/landis2; D=$L/states_fb_20260930
STS=(NH VT); M5=(d8d5409c3905c55637efb3b63dc92275 d1475aece3661b5472024fa33e11052c)
RNS=(fit_20261015_d10_confirm_a2.55_b3.25_r2 fit_20261015_d10_confirm_a2.30_b2.90_r2); AS=(2.55 2.30); BS=(3.25 2.90)
i=$SLURM_ARRAY_TASK_ID; ST=${STS[$i]}; RN=${RNS[$i]}
T=$D/$ST/inputs/SppEcoregionData_fia_20261015.csv
[ "$(md5sum $T | cut -c1-32)" = "${M5[$i]}" ] || { echo "TABLE MD5 MISMATCH $T"; exit 4; }
SRC=$D/$ST/runs/smoke_20261001_d10; R=$D/$ST/runs/$RN
[ -e "$R" ] && { echo "SKIP $R exists"; exit 0; }
mkdir -p "$R/output/biomass"
for f in scenario.txt biomass_succession.txt climate.csv climate-generator.txt species.txt SpeciesData.csv \
         ecoregions.txt ecoregions.tif initial-communities.tif output_biomass.txt build_summary.csv; do cp "$SRC/$f" "$R/$f"; done
cp "$D/$ST/inputs/initial_communities_20261006/cohort_biomass_by_mapcode_fiadb.csv" "$R/initial-communities.csv"
awk -F, 'NR==FNR{if(FNR>1) e[$2]=1; next} FNR==1 || ($2 in e)' "$SRC/SppEcoregionData_fia.csv" "$T" > "$R/SppEcoregionData_fia.csv"
echo "rows src $(wc -l < $SRC/SppEcoregionData_fia.csv) run $(wc -l < $R/SppEcoregionData_fia.csv)"
echo "$ST $RN table=inputs/SppEcoregionData_fia_20261015.csv (filtered to run ecoregions) anpp=${AS[$i]} bmx=${BS[$i]} ic=initial_communities_20261006" > "$R/RUN_SPEC.txt"
cd "$R"
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
  --bind $L/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \
  --bind $L/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \
  --bind $R:$R --pwd $R \
  $L/images/landis-ii_v8_allext_v1.0.sif dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > landis_stdout.txt 2>&1
echo "$ST $RN LANDIS_EXIT=$? complete=$(grep -c 'Model run is complete' Landis-log.txt) $(date +%T)"
