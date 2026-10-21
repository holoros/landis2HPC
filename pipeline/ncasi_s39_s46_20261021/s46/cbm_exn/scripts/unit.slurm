#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s46Lunit
#SBATCH -t 00:20:00
#SBATCH -n 1
#SBATCH -c 6
#SBATCH --mem=24G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/unit_%j.out
source /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/scripts/env.sh
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/scripts; md5sum L_unit_shift.py trackL_common.py exn_common.py
printf "%s\n" ME NH VT MI WI MN | xargs -P 6 -I{} bash -c "python -u L_unit_shift.py {} /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/unit > /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/unit_{}.log 2>&1; echo {} rc=\$?"
grep -h "^UNIT" /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/unit_*.log
