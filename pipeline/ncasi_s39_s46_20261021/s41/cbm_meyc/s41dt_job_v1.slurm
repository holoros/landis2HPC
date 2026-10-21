#!/bin/bash
#SBATCH --job-name=s41_dt
#SBATCH --account=PUOM0008
#SBATCH --time=00:45:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_meyc/logs/s41_dt_%j.out
# s41 dying-tree rescore (PROPOSED AMENDED DEFINITION, NOT FILED; diagnostic) and
# year 0 decomposition with libcbm's own volume to biomass. Reads existing run
# outputs and registered configs only; writes under s41/cbm_meyc/dt/.
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_meyc
O=$D/dt
cd $D
printf "0f7821eefe79c33d6e07a54f63d7f161  s41dt_rescore_v1.py\n0f89d5a772d715d3073bbb5385930d29  s41dt_year0_libcbm_v1.py\n9ebbfd07b6a5363c1757d1ceab2cb89e  $O/inputs/s41_year0_decomposition_20261015.csv\n" | md5sum -c - || exit 1
[ -e $O/out ] && { echo "ABORT: $O/out exists"; exit 1; }
mkdir -p $O/out; cd $O/out
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
F="Pandas4Warning|RuntimeWarning|warnings.warn|untested linux"
G=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015
echo "### 1 dying-tree rescore"
python -u $D/s41dt_rescore_v1.py s41dt_rescore_all_runs_20261016.csv $G/cbm/rerun_v2_20261015:registered_FVS_FIAW_NEW $G/s41/cbm_fvsrecal/gate_old:fvsrecal_old_curves $G/s41/cbm_fvsrecal/gate_new:fvsrecal_new_curves $D/v3/new10:ME_MEYC3 2>&1 | grep -v -E "$F"
echo "### 2 year 0 decomposition, libcbm v2b"
python -u $D/s41dt_year0_libcbm_v1.py s41dt_year0_libcbm 2>&1 | grep -v -E "$F"
rm -rf work
md5sum *.csv
