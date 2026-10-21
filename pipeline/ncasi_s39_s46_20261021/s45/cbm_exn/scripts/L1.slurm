#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s45L1
#SBATCH -t 00:20:00
#SBATCH -n 1
#SBATCH -c 6
#SBATCH --mem=16G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn/logs/L1_%j.out
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn
source $T/scripts/env.sh
md5sum $T/scripts/L1_param_diff.py
cd $T/scripts
printf "%s\n" ME NH VT MI WI MN | xargs -P 6 -I{} bash -c "python -u L1_param_diff.py {} $T/dump/{} > $T/logs/L1_{}.log 2>&1; echo {} rc=\$?"
