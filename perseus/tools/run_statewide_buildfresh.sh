#!/bin/bash
# run_statewide_buildfresh.sh — build-fresh 100yr statewide trajectory generator.
#
# State-parameterized runner. Builds per-plot scenarios fresh via
# build_plot_scenario_{ST}.sh, applies a theta vector to the state SppEcoregionData
# baseline via apply_theta_{ST}_perspecies.py, runs a stratified plot set
# (<=200 per ecoregion) for 100 years, extracts TotalBiomass at years 0/25/50/75/100,
# and aggregates to a state-median biomass trajectory. No likelihood step.
#
# Supports any state with a build_plot_scenario_{ST}.sh AND apply_theta_{ST}_perspecies.py
# AND a baseline states/{ST}/inputs/SppEcoregionData.csv. MN family (MN/WI/MI) shares the
# MN baseline + apply_theta_MN, so for those states pass ST=MN with the appropriate theta.
# Hardened with flock-based submit serialization to avoid OSC QOSMaxSubmitJobPerUserLimit.
#
# Usage:  bash run_statewide_buildfresh.sh <STATE> <THETA_CSV> <TAG>
set -uo pipefail
[ "$#" -lt 3 ] && { echo "Usage: $0 <STATE> <THETA_CSV> <TAG>"; exit 1; }
ST=$1; THETA_CSV=$2; TAG=$3

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
TOOLS=$LANDIS/tools
PERSEUS=$LANDIS/states/$ST/perseus
STIN=$LANDIS/states/$ST/inputs
BAY=$PERSEUS/statewide/$TAG
mkdir -p $BAY/runs
LOG=$BAY/launch.log
echo "=== statewide_buildfresh $ST $TAG started $(date) ===" > $LOG

# Stratified plot list: up to 200 per ecoregion (a stable statewide median; far cheaper
# than the full inventory). plot_to_ecoregion_{ST}.csv = plot_id,plt_cn,eco.
PLOT_LIST=$BAY/plotlist.txt
awk -F',' 'NR>1 && $3+0>0 {print $3,$1}' $TOOLS/plot_to_ecoregion_${ST}.csv | sort -n | \
  awk '{c[$1]++; if (c[$1] <= 200) print $2}' > $PLOT_LIST
N=$(wc -l < $PLOT_LIST)
echo "stratified plot list: $N" >> $LOG

# Apply theta to the state SppEcoregionData baseline (state-specific apply_theta tool)
SPP_MOD=$BAY/SppEcoregionData_${TAG}.csv
python3 $TOOLS/apply_theta_${ST}_perspecies.py --theta-csv "$THETA_CSV" --baseline-spp "$STIN/SppEcoregionData.csv" --out "$SPP_MOD" >> $LOG 2>&1

while [ "$(squeue --me -h -r | wc -l)" -gt 100 ]; do sleep 30; done

CHUNK=900
NCHUNKS=$(( (N + CHUNK - 1) / CHUNK ))
for ((c=0; c<NCHUNKS; c++)); do
  START=$(( c * CHUNK + 1 )); END=$(( (c+1) * CHUNK )); [ $END -gt $N ] && END=$N
  SIZE=$(( END - START + 1 ))
  CK=$BAY/chunk${c}.slurm
  cat > $CK <<SLURM
#!/bin/bash
#SBATCH --job-name=sw${ST}_c${c}
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1 --cpus-per-task=1 --mem=4G --time=00:20:00
#SBATCH --array=1-${SIZE}%150
#SBATCH --output=$BAY/c${c}_%a.out
#SBATCH --error=$BAY/c${c}_%a.err

LINE_NUM=\$(( ${START} + SLURM_ARRAY_TASK_ID - 1 ))
PLOT=\$(sed -n "\${LINE_NUM}p" $PLOT_LIST)
PD=$BAY/runs/plot_\${PLOT}
mkdir -p \$PD
if [ -f "\$PD/biomass_trajectory.csv" ]; then exit 0; fi

