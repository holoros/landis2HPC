#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=fvsmr_grid_ne
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=48
#SBATCH --mem=150G
#SBATCH --time=04:00:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs/fvsmr_grid_ne_%j.log
set -uo pipefail
G=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs
cd $G
md5sum -c MD5SUMS_s41b.txt || { echo "MD5 MISMATCH"; exit 3; }
grep -q REPRO_GATE_PASS fvsmr_repro_15551870.log || { echo "REPRO GATE NOT PASSED"; exit 4; }
module purge
export TMPDIR=${TMPDIR:-/tmp}
python3 fvsmr_run_20261015b.py --mode grid --variant ne --workers 46 --cap 1500 || exit 5
echo "JOB EXIT 0"
