#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s45L2a
#SBATCH -t 00:40:00
#SBATCH -n 1
#SBATCH -c 6
#SBATCH --mem=32G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn/logs/L2a_%j.out
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn
source $T/scripts/env.sh
md5sum $T/scripts/L2a_capture_cbm3.py
cd $T/scripts
printf "%s\n" ME NH VT MI WI MN | xargs -P 6 -I{} bash -c "python -u L2a_capture_cbm3.py {} $T/out/L2/{} > $T/logs/L2a_{}.log 2>&1; echo {} rc=\$?"
