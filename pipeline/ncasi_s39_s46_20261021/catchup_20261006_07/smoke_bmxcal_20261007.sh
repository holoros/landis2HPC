#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s37_bmxcal --time=02:30:00
#SBATCH --nodes=1 --cpus-per-task=8 --mem=96G
#SBATCH --output=/users/PUOM0008/crsfaaron/s34/bmxcal_%j.out
# Session 37, 7 Oct 2026. Two run families, 10 year LANDIS smokes, no harvest or disturbance, Daymet means.
# (A) Formal anchored smoke: the DRYBIO patched, FIADB anchored cohort tables (initial_communities_20261006/
#     cohort_biomass_by_mapcode_fiadb.csv, md5 verified against the firebreather gate record) for NH VT MI WI.
#     Run dir smoke_20261007_d10_anchored. Every other file from smoke_20261001_d10 (the gated 270 m grid).
# (B) BiomassMax calibration probe for decision 3 (Aaron, 7 Oct: resolve open items): NH VT WI with the same
#     anchored IC and BiomassMax x m, m in 1.25 1.5 2.0, ANPPmax unchanged. Run dirs smoke_20261007_d10_anch_bmx<m>.
#     Run copies only; no source table is changed.
# Scored by smoke_bmxcal_diag_20261007.R. Refuses to overwrite any run directory.
set -uo pipefail
L=/fs/scratch/PUOM0008/crsfaaron/landis2; D=$L/states_fb_20260930
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
run_one() {  # ST RUNNAME MULT
  local ST=$1 RN=$2 M=$3
  local SRC=$D/$ST/runs/smoke_20261001_d10 R=$D/$ST/runs/$2
  [ -e "$R" ] && { echo "SKIP $R exists"; return; }
  mkdir -p "$R/output/biomass"
  for f in scenario.txt biomass_succession.txt climate.csv climate-generator.txt species.txt SpeciesData.csv \
           ecoregions.txt ecoregions.tif initial-communities.tif output_biomass.txt build_summary.csv; do cp "$SRC/$f" "$R/$f"; done
  cp "$D/$ST/inputs/initial_communities_20261006/cohort_biomass_by_mapcode_fiadb.csv" "$R/initial-communities.csv"
  awk -F, -v m="$M" 'BEGIN{OFS=","} NR==1{print; next} {$7=int($7*m+0.5); print}' "$SRC/SppEcoregionData_fia.csv" > "$R/SppEcoregionData_fia.csv"
  echo "$ST $RN bmx_mult=$M ic=$(md5sum < $R/initial-communities.csv | cut -c1-12)" > "$R/RUN_SPEC.txt"
  cd "$R"
  apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
    --bind $L/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \
    --bind $L/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \
    --bind $R:$R --pwd $R \
    $L/images/landis-ii_v8_allext_v1.0.sif dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > landis_stdout.txt 2>&1
  echo "$ST $RN LANDIS_EXIT=$? complete=$(grep -c 'Model run is complete' Landis-log.txt)"
}
for ST in NH VT WI MI; do run_one $ST smoke_20261007_d10_anchored 1; done
for ST in NH VT WI; do for M in 1.25 1.5 2.0; do run_one $ST smoke_20261007_d10_anch_bmx$M $M; done; done
Rscript $D/scripts_20261001/smoke_bmxcal_diag_20261007.R
echo "DIAG_EXIT=$?"; echo ALLDONE
