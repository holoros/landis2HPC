#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s40_miconf --time=02:30:00 --nodes=1 --cpus-per-task=8 --mem=48G
#SBATCH --output=/users/PUOM0008/crsfaaron/s34/miconf_%j.out
# Session 40 (15 Oct 2026, autopilot). Michigan behavioural gate fit from the ProbEstablish scaling grid
# (pesc_score_20261015.R): ANPPmax x1, BiomassMax x2.5, ProbEstablish x0.1. Writes MI/inputs/SppEcoregionData_fia_20261015.csv
# beside the existing tables from _20260929 (refuses to overwrite; not promoted) and runs a 10 yr anchored confirmation
# smoke from that exact table filtered to the run's ecoregions, as confirm_nhvt_r2_20261015.sh did.
set -uo pipefail
L=/fs/scratch/PUOM0008/crsfaaron/landis2; D=$L/states_fb_20260930; ST=MI; A=1; B=2.5; PE=0.1
T=$D/$ST/inputs/SppEcoregionData_fia_20261015.csv; SRCT=$D/$ST/inputs/SppEcoregionData_fia_20260929.csv
[ -e "$T" ] && { echo "TABLE EXISTS $T"; exit 4; }
awk -F, -v b="$B" -v a="$A" -v pe="$PE" 'BEGIN{OFS=","} NR==1{print; next} {$4=$4*pe; $6=int($6*a+0.5); $7=int($7*b+0.5); print}' "$SRCT" > "$T"
echo "$ST table $(md5sum $T)"
RN=fit_20261015_d10_confirm_a1_b2.5_pe0.1; SRC=$D/$ST/runs/smoke_20261001_d10; R=$D/$ST/runs/$RN
[ -e "$R" ] && { echo "SKIP $R exists"; exit 0; }
mkdir -p "$R/output/biomass"
for f in scenario.txt biomass_succession.txt climate.csv climate-generator.txt species.txt SpeciesData.csv \
         ecoregions.txt ecoregions.tif initial-communities.tif output_biomass.txt build_summary.csv; do cp "$SRC/$f" "$R/$f"; done
cp "$D/$ST/inputs/initial_communities_20261006/cohort_biomass_by_mapcode_fiadb.csv" "$R/initial-communities.csv"
awk -F, 'NR==FNR{if(FNR>1) e[$2]=1; next} FNR==1 || ($2 in e)' "$SRC/SppEcoregionData_fia.csv" "$T" > "$R/SppEcoregionData_fia.csv"
echo "rows src $(wc -l < $SRC/SppEcoregionData_fia.csv) run $(wc -l < $R/SppEcoregionData_fia.csv)"
echo "$ST $RN table=inputs/SppEcoregionData_fia_20261015.csv (filtered) anpp=$A bmx=$B pe=$PE ic=initial_communities_20261006" > "$R/RUN_SPEC.txt"
cd "$R"
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
  --bind $L/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \
  --bind $L/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \
  --bind $R:$R --pwd $R \
  $L/images/landis-ii_v8_allext_v1.0.sif dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > landis_stdout.txt 2>&1
echo "$ST $RN LANDIS_EXIT=$? complete=$(grep -c 'Model run is complete' Landis-log.txt) $(date +%T)"
