#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=fvsmr_repro
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=48
#SBATCH --mem=120G
#SBATCH --time=00:45:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs/fvsmr_repro_%j.log
set -uo pipefail
G=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs
cd $G
md5sum -c MD5SUMS_s41a.txt || { echo "MD5 MISMATCH"; exit 3; }
( cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs && md5sum -c MD5SUMS_v1.txt ) || { echo "V1 MD5 MISMATCH"; exit 3; }
module purge
export TMPDIR=${TMPDIR:-/tmp}
rm -f fvs_mortrecal_repro_20261015.csv
python3 fvsmr_run_20261015b.py --mode repro --workers 46 || { echo "REPRO STEP FAILED"; exit 4; }
python3 - <<'PY' || { echo "REPRO GATE FAILED"; exit 5; }
import pandas as pd
d = pd.read_csv("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs/fvs_mortrecal_repro_20261015.csv")
print(d.to_string(index=False))
assert len(d) == 12 and d.pass_.all() and (d.ok == d.pairs).all()
print("REPRO_GATE_PASS")
PY
python3 fvsmr_run_20261015b.py --mode split || exit 6
echo "JOB EXIT 0"
