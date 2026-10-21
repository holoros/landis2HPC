#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=fvsmr_score
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=48
#SBATCH --mem=150G
#SBATCH --time=02:00:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs/fvsmr_score2_%j.log
set -uo pipefail
G=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs
cd $G
md5sum -c MD5SUMS_s41c.txt || { echo "MD5 MISMATCH"; exit 3; }
module purge; module load gcc/12.3.0 R/4.4.0 >/dev/null 2>&1
Rscript fvsmr_select_20261015b.R || { echo "SELECT FAILED"; exit 4; }
md5sum fvs_mortrecal_chosen_20261015.csv
module purge
export TMPDIR=${TMPDIR:-/tmp}
python3 fvsmr_run_20261015c.py --mode score --workers 46 || exit 5
python3 fvsmr_score_20261015.py || exit 6
rm -f fvs_mortrecal_sanity_20261015.csv fvs_mortrecal_sanity_bycls_20261015.csv
python3 fvsmr_run_20261015c.py --mode sanity --workers 46 || exit 7
md5sum fvs_mortrecal_*.csv
echo "JOB EXIT 0"
