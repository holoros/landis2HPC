#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=osmgate
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=48
#SBATCH --mem=180G
#SBATCH --time=04:00:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm/osmgate_%j.log
set -uo pipefail
G=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm
cd $G
md5sum -c MD5SUMS_s41osm_d.txt || { echo "MD5 MISMATCH"; exit 3; }
module purge
export TMPDIR=${TMPDIR:-/tmp}
python3 osmgate_run_20261016d.py --limit 30 --mode cycle --workers 8 --chunk 10 || { echo "SMOKE CYCLE FAILED"; exit 5; }
python3 osmgate_run_20261016d.py --limit 30 --mode annual --workers 8 --chunk 10 || { echo "SMOKE ANNUAL FAILED"; exit 5; }
python3 osmgate_run_20261016d.py --mode cycle --workers 44 --chunk 100 || exit 6
python3 osmgate_run_20261016d.py --mode annual --workers 44 --chunk 100 || exit 7
python3 osmgate_score_20261016b.py || exit 8
echo "JOB EXIT 0"
