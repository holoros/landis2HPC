#!/bin/bash
#SBATCH --job-name=s41_probe
#SBATCH --account=PUOM0008
#SBATCH --time=00:10:00
#SBATCH --ntasks=1
#SBATCH --mem=8G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm/logs/s41_probe_%j.out
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm
echo "33a4738c2c351757c9f24b3d4744a41f  s41_probe_aidb_v1.py" | md5sum -c - || exit 1
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
python -u s41_probe_aidb_v1.py

