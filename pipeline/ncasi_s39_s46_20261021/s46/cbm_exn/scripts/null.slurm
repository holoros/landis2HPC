#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s46Lnull
#SBATCH -t 01:30:00
#SBATCH -n 1
#SBATCH -c 6
#SBATCH --mem=48G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/null_%j.out
source /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/scripts/env.sh
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/scripts; md5sum L2_null_replay.py trackL_common.py exn_common.py L2_compare.py cbm_gate_score_v4_20261015.py null_state.sh
printf "312853b8cc9a560cd4e312e6006e141b  cbm_gate_score_v4_20261015.py\n" | md5sum -c - || exit 1
rm -rf /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/null_shift0 /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/null_shift1 /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/null_shift2
printf "%s\n" ME NH VT MI WI MN | xargs -P 6 -I{} ./null_state.sh {}
for SH in 0 1 2; do
  python -u cbm_gate_score_v4_20261015.py /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/null_shift$SH > /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/score_s$SH.log 2>&1
  python -u L2_compare.py /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/null_shift$SH /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/L2_null_compare_shift$SH.csv shift$SH | tail -1
done
