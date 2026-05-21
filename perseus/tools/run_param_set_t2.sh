#!/bin/bash
# run_param_set_t2.sh
#
# Tier 2 LANDIS evaluator for the CMA-ES driver. Behaves like
# run_param_set.sh but replaces the broken osgeo-based aggregation block
# with the gdalinfo CLI logic from agg_bayesian.sh, so the entire pipeline
# (apply theta -> submit -> wait -> aggregate -> log-likelihood) runs
# inside one script invocation. The driver only needs to read
# log_likelihood.txt after this returns.
#
# Usage on Cardinal (driver invokes this):
#   bash run_param_set_t2.sh <THETA_CSV> <THETA_TAG>
#
# Output:
#   $BAY/<TAG>/per_plot.csv
#   $BAY/<TAG>/log_likelihood.txt

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: bash run_param_set_t2.sh <THETA_CSV> <THETA_TAG>"
  exit 1
fi

THETA_CSV=$1
TAG=$2

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
TOOLS=/users/PUOM0008/crsfaaron/landis2/scratch/tools
PERSEUS=$LANDIS/states/ME/perseus
BAY=$PERSEUS/bayesian/$TAG
INPUTS=$LANDIS/states/ME/inputs

mkdir -p $BAY/runs
LOG=$BAY/launch.log
echo "=== run_param_set_t2 $TAG started $(date) ===" > $LOG

##############################################################################
# 1. Apply theta to baseline SppEcoregionData -> modified CSV
##############################################################################
SPP_BASE=$INPUTS/SppEcoregionData.csv
SPP_MOD=$BAY/SppEcoregionData_${TAG}.csv

python3 $TOOLS/apply_theta.py \
  --theta-csv "$THETA_CSV" \
  --baseline-spp "$SPP_BASE" \
  --out "$SPP_MOD" >> $LOG 2>&1

##############################################################################
# 2. Build + submit one scenario per plot (baseline climate, no harvest)
##############################################################################
ICS=$PERSEUS/plot_ics
SUBMITTED=0

