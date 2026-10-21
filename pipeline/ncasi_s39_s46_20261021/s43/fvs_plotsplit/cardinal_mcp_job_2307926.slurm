#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=fvsps_repro
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=48
#SBATCH --mem=150G
#SBATCH --time=01:00:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/fvs_plotsplit/fvsps_repro_%j.log
set -uo pipefail
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/fvs_plotsplit
cd $T
md5sum fvsps_run_20261019.py fvsmr_run_20261015e.py RULE.md
module purge
export TMPDIR=${TMPDIR:-/tmp}
python3 fvsps_run_20261019.py --mode splitsum || exit 5
python3 fvsps_run_20261019.py --mode repro --variant ne --workers 46 --cap 1500 || exit 6
echo "JOB EXIT 0"

