#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=fvsgate
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=48
#SBATCH --mem=180G
#SBATCH --time=04:00:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs/fvsgate_%j.log
set -uo pipefail
G=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs
cd $G
md5sum -c MD5SUMS_v1.txt || { echo "MD5 MISMATCH"; exit 3; }
module purge; module load gcc/12.3.0 R/4.4.0 proj/9.2.1 gdal/3.7.3 geos/3.12.0 >/dev/null 2>&1
which Rscript
Rscript fvsgate_pairs_20261015.R || { echo "PAIRS STEP FAILED"; exit 4; }
module purge
export TMPDIR=${TMPDIR:-/tmp}
python3 fvsgate_run_20261015.py --variant ne --limit 30 --workers 46 && python3 fvsgate_run_20261015.py --variant ls --limit 30 --workers 46 || { echo "SMOKE FAILED"; exit 5; }
python3 fvsgate_run_20261015.py --variant ne --workers 46 || exit 6
python3 fvsgate_run_20261015.py --variant ls --workers 46 || exit 7
python3 fvsgate_score_20261015.py || exit 8
echo "JOB EXIT 0"
