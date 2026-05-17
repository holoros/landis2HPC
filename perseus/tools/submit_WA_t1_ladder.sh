#!/bin/bash
# submit_WA_t1_ladder.sh — submit chunked SLURM arrays for the WA Tier 1 θ ladder.
# Builds θ-tagged scenarios (with cleanup) for θ in {0.50, 0.65, 0.75, 0.85, 1.00}.
# Each θ writes its own results subdir results_t<theta>/plot_<id>.csv.
#
# Usage: bash submit_WA_t1_ladder.sh "0.50 0.65 0.75 0.85 1.00"

set -uo pipefail

THETAS=${1:-"0.50 0.65 0.75 0.85 1.00"}
LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
PERSEUS=$LANDIS/states/WA/perseus
TOOLS=$LANDIS/tools
PLOT_LIST=$PERSEUS/wa_t0_plotlist.txt
N=$(wc -l < $PLOT_LIST)
LOG=$PERSEUS/wa_t1_logs
mkdir -p $LOG

CHUNK=900
NCHUNKS=$(( (N + CHUNK - 1) / CHUNK ))

for TH in $THETAS; do
  TH_TAG=$(printf "t%.2f" "$TH" | tr '.' '_')
  RESULTS=$PERSEUS/results_${TH_TAG}
  mkdir -p $RESULTS
  for ((c=0; c<NCHUNKS; c++)); do
    CSTART=$(( c * CHUNK + 1 ))
    CEND=$(( (c+1) * CHUNK ))
    [ $CEND -gt $N ] && CEND=$N
    SIZE=$(( CEND - CSTART + 1 ))
    SLURM_FILE=$PERSEUS/wa_t1_${TH_TAG}_c${c}.slurm
    cat > $SLURM_FILE <<SLURM
#!/bin/bash
#SBATCH --job-name=wa${TH_TAG}c${c}
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1 --cpus-per-task=1 --mem=4G --time=00:20:00
#SBATCH --array=1-${SIZE}%150
#SBATCH --output=$LOG/${TH_TAG}_c${c}_%a.out
#SBATCH --error=$LOG/${TH_TAG}_c${c}_%a.err

LINE_NUM=\$(( ${CSTART} + SLURM_ARRAY_TASK_ID - 1 ))
PLOT=\$(sed -n "\${LINE_NUM}p" $PLOT_LIST)
TAG_RUNS=$PERSEUS/runs_${TH_TAG}
PLOT_DIR=\$TAG_RUNS/plot_\${PLOT}__clim_baseline_harv_none
RESULT=$RESULTS/plot_\${PLOT}.csv

if [ -f "\$RESULT" ]; then exit 0; fi

bash $TOOLS/build_plot_scenario_WA_theta.sh \$PLOT baseline none $TH > /dev/null

cd \$PLOT_DIR
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  --bind $LANDIS/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \\
  --bind $LANDIS/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \\
  --bind \$PLOT_DIR:\$PLOT_DIR --pwd \$PLOT_DIR \\
  $LANDIS/images/landis-ii_v8_allext_v1.0.sif \\
  dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt

apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  $LANDIS/images/landis-ii_v8_allext_v1.0.sif python3 -c "
from osgeo import gdal
import os
lines = ['plot_id,year,TotalBiomass_gm2']
for y in range(0, 101, 5):
    f = '\$PLOT_DIR/output/biomass/biomass-TotalBiomass-' + str(y) + '.tif'
    if os.path.exists(f):
        ds = gdal.Open(f)
        v = float(ds.GetRasterBand(1).ReadAsArray().flatten()[0])
        lines.append('\$PLOT,' + str(y) + ',' + str(v))
with open('\$RESULT', 'w') as fp:
    fp.write('\n'.join(lines) + '\n')
"
if [ -f "\$RESULT" ] && [ \$(wc -l < "\$RESULT") -gt 1 ]; then
  rm -rf "\$PLOT_DIR"
fi
SLURM
    echo "wrote $SLURM_FILE (lines $CSTART-$CEND)"
  done
done

echo
echo "Ladder SLURM files staged. Submit chunks one θ at a time with the chain submitter."
