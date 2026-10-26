#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s46_miwi_smoke --time=01:00:00 --nodes=1 --cpus-per-task=8 --mem=48G
#SBATCH --array=0-1
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/landis_miwi_promote/logs/smoke_%A_%a.out
STS=(MI WI); export ST=${STS[$SLURM_ARRAY_TASK_ID]} SEED=1234
bash /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/landis_miwi_promote/scripts/smoke_miwi_s46.sh

