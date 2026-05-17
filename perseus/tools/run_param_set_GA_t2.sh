#!/bin/bash
# run_param_set_GA_t2.sh — inner CMA-ES loop for GA Tier 2 per-species.
#
# Usage: bash run_param_set_GA_t2.sh <THETA_CSV> <TAG>

set -uo pipefail
if [ "$#" -lt 2 ]; then echo "Usage: $0 <THETA_CSV> <TAG>"; exit 1; fi
THETA_CSV=$1; TAG=$2

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
TOOLS=$LANDIS/tools
GA=$LANDIS/states/GA
PERSEUS=$GA/perseus
BAY=$PERSEUS/bayesian/ga_t2_v1/$TAG
TEMPLATE=$PERSEUS/runs/plot_1__clim_baseline_harv_none
PATCH=$LANDIS/patches
SIF=$LANDIS/images/landis-ii_v8_allext_v1.0.sif
PLOT_SUBSET=$PERSEUS/ga_t2_plotsubset.txt

mkdir -p $BAY
LOG=$BAY/launch.log
echo "=== run_param_set_GA_t2 $TAG $(date) ===" > $LOG

# Build stratified plot subset (~1000 plots) if missing
if [ ! -f "$PLOT_SUBSET" ]; then
  # Use cluster sampling: 50 plots per ecoregion
  SPP=$GA/inputs/SppEcoregionData.csv
  # No per-plot ecoregion CSV yet — fall back to first 1000 plot IDs
  ls $PERSEUS/plot_ics_full/plot_* -d | sed 's|.*/plot_||' | shuf -n 1000 --random-source=<(yes 42) > $PLOT_SUBSET 2>/dev/null || \
    ls $PERSEUS/plot_ics_full/plot_* -d | sed 's|.*/plot_||' | head -1000 > $PLOT_SUBSET
fi
N=$(wc -l < $PLOT_SUBSET)
echo "Plot subset: $N" >> $LOG

# Apply theta
SPP_BASE=$GA/inputs/SppEcoregionData.csv
SPP_MOD=$BAY/SppEcoregionData_${TAG}.csv
python3 $TOOLS/apply_theta_GA_perspecies.py --theta-csv "$THETA_CSV" --baseline-spp "$SPP_BASE" --out "$SPP_MOD" >> $LOG 2>&1

# Wait for queue clearance before launching
while [ "$(squeue --me -h -r 2>/dev/null | wc -l)" -gt 100 ]; do sleep 30; done

# Submit chunked array (chunk=900 fits 1000 limit)
CHUNK=900
NCHUNKS=$(( (N + CHUNK - 1) / CHUNK ))
PATCH_BIND="--bind $PATCH/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll"
[ -f $PATCH/Landis.Utilities.dll ] && PATCH_BIND="$PATCH_BIND --bind $PATCH/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll"

for ((c=0; c<NCHUNKS; c++)); do
  START=$(( c * CHUNK + 1 )); END=$(( (c+1) * CHUNK )); [ $END -gt $N ] && END=$N
  SIZE=$(( END - START + 1 ))
  CHK=$BAY/chunk${c}.slurm
  cat > $CHK <<SLURM
#!/bin/bash
#SBATCH --job-name=gat2${TAG: -3}_c${c}
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1 --cpus-per-task=1 --mem=4G --time=00:20:00
#SBATCH --array=1-${SIZE}%150
#SBATCH --output=$BAY/c${c}_%a.out
#SBATCH --error=$BAY/c${c}_%a.err

LINE_NUM=\$(( ${START} + SLURM_ARRAY_TASK_ID - 1 ))
PID=\$(sed -n "\${LINE_NUM}p" $PLOT_SUBSET)
RUN=$BAY/runs/plot_\${PID}

if [ -f "\$RUN/biomass_trajectory.csv" ]; then exit 0; fi

mkdir -p "\$RUN/output/biomass"
cp $PERSEUS/plot_ics_full/plot_\${PID}/initial_communities.csv \$RUN/initial-communities.csv
cp $TEMPLATE/scenario.txt $TEMPLATE/biomass-succession.txt $TEMPLATE/climate-generator.txt $TEMPLATE/climate.csv $TEMPLATE/output-biomass.txt $TEMPLATE/ecoregions.txt $TEMPLATE/ecoregions.tif $TEMPLATE/initial-communities.tif \$RUN/
ln -sf $GA/inputs/species.txt \$RUN/species.txt
ln -sf $GA/inputs/SpeciesData.csv \$RUN/SpeciesData.csv
ln -sf $SPP_MOD \$RUN/SppEcoregionData.csv

