#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s45L2b
#SBATCH -t 01:00:00
#SBATCH -n 1
#SBATCH -c 6
#SBATCH --mem=48G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn/logs/L2b_%j.out
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn
source $T/scripts/env.sh
md5sum $T/scripts/L2b_exn_replay.py $T/scripts/exn_common.py
cd $T/scripts
printf "%s\n" ME NH VT MI WI MN | xargs -P 6 -I{} bash -c "python -u L2b_exn_replay.py {} $T/out/L2/{} $T/out/L2exn > $T/logs/L2b_{}.log 2>&1; echo {} rc=\$?"
