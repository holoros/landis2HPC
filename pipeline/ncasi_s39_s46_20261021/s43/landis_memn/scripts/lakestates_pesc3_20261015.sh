#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s40_pe0 --time=02:30:00
#SBATCH --nodes=1 --cpus-per-task=8 --mem=48G --array=1-4
#SBATCH --output=/users/PUOM0008/crsfaaron/s34/pesc3_%A_%a.out
# Session 40 (15 Oct 2026, autopilot). WI third pass: at ANPPmax x1.6, ProbEstablish x0.1, BiomassMax x3 WI just missed
# (mortality 1.18, dense 0.785), and both improved with BiomassMax, so BiomassMax 3.5 and 4 at ProbEstablish 0.1 and 0.2.
# Earlier header: Lake States follow up to the ProbEstablish = 0 diagnosis (pe0 runs showed MI
# recruitment adding about 14 Tg/yr and true mortality 1.7x FIA). ProbEstablish is now SCALED by pe (0, 0.1, 0.25),
# crossed with BiomassMax 2 to 3, ANPPmax x1 (MI) and x1.2 (WI). Original header:
# Lake States diagnosis: why does balance mortality go negative when BiomassMax
# rises? Same 10 yr anchored smokes as fit_behav_20261015.sh, but with ProbEstablish set to 0 for every species and
# ecoregion, so no new cohorts are added and ANPP minus biomass change is true mortality. Paired with the existing
# PE > 0 runs (smoke_20261007_d10_anchored, fit_20261015_d10_a1_b2 for MI, fit_20261007_d10_a1_b2 for WI) the
# difference in net growth is the recruitment contribution. NH a1 b1 is the low ProbEstablish control. Run names read
# as text from pesc_grid_20261015.csv. Refuses to overwrite.
set -uo pipefail
L=/fs/scratch/PUOM0008/crsfaaron/landis2; D=$L/states_fb_20260930; G=$D/scripts_20261001/pesc3_grid_20261015.csv
LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID+1))p" "$G"); IFS=, read -r ST A B PE RN <<< "$LINE"
SRC=$D/$ST/runs/smoke_20261001_d10; R=$D/$ST/runs/$RN
[ -e "$R" ] && { echo "SKIP $R exists"; exit 0; }
mkdir -p "$R/output/biomass"
for f in scenario.txt biomass_succession.txt climate.csv climate-generator.txt species.txt SpeciesData.csv \
         ecoregions.txt ecoregions.tif initial-communities.tif output_biomass.txt build_summary.csv; do cp "$SRC/$f" "$R/$f"; done
cp "$D/$ST/inputs/initial_communities_20261006/cohort_biomass_by_mapcode_fiadb.csv" "$R/initial-communities.csv"
awk -F, -v b="$B" -v a="$A" -v pe="$PE" 'BEGIN{OFS=","} NR==1{print; next} {$4=$4*pe; $6=int($6*a+0.5); $7=int($7*b+0.5); print}' "$SRC/SppEcoregionData_fia.csv" > "$R/SppEcoregionData_fia.csv"
echo "$ST $RN anpp=$A bmx=$B pe=$PE src=$SRC ic=initial_communities_20261006" > "$R/RUN_SPEC.txt"
cd "$R"
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
  --bind $L/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \
  --bind $L/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \
  --bind $R:$R --pwd $R \
  $L/images/landis-ii_v8_allext_v1.0.sif dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > landis_stdout.txt 2>&1
echo "$ST $RN LANDIS_EXIT=$? complete=$(grep -c 'Model run is complete' Landis-log.txt) $(date +%T)"
