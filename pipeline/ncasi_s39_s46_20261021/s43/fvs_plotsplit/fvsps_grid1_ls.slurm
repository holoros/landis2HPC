#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=fvsps_g1_ls
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=48
#SBATCH --mem=150G
#SBATCH --time=05:00:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/fvs_plotsplit/fvsps_grid1_ls_%j.log
set -uo pipefail
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/fvs_plotsplit
md5sum -c MD5SUMS_h.txt || { echo "MD5 MISMATCH"; exit 3; }
grep -q REPRO_GATE_PASS fvsps_repro_15691402.log || { echo "REPRO GATE NOT PASSED"; exit 4; }
module purge
export TMPDIR=${TMPDIR:-/tmp}
python3 fvsps_run_20261019.py --mode grid --grid 1 --variant ls --workers 46 --cap 1500 || exit 5
echo "JOB EXIT 0"
