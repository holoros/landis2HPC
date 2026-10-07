#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s34_t2cal --time=01:30:00
#SBATCH --nodes=1 --cpus-per-task=8 --mem=96G
#SBATCH --output=/users/PUOM0008/crsfaaron/s34/t2cal_%j.out
# Session 34, 3 Oct 2026. Diagnostic for decision (3), Michigan growth. Does NOT decide it.
# Reruns the 1 Oct unit corrected 10 year smoke for MI and WI with ONE change: the BiomassMax and
# ANPPmax table is the Tier 2 calibrated table from the old Cardinal tree
# (states/<ST>/perseus/statewide/<st>_t2_calibrated/), restricted to the active ecoregions,
# instead of SppEcoregionData_fia_20260929.csv. Every other file is copied from
# smoke_20261001_d10_unitfix. Source files and the 1 Oct runs are not touched. Nothing is promoted.
set -uo pipefail
L=/fs/scratch/PUOM0008/crsfaaron/landis2; D=$L/states_fb_20260930
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
for ST in MI WI; do
  st=$(echo $ST | tr A-Z a-z)
  SRC=$D/$ST/runs/smoke_20261001_d10_unitfix
  R=$D/$ST/runs/smoke_20261003_d10_unitfix_t2cal
  CAL=$L/states/$ST/perseus/statewide/${st}_t2_calibrated/SppEcoregionData_${st}_t2_calibrated.csv
  [ -f "$CAL" ] || { echo "ERROR no $CAL"; continue; }
  [ -e "$R" ] && { echo "ERROR $R exists, refusing to overwrite"; continue; }
  mkdir -p "$R/output/biomass"
  for f in scenario.txt biomass_succession.txt climate.csv climate-generator.txt species.txt SpeciesData.csv \
           ecoregions.txt ecoregions.tif initial-communities.csv initial-communities.tif output_biomass.txt \
           build_summary.csv active_cells_by_ecoregion.csv; do cp "$SRC/$f" "$R/$f"; done
  ECOS=$(awk '$1=="yes"{print $2}' "$R/ecoregions.txt" | tr '\n' ' ')
  H1=$(head -1 "$SRC/SppEcoregionData_fia.csv"); H2=$(head -1 "$CAL" | tr -d '\r')
  [ "$H1" = "$H2" ] || { echo "ERROR header mismatch: $H1 vs $H2"; continue; }
  awk -F, -v E="$ECOS" 'BEGIN{n=split(E,a," "); for(i=1;i<=n;i++) k[a[i]]=1} {sub(/\r$/,"")} NR==1 || ($2 in k)' \
    "$CAL" > "$R/SppEcoregionData_fia.csv"
  echo "$ST rows: baseline $(($(wc -l < $SRC/SppEcoregionData_fia.csv)-1)) calibrated run copy $(($(wc -l < $R/SppEcoregionData_fia.csv)-1))"
  echo "$CAL $(md5sum < $CAL | cut -c1-12)" > "$R/SPP_SOURCE.txt"
  cd "$R"
  apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
    --bind $L/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \
    --bind $L/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \
    --bind $R:$R --pwd $R \
    $L/images/landis-ii_v8_allext_v1.0.sif dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > landis_stdout.txt 2>&1
  echo "$ST LANDIS_EXIT=$? complete=$(grep -c 'Model run is complete' Landis-log.txt)"
done
Rscript $D/scripts_20261001/t2cal_diag_20261003.R
echo ALLDONE
