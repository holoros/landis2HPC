#!/bin/bash
#SBATCH --job-name=s41_probe2
#SBATCH --account=PUOM0008
#SBATCH --time=00:10:00
#SBATCH --ntasks=1
#SBATCH --mem=8G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm/logs/s41_probe2_%j.out
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm
echo "46318ee0cb83e524208e841d7f436753  s41_probe_aidb_v2.py" | md5sum -c - || exit 1
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
python -u s41_probe_aidb_v2.py

