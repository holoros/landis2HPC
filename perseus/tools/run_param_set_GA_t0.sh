#!/bin/bash
# run_param_set_GA_t0.sh
# Georgia baseline (Tier 0, uncalibrated) per-plot LANDIS sweep.
# Mirrors Maine's run_param_set_t2.sh pattern: build per-plot scenarios using
# the proven plot_1 working scenario as canonical template, submit, wait,
# aggregate biomass via gdalinfo CLI, compute log-likelihood vs FIA observed.

set -uo pipefail

TAG=${1:-GA_t0}
LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
TOOLS=/users/PUOM0008/crsfaaron/landis2/scratch/tools
GA=$LANDIS/states/GA
PERSEUS=$GA/perseus
ICS=$PERSEUS/plot_ics_full
BAY=$PERSEUS/bayesian/$TAG
TEMPLATE=$PERSEUS/runs/plot_1__clim_baseline_harv_none
PATCH=$LANDIS/patches
SIF=$LANDIS/images/landis-ii_v8_allext_v1.0.sif

mkdir -p $BAY/runs
LOG=$BAY/launch.log
echo "=== run_param_set_GA_t0 $TAG started $(date) ===" > $LOG

# Verify template exists
if [ ! -f "$TEMPLATE/scenario.txt" ]; then
  echo "FATAL: template missing at $TEMPLATE" >> $LOG; exit 2
fi

PATCH_BIND="--bind $PATCH/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll"
[ -f $PATCH/Landis.Utilities.dll ] && PATCH_BIND="$PATCH_BIND --bind $PATCH/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll"

##############################################################################
# 1. Build + submit one scenario per plot
##############################################################################
SUBMITTED=0
SKIPPED=0
for IC_DIR in $ICS/plot_*; do
  PID=${IC_DIR##*/plot_}
  IC=$IC_DIR/initial_communities.csv
  [ -f "$IC" ] || { SKIPPED=$((SKIPPED+1)); continue; }
  [ "$(wc -l < $IC)" -gt 1 ] || { SKIPPED=$((SKIPPED+1)); continue; }

  RUN=$BAY/runs/plot_${PID}
  [ -f "$RUN/output/biomass/biomass-TotalBiomass-100.tif" ] && continue

  mkdir -p "$RUN/output/biomass"
  cp $IC $RUN/initial-communities.csv

  # Copy text configs + 1x1 rasters from canonical plot_1 template
  cp $TEMPLATE/scenario.txt                             $RUN/
  cp $TEMPLATE/biomass-succession.txt                   $RUN/
  cp $TEMPLATE/climate-generator.txt                    $RUN/
  cp $TEMPLATE/climate.csv                              $RUN/
  cp $TEMPLATE/output-biomass.txt                       $RUN/
  cp $TEMPLATE/ecoregions.txt                           $RUN/
  cp $TEMPLATE/ecoregions.tif                           $RUN/
  cp $TEMPLATE/initial-communities.tif                  $RUN/

  ln -sf $GA/inputs/species.txt          $RUN/species.txt
  ln -sf $GA/inputs/SpeciesData.csv      $RUN/SpeciesData.csv
  ln -sf $GA/inputs/SppEcoregionData.csv $RUN/SppEcoregionData.csv

  cat > $RUN/job.slurm <<SLURM
#!/bin/bash
#SBATCH --job-name=ga_t0_${PID}
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

  # Throttle
  while :; do
    Q=$(squeue -u $USER --noheader 2>/dev/null | wc -l)
    [ "$Q" -lt 900 ] && break
    sleep 30
  done

  sbatch --parsable $RUN/job.slurm > $RUN/last_jobid.txt 2>/dev/null || echo submit_failed > $RUN/last_jobid.txt
  SUBMITTED=$((SUBMITTED + 1))
  if [ $((SUBMITTED % 500)) -eq 0 ]; then
    echo "[$(date '+%H:%M:%S')] submitted $SUBMITTED skipped $SKIPPED" >> $LOG
  fi
done
echo "=== submission complete: $SUBMITTED submitted, $SKIPPED skipped, $(date) ===" >> $LOG

##############################################################################
# 2. Wait for completion
##############################################################################
while :; do
  Q=$(squeue -u $USER --noheader -o "%j" 2>/dev/null | grep -c "^ga_t0_" | tr -d ' \n' || true)
  [ -z "$Q" ] && Q=0
  [ "$Q" -eq 0 ] && break
  echo "[$(date '+%H:%M:%S')] $Q ga_t0 jobs still in queue" >> $LOG
  sleep 60
done
echo "=== all ga_t0 jobs complete $(date) ===" >> $LOG

##############################################################################
# 3. Aggregate per-plot biomass at FIA-validation years (0, 5, 10, 15)
##############################################################################
PER_PLOT=$BAY/per_plot.csv
echo "plot_id,year,biomass_g_m2,biomass_Mg_ha" > $PER_PLOT
for d in $BAY/runs/plot_*; do
  pid=${d##*/plot_}
  for yr in 0 5 10 15 20 25 30 50 75 100; do
    tif=$d/output/biomass/biomass-TotalBiomass-$yr.tif
    [ -f "$tif" ] || continue
    mean=$(gdalinfo -stats "$tif" 2>/dev/null | grep -m1 -oE "Mean=[0-9.]*" | sed 's/Mean=//')
    [ -z "$mean" ] && mean=0
    mgha=$(awk -v m="$mean" 'BEGIN{printf "%.4f", m/100}')
    echo "$pid,$yr,$mean,$mgha" >> $PER_PLOT
  done
done
echo "=== per_plot.csv: $(wc -l < $PER_PLOT) rows ===" >> $LOG

##############################################################################
# 4. Compute log-likelihood vs FIA observed (BIOM_<year>_Mgha)
##############################################################################
LL=$BAY/log_likelihood.txt
python3 $TOOLS/likelihood_GA.py \
  --pred "$PER_PLOT" \
  --obs $TOOLS/untreated_plots_GA_full.csv \
  --sigma 0.20 > "$LL" 2>&1

echo "=== Log-likelihood result ===" >> $LOG
cat $LL >> $LOG
cat $LL
