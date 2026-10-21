#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s39_grid --time=02:30:00
#SBATCH --nodes=1 --cpus-per-task=8 --mem=48G --array=1-36
#SBATCH --output=/users/PUOM0008/crsfaaron/s34/grid39_%A_%a.out
# Session 39, 15 Oct 2026. Aaron chose the behavioural realism gate (option 1). Finer grid for NH and VT around
# ANPPmax x2.25 to 2.75 by BiomassMax x2.5 to 3.5, and first grids for WI (1.25 to 1.75 by 2 to 3) and MI (1 to 1.5 by
# 1.5 to 2.5). One array task per run. Mechanics identical to fit_joint_20261007.sh (10 yr anchored smokes on
# initial_communities_20261006, no harvest, multipliers on the run copy of SppEcoregionData_fia_20260929). Run names are
# read as text from fit_grid_20261015.csv. Refuses to overwrite.
set -uo pipefail
L=/fs/scratch/PUOM0008/crsfaaron/landis2; D=$L/states_fb_20260930; G=$D/scripts_20261001/fit_grid_20261015.csv
LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID+1))p" "$G"); IFS=, read -r ST A B RN <<< "$LINE"
SRC=$D/$ST/runs/smoke_20261001_d10; R=$D/$ST/runs/$RN
[ -e "$R" ] && { echo "SKIP $R exists"; exit 0; }
mkdir -p "$R/output/biomass"
for f in scenario.txt biomass_succession.txt climate.csv climate-generator.txt species.txt SpeciesData.csv \
         ecoregions.txt ecoregions.tif initial-communities.tif output_biomass.txt build_summary.csv; do cp "$SRC/$f" "$R/$f"; done
cp "$D/$ST/inputs/initial_communities_20261006/cohort_biomass_by_mapcode_fiadb.csv" "$R/initial-communities.csv"
awk -F, -v b="$B" -v a="$A" 'BEGIN{OFS=","} NR==1{print; next} {$6=int($6*a+0.5); $7=int($7*b+0.5); print}' "$SRC/SppEcoregionData_fia.csv" > "$R/SppEcoregionData_fia.csv"
echo "$ST $RN anpp=$A bmx=$B src=$SRC ic=initial_communities_20261006" > "$R/RUN_SPEC.txt"
cd "$R"
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
  --bind $L/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \
  --bind $L/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \
  --bind $R:$R --pwd $R \
  $L/images/landis-ii_v8_allext_v1.0.sif dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > landis_stdout.txt 2>&1
echo "$ST $RN LANDIS_EXIT=$? complete=$(grep -c 'Model run is complete' Landis-log.txt) $(date +%T)"