cd \$RUN
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  $PATCH_BIND \\
  --bind \$RUN:\$RUN --pwd \$RUN \\
  $SIF \\
  dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > /dev/null 2>&1

# extract biomass trajectory + cleanup
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 $SIF python3 -c "
from osgeo import gdal
import os
lines = ['plot_id,year,TotalBiomass_gm2']
for y in range(0, 31, 5):
    f = '\$RUN/output/biomass/biomass-TotalBiomass-' + str(y) + '.tif'
    if os.path.exists(f):
        ds = gdal.Open(f)
        v = float(ds.GetRasterBand(1).ReadAsArray().flatten()[0])
        lines.append('\$PID,' + str(y) + ',' + str(v))
with open('\$RUN/biomass_trajectory.csv','w') as fp:
    fp.write('\n'.join(lines) + '\n')
" 2>/dev/null

find \$RUN -mindepth 1 -name "output" -type d -exec rm -rf {} + 2>/dev/null
find \$RUN -mindepth 1 -name "Metadata" -type d -exec rm -rf {} + 2>/dev/null
rm -f \$RUN/*.tif \$RUN/scenario.txt \$RUN/biomass-succession.txt \$RUN/climate.csv \$RUN/climate-generator.txt \$RUN/output-biomass.txt \$RUN/ecoregions.txt \$RUN/initial-communities.csv 2>/dev/null
SLURM
  JID=$(sbatch --parsable $CHK)
  echo "  chunk $c -> job $JID" >> $LOG
  sleep 60
  while squeue -j $JID -h -r 2>/dev/null | grep -q .; do sleep 30; done
done

# Compute LL on this candidate's results
python3 - <<PY >> $LOG 2>&1
import csv, glob, os, math
plt_cn_to_invyr = {}
with open("$LANDIS/tools/untreated_plots_GA.csv") as f:
    for r in csv.DictReader(f):
        cn = r.get("FIRST_PLTCN", "").strip()
        try: plt_cn_to_invyr[cn] = int(r.get("FIRST_INVYR") or 0)
        except: pass
pid_to_cn = {}
with open("$PERSEUS/plot_ics_full/_summary.csv") as f:
    for r in csv.DictReader(f):
        pid_to_cn[r["plot_id"]] = r["plt_cn"].strip()
obs = {}
with open("$LANDIS/tools/untreated_plots_GA.csv") as f:
    for r in csv.DictReader(f):
        cn = r.get("FIRST_PLTCN", "").strip()
        d = {}
        for k, v in r.items():
            if k.startswith("BIOM_") and k.endswith("_Mgha") and v not in ("", None):
                try:
                    yr = int(k.split("_")[1]); b = float(v)
                    if b > 0: d[yr] = b
                except: pass
        if cn and d: obs[cn] = d
resids = []
for t in glob.glob("$BAY/runs/plot_*/biomass_trajectory.csv"):
    pid = os.path.basename(os.path.dirname(t)).replace("plot_", "")
    cn = pid_to_cn.get(pid)
    if not cn or cn not in obs: continue
    invyr = plt_cn_to_invyr.get(cn, 0)
    if invyr <= 0: continue
    pred = {}
    with open(t) as fp:
        rdr = csv.DictReader(fp)
        for row in rdr: pred[int(row["year"])] = float(row["TotalBiomass_gm2"]) * 0.01
    for y_l, p in pred.items():
        cal = invyr + y_l
        o = obs[cn].get(cal)
        if o and o > 0 and p > 0:
            resids.append(math.log(p) - math.log(o))
n = len(resids)
mean = sum(resids)/n if n else 0
var = sum((r-mean)**2 for r in resids)/max(n-1,1)
sd = math.sqrt(var) if var > 0 else 1e-6
ll = sum(-0.5*((r-mean)/sd)**2 - math.log(sd) - 0.5*math.log(2*math.pi) for r in resids)
with open("$BAY/log_likelihood.txt","w") as f: f.write(f"{ll:.4f}\n")
print(f"n={n} mean={mean:.4f} sd={sd:.4f} LL={ll:.2f}")
PY

# Cleanup runs dir to free inodes for next iteration
rm -rf $BAY/runs

echo "=== $TAG done $(date) ===" >> $LOG
cat $BAY/log_likelihood.txt
