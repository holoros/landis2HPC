#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s45L2b
#SBATCH -t 01:00:00
#SBATCH -n 1
#SBATCH -c 6
#SBATCH --mem=48G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn/logs/L2bc_%j.out
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn
source $T/scripts/env.sh
md5sum $T/scripts/L2b_exn_replay.py $T/scripts/exn_common.py $T/scripts/L2c_compare.py
printf "312853b8cc9a560cd4e312e6006e141b  $T/scripts/cbm_gate_score_v4_20261015.py\n" | md5sum -c - || exit 1
cd $T/scripts
rm -rf $T/out/L2exn
printf "%s\n" ME NH VT MI WI MN | xargs -P 6 -I{} bash -c "python -u L2b_exn_replay.py {} $T/out/L2/{} $T/out/L2exn > $T/logs/L2b_{}.log 2>&1; echo {} rc=\$?"
python -u cbm_gate_score_v4_20261015.py $T/out/L2exn 2>&1 | grep -v Pandas4Warning | head -20
python -u L2c_compare.py $T/out/L2exn $T/out/L2_null_test_compare.csv
