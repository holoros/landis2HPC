#!/bin/bash
# add_state.sh — bootstrap a new PERSEUS state under the cluster-warmstart pattern.
#
# Reads the cluster reference theta and extension literature, downloads the state FIA,
# builds plot_to_ecoregion + SppEcoregionData baseline + apply_theta + build_plot_scenario
# from the cluster template, and submits the T2 v1 calibration chain.
#
# Per-state cost: ~1 day (FIA download + extension literature) + ~1.5 days calibration.
# vs. 5 days from scratch.
#
# Prerequisite: cluster reference frozen at $TEMPLATES/cluster_${CLUSTER}_reference_theta.csv
# and extension literature CSV at $TEMPLATES/cluster_${CLUSTER}_extension_species.csv.
#
# Usage:  bash add_state.sh <FIPS> <STATE_CODE> <CLUSTER> [DRY_RUN]
#   FIPS: 2-digit US state FIPS code (e.g., 36 for NY)
#   STATE_CODE: 2-letter abbreviation (e.g., NY)
#   CLUSTER: one of N1, N2, N3, N4, S1, S2, P1, P2, R1, R2, R3, P3, P4 (see conus_ecoregion_clusters.md)
#   DRY_RUN: optional. If "dry", build files but do not submit chain.
#
# Example: bash add_state.sh 36 NY N4

set -uo pipefail
if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <FIPS> <STATE_CODE> <CLUSTER> [dry]"
  exit 1
fi
FIPS=$1; ST=$2; CLUSTER=$3; DRY=${4:-}

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
TOOLS=$LANDIS/tools
TEMPLATES=$LANDIS/tools/state_templates
STATE=$LANDIS/states/$ST
PERSEUS=$STATE/perseus
INPUTS=$STATE/inputs
FIA_FOLDER=$LANDIS/FIA
LOG=$STATE/add_state.log

# Sanity checks
[ -f "$TEMPLATES/cluster_${CLUSTER}_reference_theta.csv" ] || { echo "ERROR: cluster $CLUSTER reference theta not found"; exit 2; }
[ -f "$TEMPLATES/cluster_${CLUSTER}_extension_species.csv" ] || { echo "WARN: no extension species for $CLUSTER (means no new species beyond reference); proceeding"; }
[ "${#FIPS}" -ne 2 ] && { echo "ERROR: FIPS must be 2 digits"; exit 2; }
[ "${#ST}" -ne 2 ] && { echo "ERROR: STATE_CODE must be 2 letters"; exit 2; }

mkdir -p $STATE $PERSEUS $INPUTS
echo "=== add_state $ST (FIPS=$FIPS) cluster=$CLUSTER started $(date) ===" > $LOG

# Step 1: download FIA tables for the state
echo "[1/6] Downloading FIA state $FIPS..." | tee -a $LOG
FIA_URL="https://apps.fs.usda.gov/fia/datamart/CSV/${FIPS}_FIA.zip"
if [ ! -d "$FIA_FOLDER/${FIPS}" ]; then
  mkdir -p $FIA_FOLDER/${FIPS}
  wget -q -P /tmp "$FIA_URL" 2>>$LOG || { echo "ERROR: FIA download failed"; exit 3; }
  unzip -q /tmp/${FIPS}_FIA.zip -d $FIA_FOLDER/${FIPS} 2>>$LOG
  rm /tmp/${FIPS}_FIA.zip
  echo "  done: $(ls $FIA_FOLDER/${FIPS} | wc -l) FIA tables" >> $LOG
else
  echo "  already present" >> $LOG
fi

# Step 2: build state SppEcoregionData baseline from cluster reference
echo "[2/6] Building SppEcoregionData from cluster $CLUSTER reference..." | tee -a $LOG
# Combine reference cluster ANPP+BMAX values with state-specific ecoregion list
python3 $TOOLS/build_state_sppecoregion.py \
  --state "$ST" --cluster "$CLUSTER" \
  --cluster-reference "$TEMPLATES/cluster_${CLUSTER}_reference_theta.csv" \
  --extension-species "$TEMPLATES/cluster_${CLUSTER}_extension_species.csv" \
  --out "$INPUTS/SppEcoregionData.csv" 2>>$LOG
