#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=osmsmoke
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=00:30:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm/osmsmoke_%j.log
set -uo pipefail
G=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm
cd $G
md5sum -c MD5SUMS_s41osm_c.txt || { echo "MD5 MISMATCH"; exit 3; }
module purge
export TMPDIR=${TMPDIR:-/tmp}
python3 -c "import pandas, numpy; print('pandas', pandas.__version__, 'numpy', numpy.__version__)"
python3 osmgate_run_20261016c.py --limit 30 --mode cycle --workers 8 --chunk 10 || { echo "SMOKE CYCLE FAILED"; exit 5; }
python3 osmgate_run_20261016c.py --limit 30 --mode annual --workers 8 --chunk 10 || { echo "SMOKE ANNUAL FAILED"; exit 6; }
echo "JOB EXIT 0"
