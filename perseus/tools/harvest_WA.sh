#!/bin/bash
# harvest_WA.sh — extract per-year TotalBiomass values for each WA plot run dir,
# write to compact CSV in results/, then delete the run dir to free inodes.
# Idempotent: skips dirs already harvested.
set -uo pipefail

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
PERSEUS=$LANDIS/states/WA/perseus
RESULTS=$PERSEUS/results
mkdir -p $RESULTS

LOG=$PERSEUS/wa_harvest.log
echo "=== harvest start $(date) ===" > $LOG

apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
  $LANDIS/images/landis-ii_v8_allext_v1.0.sif python3 - <<PY >> $LOG 2>&1
from osgeo import gdal
import os, glob, shutil

PERSEUS = "$PERSEUS"
RESULTS = "$RESULTS"

runs = sorted(glob.glob(os.path.join(PERSEUS, "runs", "plot_*__clim_baseline_harv_none")))
print(f"Found {len(runs)} run dirs", flush=True)
done = 0; skipped = 0; already = 0
for d in runs:
    pid = os.path.basename(d).split("__")[0].replace("plot_", "")
    out = os.path.join(RESULTS, f"plot_{pid}.csv")
    if os.path.exists(out):
        shutil.rmtree(d, ignore_errors=True)
        already += 1
        continue
    final = os.path.join(d, "output", "biomass", "biomass-TotalBiomass-100.tif")
    if not os.path.exists(final):
        skipped += 1
        shutil.rmtree(d, ignore_errors=True)
        continue
    lines = ["plot_id,year,TotalBiomass_gm2"]
    for y in range(0, 101, 5):
        f = os.path.join(d, "output", "biomass", f"biomass-TotalBiomass-{y}.tif")
        if os.path.exists(f):
            ds = gdal.Open(f)
            v = float(ds.GetRasterBand(1).ReadAsArray().flatten()[0])
            lines.append(f"{pid},{y},{v}")
    if len(lines) > 1:
        with open(out, "w") as fp:
            fp.write("\n".join(lines) + "\n")
        shutil.rmtree(d, ignore_errors=True)
        done += 1
        if done % 50 == 0:
            print(f"  harvested {done}", flush=True)
print(f"DONE: harvested {done}, already-had {already}, incomplete-cleaned {skipped}")
PY

echo "=== harvest done $(date) ===" >> $LOG
echo "=== post quota ===" >> $LOG
quota -s | tail -3 >> $LOG
