#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s46kP
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --array=0-5
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cem_netdonor/logs/%x_%A_%a.log
# s46: per sim registered ratios of the designated unfixed reference draw s45 k20ref (v9 K2, v10 item 1).
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cem_netdonor
STATES6=(ME NH VT MI WI MN); ST=${STATES6[$SLURM_ARRAY_TASK_ID]}
module purge; module load gcc/12.3.0 R/4.5.2
mkdir -p $T/scores/persim; cd $T
CEM_OUT=$T/scores/persim Rscript persim_s46.R $ST k20ref_postunblind_followon_not_gate_eligible /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor/engine_kref 2>&1 | grep -v -E "PLT_CN|LAT|LON" | tail -8
