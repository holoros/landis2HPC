#!/bin/bash
#SBATCH --job-name=s41cf_cvs
#SBATCH --account=PUOM0008
#SBATCH --time=00:15:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_fvsrecal/logs/s41cf_cvs_%j.out
# Diagnostic: curve at each FVS sample stand's own starting age over that stand's starting volume (unchanged
# s41_curve_vs_start_v1.py), old (rebuilt September) and new (recal) curves; plus b0-at-bound counts.
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_fvsrecal
CV=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm/s41_curve_vs_start_v1.py
cd $D
for x in cvs_old cvs_new; do [ -e "$D/$x" ] && { echo "ABORT: $D/$x exists"; exit 1; }; done
md5sum $CV
mkdir -p cvs_old cvs_new
ln -s $D/repro_b/adapter_out/yield_curve_coefficients_DATA_2026-09-17.csv cvs_old/; ln -s $D/repro_b/points_sept_rebuilt.csv cvs_old/fvs_growth_points_DATA_2026-09-17.csv
ln -s $D/curves_new/adapter_out/yield_curve_coefficients_DATA_2026-09-17.csv cvs_new/; ln -s $D/curves_new/points_recal.csv cvs_new/fvs_growth_points_DATA_2026-09-17.csv
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
python -u $CV $D/cvs_old $D/s41cf_curve_vs_start_old_20261016.csv
python -u $CV $D/cvs_new $D/s41cf_curve_vs_start_new_20261016.csv
python - <<PY
import pandas as pd
for lab, f in (("old", "$D/repro_b/adapter_out/yield_curve_coefficients_DATA_2026-09-17.csv"), ("new", "$D/curves_new/adapter_out/yield_curve_coefficients_DATA_2026-09-17.csv")):
    c = pd.read_csv(f); c = c[c.arm == "calibrated"]
    print(lab, "calibrated strata", len(c), "b0 at upper bound", int(c.b0_at_upper_bound.sum()), "by state", c.groupby("state").b0_at_upper_bound.sum().to_dict())
PY
md5sum $D/s41cf_curve_vs_start_*_20261016.csv
