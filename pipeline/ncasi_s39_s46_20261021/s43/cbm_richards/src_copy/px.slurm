#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s43b_px
#SBATCH -t 01:30:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem=64G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver/logs/px_%j.out
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver
mkdir -p $T/out/px_RESTRICTED
md5sum $T/scripts/03_tm_pixels.py
for S in ME NH VT MI WI MN; do python -u $T/scripts/03_tm_pixels.py $S $T/out/px_RESTRICTED/tm2020_counts_$S.csv; done