echo "  $(wc -l < $INPUTS/SppEcoregionData.csv) rows" >> $LOG

# Step 3: build plot_to_ecoregion lookup from FIA + EPA L3 raster
echo "[3/6] Building plot_to_ecoregion lookup..." | tee -a $LOG
python3 $TOOLS/build_plot_to_ecoregion.py \
  --state "$ST" --fips "$FIPS" --fia-folder "$FIA_FOLDER/$FIPS" \
  --ecoregion-shapefile /users/PUOM0008/crsfaaron/Disturbance/us_eco_l3.shp \
  --out "$TOOLS/plot_to_ecoregion_${ST}.csv" 2>>$LOG
echo "  $(wc -l < $TOOLS/plot_to_ecoregion_${ST}.csv) plots mapped" >> $LOG

# Step 4: build initial-communities raster from FIA
echo "[4/6] Building IC raster from FIA..." | tee -a $LOG
python3 $TOOLS/build_plot_ics_${CLUSTER}.py \
  --state "$ST" --fips "$FIPS" --fia-folder "$FIA_FOLDER/$FIPS" \
  --out "$PERSEUS/plot_ics_full" 2>>$LOG || \
  python3 $TOOLS/build_plot_ics_MN.py --state "$ST" --fips "$FIPS" --fia-folder "$FIA_FOLDER/$FIPS" --out "$PERSEUS/plot_ics_full" 2>>$LOG
echo "  $(ls $PERSEUS/plot_ics_full/plot_*.tif 2>/dev/null | wc -l) plot IC rasters" >> $LOG

# Step 5: clone the build_plot_scenario_${ST}.sh from the cluster template
echo "[5/6] Generating build_plot_scenario_${ST}.sh + apply_theta_${ST}_perspecies.py..." | tee -a $LOG
sed "s/{ST_CODE}/$ST/g; s/{CLUSTER}/$CLUSTER/g" \
  $TEMPLATES/build_plot_scenario_template.sh > $TOOLS/build_plot_scenario_${ST}.sh
chmod +x $TOOLS/build_plot_scenario_${ST}.sh
sed "s/{ST_CODE}/$ST/g; s/{CLUSTER}/$CLUSTER/g" \
  $TEMPLATES/apply_theta_template.py > $TOOLS/apply_theta_${ST}_perspecies.py
chmod +x $TOOLS/apply_theta_${ST}_perspecies.py
echo "  generated" >> $LOG

# Step 6: submit T2 v1 chain (warmstarted from cluster reference)
if [ "$DRY" = "dry" ]; then
  echo "[6/6] DRY RUN: skipping chain submission" | tee -a $LOG
  exit 0
fi
echo "[6/6] Submitting T2 v1 chain (warmstart from cluster $CLUSTER reference)..." | tee -a $LOG
TAG=${ST,,}_t2_v1
WARMSTART=$TEMPLATES/cluster_${CLUSTER}_reference_theta.csv
mkdir -p "$PERSEUS/bayesian/$TAG"   # SLURM --output dir must exist before sbatch
sbatch_id=$(sbatch --parsable \
  --job-name=${TAG} \
  --account=PUOM0008 --partition=batch \
  --ntasks=1 --cpus-per-task=1 --mem=4G --time=2-00:00:00 \
  --output=$PERSEUS/bayesian/${TAG}/driver.out \
  --error=$PERSEUS/bayesian/${TAG}/driver.err \
  --wrap "python3 $TOOLS/cma_es_optimize_${CLUSTER}.py --state $ST --tag $TAG --warmstart $WARMSTART")
echo "  submitted: $sbatch_id" >> $LOG
echo ""
echo "===== add_state $ST done ====="
echo "FIA: $FIA_FOLDER/$FIPS"
echo "Inputs: $INPUTS"
echo "Chain job: $sbatch_id"
echo "Monitor: bash $TOOLS/check_t2v2_chains.sh"
echo "Log: $LOG"
