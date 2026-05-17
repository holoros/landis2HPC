#!/bin/bash
# submit_WA_t0.sh
# Submit five SLURM arrays (max 1000 each on OSC) that do (build + run) per WA
# plot at Tier 0 (uniform θ = 1.0). Skips plots in eco 0. Total = 4,461 plots.

set -euo pipefail

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
TOOLS=$LANDIS/tools
STATE=$LANDIS/states/WA
PERSEUS=$STATE/perseus
PLOT_ECO=$TOOLS/plot_to_ecoregion_WA.csv

# Build runnable plot list (eco != 0)
PLOT_LIST=$PERSEUS/wa_t0_plotlist.txt
awk -F',' 'NR>1 && $3+0 > 0 {print $1}' "$PLOT_ECO" | tr -d '\r' > "$PLOT_LIST"
N=$(wc -l < "$PLOT_LIST")
echo "Plots to run: $N"

LOG=$PERSEUS/wa_t0_logs
mkdir -p "$LOG"

CHUNK=900
NCHUNKS=$(( (N + CHUNK - 1) / CHUNK ))
echo "Chunks: $NCHUNKS x $CHUNK (chained via dependency to stay under 1000-submit limit)"

JOBS=""
DEP=""
for ((c=0; c<NCHUNKS; c++)); do
  START=$(( c * CHUNK + 1 ))
  END=$(( (c+1) * CHUNK ))
  [ $END -gt $N ] && END=$N
  SIZE=$(( END - START + 1 ))
  cat > $PERSEUS/wa_t0_chunk${c}.slurm <<SLURM
#!/bin/bash
#SBATCH --job-name=wa_t0_c${c}
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1 --cpus-per-task=1 --mem=4G --time=00:25:00
#SBATCH --array=1-${SIZE}%150
#SBATCH --output=$LOG/c${c}_%a.out
#SBATCH --error=$LOG/c${c}_%a.err

LINE_NUM=\$(( ${START} + SLURM_ARRAY_TASK_ID - 1 ))
PLOT=\$(sed -n "\${LINE_NUM}p" $PLOT_LIST)
PLOT_DIR=$PERSEUS/runs/plot_\${PLOT}__clim_baseline_harv_none
RESULT_DIR=$PERSEUS/results
RESULT=\$RESULT_DIR/plot_\${PLOT}.csv
mkdir -p \$RESULT_DIR

# Skip if already aggregated into compact result
if [ -f "\$RESULT" ]; then
  exit 0
fi

# Build (idempotent)
bash $TOOLS/build_plot_scenario_WA.sh \$PLOT baseline none > /dev/null

# Run LANDIS
cd \$PLOT_DIR
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  --bind $LANDIS/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \\
  --bind $LANDIS/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \\
  --bind \$PLOT_DIR:\$PLOT_DIR --pwd \$PLOT_DIR \\
  $LANDIS/images/landis-ii_v8_allext_v1.0.sif \\
  dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt

# Extract per-year TotalBiomass to compact CSV, then delete run dir to free inodes
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  $LANDIS/images/landis-ii_v8_allext_v1.0.sif python3 - <<PY > /dev/null
from osgeo import gdal
import os
out_lines = ["plot_id,year,TotalBiomass_gm2"]
for y in range(0, 101, 5):
    f = '\$PLOT_DIR/output/biomass/biomass-TotalBiomass-' + str(y) + '.tif'
    if os.path.exists(f):
        ds = gdal.Open(f)
        v = float(ds.GetRasterBand(1).ReadAsArray().flatten()[0])
        out_lines.append('\$PLOT,' + str(y) + ',' + str(v))
with open('\$RESULT', 'w') as fp:
    fp.write('\n'.join(out_lines) + '\n')
PY

# If extraction succeeded, remove run dir to free inodes
if [ -f "\$RESULT" ] && [ \$(wc -l < "\$RESULT") -gt 1 ]; then
  rm -rf "\$PLOT_DIR"
fi
SLURM

  if [ -z "$DEP" ]; then
    JOB=$(sbatch --parsable $PERSEUS/wa_t0_chunk${c}.slurm)
  else
    JOB=$(sbatch --parsable --dependency=afterany:$DEP $PERSEUS/wa_t0_chunk${c}.slurm)
  fi
  JOBS="$JOBS $JOB"
  DEP=$JOB
  echo "Submitted chunk $c (rows $START-$END): job $JOB (dep on prior chunk)"
done

echo "$JOBS" > $PERSEUS/wa_t0_jobids.txt
echo "All chunks submitted."
