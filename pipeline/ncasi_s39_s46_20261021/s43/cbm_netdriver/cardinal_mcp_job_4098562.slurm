#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s43b_probe
#SBATCH -t 00:20:00
#SBATCH -n 1
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver/logs/probe_%j.out
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver
cd ~
echo "== TM2020 / treemap files"
find cbm_states ncasi_cem_yield -maxdepth 7 \( -iname "*TM*2020*" -o -iname "*treemap*" -o -iname "TM_*" \) 2>/dev/null | head -60
echo "== scratch treemap"
find /fs/scratch/PUOM0008/crsfaaron -maxdepth 5 \( -iname "*TM*2020*" -o -iname "*treemap*2020*" -o -iname "*TreeMap2020*" \) 2>/dev/null | head -40
find /fs/ess/PUOM0008 -maxdepth 5 \( -iname "*TM*2020*" -o -iname "*treemap*" \) 2>/dev/null | head -40
echo "== grep sum csv refs"
grep -rn "TM.2020.sum\|sum.csv" cbm_states/states/*/08_cbm_runs/*.py 2>/dev/null | head -20
echo "== s42 roundtrip summary"
cat /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s42/cbm_fiayc/s42fy_roundtrip_summary_all_20261016.csv | cut -d, -f1-8 | head -60
echo "== slurm python env"
cat /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s42/cbm_fiayc/s42fy_job_v1.slurm

