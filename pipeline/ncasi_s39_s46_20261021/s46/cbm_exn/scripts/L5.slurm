#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s46L5
#SBATCH -t 01:30:00
#SBATCH -n 1
#SBATCH -c 6
#SBATCH --mem=60G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/L5_%j.out
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/scripts; md5sum nsvb_shares.R L5_curve_roundtrip.py trackL_common.py exn_common.py
module purge; module load gcc/12.3.0 R/4.5.2
Rscript nsvb_shares.R /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/nsvb_shares_trackL_20261020.csv > /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/nsvb.log 2>&1 || { echo NSVB FAIL; tail /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/nsvb.log; exit 1; }
tail -8 /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/nsvb.log
module purge
source /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/scripts/env.sh
printf "%s\n" ME NH VT MI WI MN | xargs -P 6 -I{} bash -c "python -u L5_curve_roundtrip.py {} /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/L5 /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/nsvb_shares_trackL_20261020.csv > /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/L5_{}.log 2>&1; echo {} rc=\$?"
grep -h "^RT" /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/L5_*.log