for IC_DIR in $ICS/plot_*; do
  PID=${IC_DIR##*/plot_}
  IC=$IC_DIR/initial_communities.csv
  [ -f "$IC" ] || continue
  [ "$(wc -l < $IC)" -gt 1 ] || continue

  RUN=$BAY/runs/plot_${PID}
  if [ -f "$RUN/output/biomass/biomass-TotalBiomass-15.tif" ]; then
    continue
  fi

  mkdir -p "$RUN/output/biomass"
  cp $IC $RUN/initial_communities.csv

  TEMPLATE_DIR=$PERSEUS/runs/plot_${PID}__clim_baseline_harv_none
  if [ ! -f "$TEMPLATE_DIR/scenario.txt" ]; then
    continue
  fi
  cp $TEMPLATE_DIR/scenario.txt           $RUN/
  cp $TEMPLATE_DIR/biomass_succession.txt $RUN/
  cp $TEMPLATE_DIR/biomass-succession_ClimateGenerator.txt $RUN/
  cp $TEMPLATE_DIR/output-biomass.txt     $RUN/
  cp $TEMPLATE_DIR/ecoregions.txt         $RUN/
  cp $TEMPLATE_DIR/ecoregions.tif         $RUN/
  cp $TEMPLATE_DIR/initial-communities.tif $RUN/
  ln -sf $INPUTS/species.txt              $RUN/species.txt
  ln -sf $INPUTS/SpeciesData.csv          $RUN/SpeciesData.csv
  ln -sf $INPUTS/PRISM_ME_l3.csv          $RUN/PRISM_maine_l3.csv
  ln -sf $SPP_MOD $RUN/SppEcoregionData.csv

  PATCH=$LANDIS/patches
  PATCH_BIND="--bind $PATCH/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll"
  [ -f $PATCH/Landis.Utilities.dll ] && PATCH_BIND="$PATCH_BIND --bind $PATCH/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll"
  SIF=$LANDIS/images/landis-ii_v8_allext_v1.0.sif

  cat > $RUN/job.slurm <<SLURM
#!/bin/bash
#SBATCH --job-name=bay_${TAG:0:8}_${PID}
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:15:00
#SBATCH --output=$RUN/job.out
#SBATCH --error=$RUN/job.err

cd $RUN
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  $PATCH_BIND \\
  --bind $RUN:$RUN --pwd $RUN \\
  $SIF \\
  dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt
SLURM

  # Throttle to keep queue under cap
  while :; do
    Q=$(squeue -u $USER --noheader 2>/dev/null | wc -l)
    [ "$Q" -lt 900 ] && break
    sleep 30
  done

  sbatch --parsable $RUN/job.slurm > $RUN/last_jobid.txt 2>/dev/null || echo submit_failed > $RUN/last_jobid.txt
  SUBMITTED=$((SUBMITTED + 1))
  if [ $((SUBMITTED % 100)) -eq 0 ]; then
    echo "[$(date '+%H:%M:%S')] submitted $SUBMITTED" >> $LOG
  fi
done

echo "=== submission complete: $SUBMITTED ===" >> $LOG

##############################################################################
# 3. Wait for completion
##############################################################################
echo "Waiting for $SUBMITTED jobs..." >> $LOG
while :; do
  Q_THIS=$(squeue -u $USER --noheader -o "%j" 2>/dev/null \
              | grep -c "^bay_${TAG:0:8}_" \
              | tr -d ' \n' || true)
  [ -z "$Q_THIS" ] && Q_THIS=0
  if [ "$Q_THIS" -eq 0 ]; then
    break
  fi
  echo "[$(date '+%H:%M:%S')] $Q_THIS jobs still in queue" >> $LOG
  sleep 60
done
echo "=== all jobs complete $(date) ===" >> $LOG

##############################################################################
# 4. Aggregate per-plot biomass via gdalinfo CLI (no osgeo bindings needed)
##############################################################################
PER_PLOT=$BAY/per_plot.csv
echo "plot_id,year,biomass_g_m2,biomass_Mg_ha,state_mmt" > $PER_PLOT

EF_CSV=$PERSEUS/plot_ics/_summary.csv

# Build expansion factor lookup
EF_TMP=$BAY/ef_lookup.tsv
python3 - <<PY > $EF_TMP
import csv
with open("$EF_CSV") as f:
    for r in csv.DictReader(f):
        try:
            mmt  = float(r.get("spreadsheet_mmt_c5", 0) or 0)
            mgha = float(r.get("total_biomass_Mg_ha", 0) or 0)
            ef = (mmt / mgha) if mgha > 0 else 0
            print(f"{r['plot_id']}\t{ef}")
        except Exception:
            pass
PY

declare -A EF
while IFS=$'\t' read -r pid ef; do
  EF[$pid]=$ef
done < $EF_TMP

for d in $BAY/runs/plot_*; do
  pid=${d##*/plot_}
  ef=${EF[$pid]:-0}
  for yr in 0 5 10 15; do
    tif=$d/output/biomass/biomass-TotalBiomass-$yr.tif
    [ -f "$tif" ] || continue
    mean=$(gdalinfo -stats "$tif" 2>/dev/null \
            | grep -m1 -oE "Mean=[0-9.]*" | sed 's/Mean=//')
    [ -z "$mean" ] && mean=0
    mgha=$(awk -v m="$mean" 'BEGIN{printf "%.4f", m/100}')
    smmt=$(awk -v m="$mgha" -v e="$ef" 'BEGIN{printf "%.6f", m*e}')
    echo "$pid,$yr,$mean,$mgha,$smmt" >> $PER_PLOT
  done
done

echo "=== per_plot.csv written: $(wc -l < $PER_PLOT) rows ===" >> $LOG

##############################################################################
# 5. Compute log-likelihood
##############################################################################
LL=$BAY/log_likelihood.txt
python3 $TOOLS/likelihood.py \
  --pred "$PER_PLOT" \
  --obs $TOOLS/untreated_plots.csv \
  --sigma 0.20 \
  --summary-only > "$LL"

echo "=== log-likelihood = $(cat $LL) ===" >> $LOG
cat $LL

##############################################################################
# 6. Scratch cleanup — delete the LANDIS run dirs now that per_plot.csv is
#    written. Keeps theta record (SppEcoregionData_*.csv), per_plot.csv,
#    log_likelihood.txt, and launch.log; throws away the heavy LANDIS output
#    tifs. Prevents scratch quota hits during long CMA-ES sweeps.
##############################################################################
if [ -f "$PER_PLOT" ] && [ "$(wc -l < $PER_PLOT)" -gt 1 ] && [ -s "$LL" ]; then
  echo "=== cleaning $BAY/runs ===" >> $LOG
  rm -rf "$BAY/runs"
  echo "=== cleanup done $(date) ===" >> $LOG
fi
