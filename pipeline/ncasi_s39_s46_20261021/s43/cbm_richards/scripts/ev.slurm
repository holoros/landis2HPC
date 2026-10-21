#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s43J_ev
#SBATCH -t 01:00:00
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=16G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards/logs/ev_%j.out
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards
md5sum scripts/07J_rt_eval_floor.py
python -u scripts/07J_rt_eval_floor.py /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards/out /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver
