#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s45L34
#SBATCH -t 00:20:00
#SBATCH -n 1
#SBATCH -c 6
#SBATCH --mem=16G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn/logs/L34_%j.out
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn
source $T/scripts/env.sh
md5sum $T/scripts/exn_common.py $T/scripts/L3L4_convention_unit.py
cd $T/scripts
printf "%s\n" ME NH VT MI WI MN | xargs -P 6 -I{} bash -c "python -u L3L4_convention_unit.py {} $T/out/L34 > $T/logs/L34_{}.log 2>&1; echo {} rc=\$?"
