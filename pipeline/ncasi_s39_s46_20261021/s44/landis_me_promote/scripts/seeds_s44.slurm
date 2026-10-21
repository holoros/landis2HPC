#!/bin/bash
#SBATCH --account=PUOM0008 --time=03:00:00 --nodes=1 --cpus-per-task=8 --mem=96G --job-name=s44_seed
#SBATCH --array=0-3
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s44/landis_me_promote/logs/seed_%A_%a.out
# s44 fresh seed confirmation of installed ME candidate. Task 0 = seed 1234 control (must reproduce 43c c_me_orig_a2.5_b3); 1-3 new seeds.
SEEDS=(1234 20261020 20261021 20261022); export SEED=${SEEDS[$SLURM_ARRAY_TASK_ID]}
export ST=ME RN=s_me_a2.5_b3_seed$SEED SRCT=/fs/scratch/PUOM0008/crsfaaron/landis2/states/ME/inputs/SppEcoregionData_fia_20261020.csv A=1 B=1 PE=1 ETAG=from270 BUILD=orig
echo "task $SLURM_ARRAY_TASK_ID seed $SEED run $RN"
bash /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s44/landis_me_promote/scripts/smoke_run_s44.sh
grep RandomNumberSeed /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s44/landis_me_promote/runs/ME/$RN/scenario.txt
