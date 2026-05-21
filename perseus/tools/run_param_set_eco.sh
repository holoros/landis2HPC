#!/bin/bash
# run_param_set.sh
#
# Given a parameter vector theta (26 multipliers on ANPPmax + BiomassMax across
# 13 species), run all 1219 PERSEUS untreated plots under baseline climate +
# no harvest with the modified SppEcoregionData. Return a per-plot biomass CSV
# matching the format expected by likelihood.py.
#
# This is the inner loop of the CMA-ES / ABC outer loop.
#
# Usage on Cardinal:
#   bash run_param_set.sh <THETA_CSV> <THETA_TAG>
#   bash run_param_set.sh /path/theta.csv  iter042
#
# Output:
#   $LANDIS/states/ME/perseus/bayesian/iter042/per_plot.csv
#   $LANDIS/states/ME/perseus/bayesian/iter042/log_likelihood.txt

set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: bash run_param_set.sh <THETA_CSV> <THETA_TAG>"
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

##############################################################################
# 1. Apply theta to baseline SppEcoregionData -> modified CSV
##############################################################################
SPP_BASE=$INPUTS/SppEcoregionData.csv
SPP_MOD=$BAY/SppEcoregionData_${TAG}.csv

python3 $TOOLS/apply_theta_eco.py \
  --theta-csv "$THETA_CSV" \
  --baseline-spp "$SPP_BASE" \
  --out "$SPP_MOD"

##############################################################################
# 2. Build + submit one scenario per plot (baseline climate, no harvest only)
##############################################################################
LOG=$BAY/launch.log
echo "=== run_param_set $TAG started $(date) ===" > $LOG

# Use existing per-plot ICs
ICS=$PERSEUS/plot_ics
SUBMITTED=0

for IC_DIR in $ICS/plot_*; do
  PID=${IC_DIR##*/plot_}
  IC=$IC_DIR/initial_communities.csv
  [ -f "$IC" ] || continue
  [ "$(wc -l < $IC)" -gt 1 ] || continue

  RUN=$BAY/runs/plot_${PID}
  if [ -f "$RUN/output/biomass/biomass-TotalBiomass-15.tif" ]; then
    continue   # already done
  fi

  mkdir -p "$RUN/output/biomass"

  # Copy IC
  cp $IC $RUN/initial_communities.csv

  # Reuse the working baseline scenario template files from the original Round 1
  TEMPLATE_DIR=$PERSEUS/runs/plot_${PID}__clim_baseline_harv_none
  if [ ! -f "$TEMPLATE_DIR/scenario.txt" ]; then
    continue   # no working baseline; skip
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

  # Use the THETA-modified SppEcoregionData (this is the parameter perturbation)
  ln -sf $SPP_MOD $RUN/SppEcoregionData.csv

  # Adapt scenario.txt: only need 15 years (cycles 6/7/8 = years 5/10/15), but
  # template runs 100, that's fine. Just write job.slurm.
  PATCH=$LANDIS/patches
  PATCH_BIND="--bind $PATCH/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll"
  [ -f $PATCH/Landis.Utilities.dll ] && PATCH_BIND="$PATCH_BIND --bind $PATCH/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll"
  SIF=$LANDIS/images/landis-ii_v8_allext_v1.0.sif

  cat > $RUN/job.slurm <<SLURM
#!/bin/bash
#SBATCH --job-name=bay_${TAG:0:6}_${PID}
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
  # grep -c always exits 1 when count is 0; pipe through cat so set -e and
  # `|| echo 0` don't double-print. Also tr -d to strip any whitespace.
  Q_THIS=$(squeue -u $USER --noheader -o "%j" 2>/dev/null \
              | grep -c "^bay_${TAG:0:6}_" \
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
# 4. Aggregate per-plot biomass at year 5/10/15
##############################################################################
PER_PLOT=$BAY/per_plot.csv
echo "plot_id,year,biomass_g_m2,biomass_Mg_ha,state_mmt" > $PER_PLOT

# Read expansion factors from the IC summary
EF_CSV=$PERSEUS/plot_ics/_summary.csv

python3 - "$BAY/runs" "$EF_CSV" "$PER_PLOT" << 'PY'
import os, sys, csv
from osgeo import gdal
import numpy as np

runs_dir, ef_csv, out_csv = sys.argv[1], sys.argv[2], sys.argv[3]

# Build expansion factor lookup
ef = {}
with open(ef_csv) as f:
    for row in csv.DictReader(f):
        try:
            mmt = float(row.get("spreadsheet_mmt_c5", 0) or 0)
            mgha = float(row.get("total_biomass_Mg_ha", 0) or 0)
            ef[int(row["plot_id"])] = (mmt / mgha) if mgha > 0 else 0
        except (ValueError, KeyError):
            continue

with open(out_csv, "a") as fout:
    for d in sorted(os.listdir(runs_dir)):
        if not d.startswith("plot_"):
            continue
        try:
            pid = int(d[len("plot_"):])
        except ValueError:
            continue
        ef_v = ef.get(pid, 0)
        for yr in [0, 5, 10, 15]:
            tif = os.path.join(runs_dir, d, "output", "biomass",
                                f"biomass-TotalBiomass-{yr}.tif")
            if not os.path.exists(tif):
                continue
            ds = gdal.Open(tif)
            if ds is None:
                continue
            arr = ds.GetRasterBand(1).ReadAsArray()
            v = arr[np.isfinite(arr) & (arr > 0)]
            if v.size == 0:
                g_m2 = 0.0
            else:
                g_m2 = float(v.mean())
            mgha = g_m2 / 100.0
            state_mmt = mgha * ef_v
            fout.write(f"{pid},{yr},{g_m2:.0f},{mgha:.4f},{state_mmt:.6f}\n")
print("Aggregation complete", file=sys.stderr)
PY

echo "=== per_plot.csv written: $PER_PLOT ===" >> $LOG

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
