#!/bin/bash
#SBATCH --job-name=s41_cbm0
#SBATCH --account=PUOM0008
#SBATCH --time=00:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=6
#SBATCH --mem=24G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm/logs/s41_cbm0_%j.out
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm
echo "4dba2dbcdd6a3c1072de57f9df9de665  s41_cbm_year0_decomp_v1.py" | md5sum -c - || exit 1
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
python -u s41_cbm_year0_decomp_v1.py 2>&1 | grep -v Pandas4Warning
