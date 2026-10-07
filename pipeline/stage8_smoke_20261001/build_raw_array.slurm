#!/bin/bash
#SBATCH --job-name=smk8_build --account=PUOM0008 --time=01:30:00
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=4 --mem=96G
#SBATCH --array=0-3
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/scripts_20261001/smk8_build_%A_%a.out
STS=(NH VT MI WI)
ST=${STS[$SLURM_ARRAY_TASK_ID]}
echo "state $ST host $(hostname) start $(date)"
bash /fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/scripts_20261001/smoke_build_fb_20261001.sh $ST 10 yes
echo "end $(date)"

