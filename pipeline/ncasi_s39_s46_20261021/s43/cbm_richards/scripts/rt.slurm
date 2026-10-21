#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s43J_rt
#SBATCH -t 02:00:00
#SBATCH -n 1
#SBATCH -c 18
#SBATCH --mem=48G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards/logs/rt_%j.out
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards
md5sum $T/scripts/s43nd_build_v1.py $T/out/fit_p*/tb_curves_0_300_DATA.csv
mkdir -p $T/logs/rt
cd $T/scripts
for V in p90 p95 p99; do mkdir -p $T/out/rt_$V; for S in ME NH VT MI WI MN; do echo "$V $S"; done; done | xargs -P 18 -L 1 bash -c 'python -u s43nd_build_v1.py $1 /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards/out/rt_$0/$1 /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards/out/fit_$0/tb_curves_0_300_DATA.csv > /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards/logs/rt/build_$0_$1.log 2>&1; echo build $0 $1 rc=$?'
