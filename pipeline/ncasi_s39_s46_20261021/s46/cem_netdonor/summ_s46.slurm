#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s46kM
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=32G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cem_netdonor/logs/%x_%A_%a.log
# s46 mechanism summary rerun after the NA fix. Task i: 0-5 k20net (EY 2024), 6-11 k10net (EY 2019).
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cem_netdonor
STATES6=(ME NH VT MI WI MN); i=$SLURM_ARRAY_TASK_ID; ST=${STATES6[$(( i % 6 ))]}
if [ $i -lt 6 ]; then CFG=k20net; EY=2024; else CFG=k10net; EY=2019; fi
module purge; module load gcc/12.3.0 R/4.5.2; cd $T; md5sum nd_summary_s46.R
Rscript nd_summary_s46.R $ST $CFG $EY 2>&1 | grep -v -E "PLT_CN|LAT|LON"
