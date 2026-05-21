#!/bin/bash
# run_param_set_GA_t1_v2.sh — GA Tier 1 uniform-theta with INCREMENTAL scratch cleanup
# Each plot's runs/plot_X dir is deleted AS SOON AS its biomass is extracted,
# preventing scratch quota peaks during aggregation.
set -uo pipefail
if [ "$#" -lt 2 ]; then echo "Usage: $0 <THETA> <TAG>"; exit 1; fi
THETA=$1
TAG=$2
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
echo "=== run_param_set_GA_t1_v2 $TAG theta=$THETA started $(date) ===" > $LOG

SPP_MOD=$BAY/SppEcoregionData_${TAG}.csv
python3 $TOOLS/apply_theta_uniform_GA.py --theta $THETA --baseline $GA/inputs/SppEcoregionData.csv --out $SPP_MOD >> $LOG 2>&1

PATCH_BIND="--bind $PATCH/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll"
[ -f $PATCH/Landis.Utilities.dll ] && PATCH_BIND="$PATCH_BIND --bind $PATCH/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll"

SUBMITTED=0
for IC_DIR in $ICS/plot_*; do
  PID=${IC_DIR##*/plot_}
  IC=$IC_DIR/initial_communities.csv
  [ -f "$IC" ] && [ "$(wc -l < $IC)" -gt 1 ] || continue
  RUN=$BAY/runs/plot_${PID}
  [ -f "$RUN/output/biomass/biomass-TotalBiomass-15.tif" ] && continue
  mkdir -p "$RUN/output/biomass"
  cp $IC $RUN/initial-communities.csv
  cp $TEMPLATE/scenario.txt $TEMPLATE/biomass-succession.txt $TEMPLATE/climate-generator.txt $TEMPLATE/climate.csv $TEMPLATE/output-biomass.txt $TEMPLATE/ecoregions.txt $TEMPLATE/ecoregions.tif $TEMPLATE/initial-communities.tif $RUN/
  ln -sf $GA/inputs/species.txt $RUN/species.txt
  ln -sf $GA/inputs/SpeciesData.csv $RUN/SpeciesData.csv
  ln -sf $SPP_MOD $RUN/SppEcoregionData.csv
  cat > $RUN/job.slurm <<SLURM
#!/bin/bash
#SBATCH --job-name=ga${TAG:3:5}_${PID}
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1 --cpus-per-task=1 --mem=4G --time=00:15:00
#SBATCH --output=$RUN/job.out
#SBATCH --error=$RUN/job.err
cd $RUN
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  $PATCH_BIND \\
  --bind $RUN:$RUN --pwd $RUN \\
  $SIF \\
  dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt
SLURM
  while :; do
    Q=$(squeue -u $USER --noheader 2>/dev/null | wc -l)
    [ "$Q" -lt 900 ] && break
    sleep 30
  done
  sbatch --parsable $RUN/job.slurm > $RUN/last_jobid.txt 2>/dev/null || true
  SUBMITTED=$((SUBMITTED+1))
  [ $((SUBMITTED % 500)) -eq 0 ] && echo "[$(date '+%H:%M:%S')] submitted $SUBMITTED" >> $LOG
done
echo "=== submission complete: $SUBMITTED, $(date) ===" >> $LOG

JOB_PREFIX="ga${TAG:3:5}_"
while :; do
  Q=$(squeue -u $USER --noheader -o "%j" 2>/dev/null | grep -c "^$JOB_PREFIX" | tr -d ' \n' || true)
  [ -z "$Q" ] && Q=0
  [ "$Q" -eq 0 ] && break
  echo "[$(date '+%H:%M:%S')] $Q $JOB_PREFIX still in queue" >> $LOG
  sleep 60
done

# 4. Aggregate WITH INCREMENTAL CLEANUP — delete each plot dir as soon as we extract its biomass
PER_PLOT=$BAY/per_plot.csv
echo "plot_id,year,biomass_g_m2,biomass_Mg_ha" > $PER_PLOT
N_CLEANED=0
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
  # ← KEY: clean each plot's runs dir after its biomass is extracted
  rm -rf "$d"
  N_CLEANED=$((N_CLEANED + 1))
  if [ $((N_CLEANED % 500)) -eq 0 ]; then
    echo "[$(date '+%H:%M:%S')] cleaned $N_CLEANED plot dirs" >> $LOG
  fi
done

LL=$BAY/log_likelihood.txt
python3 $TOOLS/likelihood_GA.py --pred $PER_PLOT --obs $TOOLS/untreated_plots_GA_full.csv --sigma 0.20 > $LL
echo "=== LL ===" >> $LOG
cat $LL >> $LOG
cat $LL
