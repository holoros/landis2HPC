#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s45_miwi_rep --time=01:00:00 --nodes=1 --cpus-per-task=8 --mem=48G
#SBATCH --array=0-1
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/landis_miwi/logs/rep_%A_%a.out
STS=(MI WI); export ST=${STS[$SLURM_ARRAY_TASK_ID]} SEED=1234
bash /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/landis_miwi/scripts/confirm_miwi_s45.sh
