#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s43b_rt
#SBATCH -t 03:00:00
#SBATCH -n 1
#SBATCH -c 6
#SBATCH --mem=48G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver/logs/rt_%j.out
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver
CUR=$T/out/fit_v2/tb_curves_0_300_DATA.csv
md5sum $T/scripts/s43nd_build_v1.py $CUR
mkdir -p $T/out/rt $T/logs/rt
cd $T/scripts
printf "ME\nNH\nVT\nMI\nWI\nMN\n" | xargs -P 6 -I{} bash -c "python -u s43nd_build_v1.py {} $T/out/rt/{} $CUR > $T/logs/rt/build_{}.log 2>&1; echo build {} rc=\$?"