bash $TOOLS/build_plot_scenario_${ST}.sh \$PLOT baseline none > /dev/null 2>&1 || exit 0
RUN=$PERSEUS/runs/plot_\${PLOT}__clim_baseline_harv_none
[ -f "\$RUN/scenario.txt" ] || exit 0
ECO=\$(awk '/^yes/{print \$2; exit}' \$RUN/ecoregions.txt)
head -1 $SPP_MOD > \$RUN/SppEcoregionData.csv
awk -F, -v e="\$ECO" 'NR>1 && \$2==e' $SPP_MOD >> \$RUN/SppEcoregionData.csv
rm -rf \$PD; mv \$RUN \$PD

cd \$PD
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  --bind $LANDIS/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \\
  --bind $LANDIS/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \\
  --bind \$PD:\$PD --pwd \$PD \\
  $LANDIS/images/landis-ii_v8_allext_v1.0.sif \\
  dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > /dev/null 2>&1

apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  $LANDIS/images/landis-ii_v8_allext_v1.0.sif python3 -c "
from osgeo import gdal
import os
lines = ['plot_id,year,TotalBiomass_gm2']
for y in range(0, 101, 25):
    f = '\$PD/output/biomass/biomass-TotalBiomass-' + str(y) + '.tif'
    if os.path.exists(f):
        ds = gdal.Open(f)
        v = float(ds.GetRasterBand(1).ReadAsArray().flatten()[0])
        lines.append('\$PLOT,' + str(y) + ',' + str(v))
with open('\$PD/biomass_trajectory.csv', 'w') as fp:
    fp.write('\n'.join(lines) + '\n')
"
find \$PD -mindepth 1 -name "output" -type d -exec rm -rf {} + 2>/dev/null
find \$PD -mindepth 1 -name "Metadata" -type d -exec rm -rf {} + 2>/dev/null
rm -f \$PD/*.tif 2>/dev/null
SLURM
  # Serialize submission across concurrent drivers (avoids OSC QOSMaxSubmitJobPerUserLimit).
  # The flock holds while any other driver is checking the queue gate and submitting,
  # so multiple statewide drivers can run in parallel without colliding on the submit step.
  ( flock -x 200
    while [ "$(squeue --me -h -r | wc -l)" -gt 100 ]; do sleep 30; done
    sbatch --parsable $CK > $BAY/last_jid.txt 2>$BAY/last_jid.err
  ) 200>/tmp/perseus_statewide_submit.lock
  JID=$(cat $BAY/last_jid.txt 2>/dev/null)
  if [ -z "$JID" ]; then echo "  chunk $c SUBMIT FAILED: $(cat $BAY/last_jid.err 2>/dev/null)" >> $LOG; continue; fi
  echo "  chunk $c -> job $JID (serialized submit)" >> $LOG
  sleep 60
  while squeue -j $JID -h -r 2>/dev/null | grep -q .; do sleep 30; done
  THR=$(( N * 85 / 100 ))
  for a in $(seq 1 20); do
    CNT=$(find $BAY/runs -name biomass_trajectory.csv 2>/dev/null | wc -l)
    if [ $CNT -ge $THR ]; then echo "  settled $CNT/$N" >> $LOG; break; fi
    echo "  settling $CNT/$N (attempt $a/20)" >> $LOG; sleep 30
  done
done

# Aggregate -> state median biomass (Mg/ha) per year
python3 - <<PY > $BAY/state_trajectory.csv
import csv, glob, statistics as st
from collections import defaultdict
by = defaultdict(list)
for f in glob.glob("$BAY/runs/plot_*/biomass_trajectory.csv"):
    for r in csv.DictReader(open(f)):
        try: by[int(r['year'])].append(float(r['TotalBiomass_gm2']) * 0.01)
        except: pass
print("year,n_plots,median_Mg_ha")
for y in sorted(by):
    print(f"{y},{len(by[y])},{st.median(by[y]):.2f}")
PY
echo "=== statewide_buildfresh $ST $TAG done $(date) ===" >> $LOG
cat $BAY/state_trajectory.csv
