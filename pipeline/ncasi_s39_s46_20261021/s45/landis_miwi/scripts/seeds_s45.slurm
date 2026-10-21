#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s45_miwi_seed --time=01:00:00 --nodes=1 --cpus-per-task=8 --mem=48G
#SBATCH --array=0-5
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/landis_miwi/logs/seed_%A_%a.out
STS=(MI MI MI WI WI WI); SDS=(20261020 20261021 20261022 20261020 20261021 20261022)
export ST=${STS[$SLURM_ARRAY_TASK_ID]} SEED=${SDS[$SLURM_ARRAY_TASK_ID]}
bash /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/landis_miwi/scripts/confirm_miwi_s45.sh
