#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s46L5b
#SBATCH -t 01:00:00
#SBATCH -n 1
#SBATCH -c 6
#SBATCH --mem=60G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/L5b_%j.out
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/scripts; md5sum L5_curve_roundtrip.py trackL_common.py exn_common.py /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/nsvb_shares_trackL_20261020.csv
source /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/scripts/env.sh
printf "%s\n" ME NH VT MI WI MN | xargs -P 6 -I{} bash -c "python -u L5_curve_roundtrip.py {} /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/L5 /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/nsvb_shares_trackL_20261020.csv > /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/L5b_{}.log 2>&1; echo {} rc=\$?"
grep -h "^RT" /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/L5b_*.log
