restored
#!/bin/bash
# run_param_set_WA_t2.sh — inner CMA-ES loop for WA Tier 2.
# Apply per-species θ → run subset of ~1000 representative plots → compute LL → write file.
#
# Usage: bash run_param_set_WA_t2.sh <THETA_CSV> <TAG>
#
# Output: $BAY/<TAG>/log_likelihood.txt + per_plot.csv

set -uo pipefail
if [ "$#" -lt 2 ]; then echo "Usage: $0 <THETA_CSV> <TAG>"; exit 1; fi
THETA_CSV=$1; TAG=$2

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
TOOLS=$LANDIS/tools
STATE=$LANDIS/states/WA
PERSEUS=$STATE/perseus
BAY=$PERSEUS/bayesian/wa_t2_v1/$TAG
INPUTS=$STATE/inputs
PLOT_SUBSET=$PERSEUS/wa_t2_plotsubset.txt

mkdir -p $BAY
LOG=$BAY/launch.log
echo "=== run_param_set_WA_t2 $TAG started $(date) ===" > $LOG

# Build representative subset if missing — 100 plots per ecoregion, stratified
if [ ! -f "$PLOT_SUBSET" ]; then
  echo "Building stratified subset (100 per eco)" >> $LOG
  PLOT_ECO=$TOOLS/plot_to_ecoregion_WA.csv
  awk -F',' 'NR>1 && $3+0>0 {print $3,$1}' $PLOT_ECO | sort | \
    awk '{count[$1]++; if (count[$1] <= 100) print $2}' > $PLOT_SUBSET
  echo "subset has $(wc -l < $PLOT_SUBSET) plots" >> $LOG
fi
N=$(wc -l < $PLOT_SUBSET)

# Apply theta to baseline SspEcoregionData
SPP_BASE=$INPUTS/SppEcoregionData.csv
SPP_MOD=$BAY/SppEcoregionData_${TAG}.csv
python3 $TOOLS/apply_theta_WA_perspecies.py --theta-csv "$THETA_CSV" --baseline-spp "$SPP_BASE" --out "$SPP_MOD" >> $LOG 2>&1

# Wait for queue clearance
while [ "$(squeue --me -h -r | wc -l)" -gt 100 ]; do sleep 30; done

# Submit SLURM array over subset (chunked to fit 1000 limit)
CHUNK=900
NCHUNKS=$(( (N + CHUNK - 1) / CHUNK ))
JOBS=""
for ((c=0; c<NCHUNKS; c++)); do
  START=$(( c * CHUNK + 1 )); END=$(( (c+1) * CHUNK )); [ $END -gt $N ] && END=$N
  SIZE=$(( END - START + 1 ))
  CHUNK_SLURM=$BAY/chunk${c}.slurm
  cat > $CHUNK_SLURM <<SLURM
#!/bin/bash
#SBATCH --job-name=wat2_${TAG}_c${c}
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1 --cpus-per-task=1 --mem=4G --time=00:20:00
#SBATCH --array=1-${SIZE}%150
#SBATCH --output=$BAY/c${c}_%a.out
#SBATCH --error=$BAY/c${c}_%a.err

LINE_NUM=\$(( ${START} + SLURM_ARRAY_TASK_ID - 1 ))
PLOT=\$(sed -n "\${LINE_NUM}p" $PLOT_SUBSET)
PLOT_DIR=$BAY/runs/plot_\${PLOT}
mkdir -p \$PLOT_DIR

if [ -f "\$PLOT_DIR/biomass_trajectory.csv" ]; then exit 0; fi

# Build per-plot scenario then patch SspEcoregionData with theta-scaled version
bash $TOOLS/build_plot_scenario_WA.sh \$PLOT baseline none > /dev/null
PLOT_RUN_DIR=$PERSEUS/runs/plot_\${PLOT}__clim_baseline_harv_none
# Filter the theta-modified SspEcoregionData to keep only this plot's ecoregion
ECO=\$(awk '/^yes/{print \$2; exit}' \$PLOT_RUN_DIR/ecoregions.txt)
head -1 $SPP_MOD > \$PLOT_RUN_DIR/SppEcoregionData.csv
awk -F, -v e="\$ECO" 'NR>1 && \$2==e' $SPP_MOD >> \$PLOT_RUN_DIR/SppEcoregionData.csv
# Move into our bayesian/<tag>/runs/ directory to keep it isolated
rm -rf \$PLOT_DIR
mv $PERSEUS/runs/plot_\${PLOT}__clim_baseline_harv_none \$PLOT_DIR

cd \$PLOT_DIR
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  --bind $LANDIS/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \\
  --bind $LANDIS/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \\
  --bind \$PLOT_DIR:\$PLOT_DIR --pwd \$PLOT_DIR \\
  $LANDIS/images/landis-ii_v8_allext_v1.0.sif \\
  dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > /dev/null

