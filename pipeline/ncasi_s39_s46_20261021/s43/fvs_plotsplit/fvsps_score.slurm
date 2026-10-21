#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=fvsps_score
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=48
#SBATCH --mem=150G
#SBATCH --time=03:00:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/fvs_plotsplit/fvsps_score_%j.log
set -uo pipefail
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/fvs_plotsplit
md5sum -c MD5SUMS_h2.txt || { echo "MD5 MISMATCH"; exit 3; }
for f in fvsps_grid1_ne fvsps_grid1_ls fvsps_grid2_ne fvsps_grid2_ls fvsps_grid3_ne fvsps_grid3_ls; do grep -q "JOB EXIT 0" ${f}_*.log || { echo "GRID NOT DONE $f"; exit 4; }; done
module purge; module load gcc/12.3.0 R/4.5.2
Rscript fvsps_select_20261019.R || { echo "SELECT FAILED"; exit 4; }
md5sum fvsps_chosen_20261019.csv; cat fvsps_chosen_20261019.csv
module purge
export TMPDIR=${TMPDIR:-/tmp}
python3 fvsps_run_20261019.py --mode score --workers 46 || exit 5
python3 fvsps_score_20261019.py || exit 6
md5sum fvsps_*.csv
echo "JOB EXIT 0"