# Extract biomass at years matching FIA observations (0,5,10,...,30)
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  $LANDIS/images/landis-ii_v8_allext_v1.0.sif python3 -c "
from osgeo import gdal
import os
lines = ['plot_id,year,TotalBiomass_gm2']
for y in range(0, 31, 5):
    f = '\$PLOT_DIR/output/biomass/biomass-TotalBiomass-' + str(y) + '.tif'
    if os.path.exists(f):
        ds = gdal.Open(f)
        v = float(ds.GetRasterBand(1).ReadAsArray().flatten()[0])
        lines.append('\$PLOT,' + str(y) + ',' + str(v))
with open('\$PLOT_DIR/biomass_trajectory.csv', 'w') as fp:
    fp.write('\n'.join(lines) + '\n')
"

# Cleanup: delete heavy outputs, keep just biomass_trajectory.csv + Landis-log.txt
find \$PLOT_DIR -mindepth 1 -name "output" -type d -exec rm -rf {} + 2>/dev/null
find \$PLOT_DIR -mindepth 1 -name "Metadata" -type d -exec rm -rf {} + 2>/dev/null
rm -f \$PLOT_DIR/*.tif \$PLOT_DIR/*.csv.bak 2>/dev/null
SLURM
  JID=$(sbatch --parsable $CHUNK_SLURM)
  JOBS="$JOBS $JID"
  echo "submitted chunk $c job=$JID" >> $LOG
  # Wait for this chunk to finish before submitting next (avoid 1000-job limit)
  sleep 60
  while squeue -j $JID -h -r 2>/dev/null | grep -q .; do sleep 30; done
done

# Aggregate biomass_trajectory.csv files into a per_plot.csv
python3 - <<PY > $BAY/per_plot.csv
import csv, glob, os
files = sorted(glob.glob("$BAY/runs/plot_*/biomass_trajectory.csv"))
print("plot_id,year,TotalBiomass_gm2")
for f in files:
    with open(f) as fp:
        next(fp)  # skip header
        for line in fp:
            print(line.strip())
PY

# Pivot to wide + compute LL
python3 $TOOLS/aggregate_WA_csv.py --results-dir $BAY/runs --out $BAY/per_plot_wide.csv 2>>$LOG || true
# Need a helper that reads biomass_trajectory.csv files instead - let's do it inline
python3 - <<PY >> $LOG 2>&1
import csv, glob, os, math
ic_year_map = {}
with open("$LANDIS/tools/untreated_plots_WA.csv") as f:
    rdr = csv.DictReader(f)
    plt_cn_to_invyr = {r['FIRST_PLTCN'].strip(): int(r.get('FIRST_INVYR') or 0) for r in rdr}
pid_to_cn = {r['plot_id']: r['plt_cn'].strip() for r in csv.DictReader(open("$PERSEUS/plot_ics_full/_summary.csv"))}
obs = {}
with open("$LANDIS/tools/untreated_plots_WA.csv") as f:
    for r in csv.DictReader(f):
        cn = r['FIRST_PLTCN'].strip()
        d = {}
        for k, v in r.items():
            if k.startswith('BIOM_') and k.endswith('_Mgha') and v not in ('', None):
                try:
                    yr = int(k.split('_')[1]); b = float(v)
                    if b > 0: d[yr] = b
                except: pass
        if cn and d: obs[cn] = d

resids = []
for traj_f in glob.glob("$BAY/runs/plot_*/biomass_trajectory.csv"):
    pid = os.path.basename(os.path.dirname(traj_f)).replace('plot_', '')
    cn = pid_to_cn.get(pid)
    if not cn or cn not in obs: continue
    invyr = plt_cn_to_invyr.get(cn, 0)
    if invyr <= 0: continue
    pred = {}
    with open(traj_f) as fp:
        rdr = csv.DictReader(fp)
        for row in rdr:
            pred[int(row['year'])] = float(row['TotalBiomass_gm2']) * 0.01  # g/m^2 → Mg/ha
    for y_landis, p in pred.items():
        cal = invyr + y_landis
        o = obs[cn].get(cal)
        if o and o > 0 and p > 0:
            resids.append(math.log(p) - math.log(o))

n = len(resids)
mean = sum(resids) / n if n else 0
var = sum((r-mean)**2 for r in resids) / max(n-1, 1)
sd = math.sqrt(var) if var > 0 else 1e-6
ll = sum(-0.5*((r-mean)/sd)**2 - math.log(sd) - 0.5*math.log(2*math.pi) for r in resids)
with open("$BAY/log_likelihood.txt", "w") as f: f.write(f"{ll:.4f}\n")
print(f"n={n} mean={mean:.4f} sd={sd:.4f} LL={ll:.2f}", flush=True)
PY

# Cleanup runs/ dir but keep aggregated CSV + LL file
rm -rf $BAY/runs

echo "=== run_param_set_WA_t2 $TAG done $(date) ===" >> $LOG
cat $BAY/log_likelihood.txt
