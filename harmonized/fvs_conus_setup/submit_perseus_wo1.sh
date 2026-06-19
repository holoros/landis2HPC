#!/bin/bash
#SBATCH --job-name=perseus_wo1 --account=PUOM0008 --time=12:00:00
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=4 --mem=16G --array=1-37
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/fvs_stress/perseus_wo1_logs/p_%A_%a.out
#SBATCH --error=/fs/scratch/PUOM0008/crsfaaron/fvs_stress/perseus_wo1_logs/p_%A_%a.err
export FVS_PROJECT_ROOT=/users/PUOM0008/crsfaaron/fvs-modern
export FVS_FIA_DATA_DIR=/fs/scratch/PUOM0008/crsfaaron/FIA
export FIA_DATA_DIR=/fs/scratch/PUOM0008/crsfaaron/FIA
export FVS_LIB_DIR=$FVS_PROJECT_ROOT/lib
export NSBE_ROOT=$FVS_PROJECT_ROOT/data/NSBE
export FVS_CONFIG_DIR=$FVS_PROJECT_ROOT/config
export PYTHONNOUSERSITE=1
export PYTHONPATH=/users/PUOM0008/crsfaaron/fvs-conus/python:$FVS_PROJECT_ROOT:$FVS_PROJECT_ROOT/deployment/fvs2py:${PYTHONPATH:-}
module load python/3.12 gcc/12.3.0 >/dev/null 2>&1
mkdir -p /fs/scratch/PUOM0008/crsfaaron/fvs_stress/perseus_wo1_logs /fs/scratch/PUOM0008/crsfaaron/fvs_stress/out_perseus_wo1
python3 /users/PUOM0008/crsfaaron/fvs-conus/python/perseus_100yr_projection.py   --batch-id ${SLURM_ARRAY_TASK_ID} --batch-size 100   --perseus-csv /users/PUOM0008/crsfaaron/fvs-conus/data/perseus_plots.csv   --variants acd ne --configs default calibrated   --output-dir /fs/scratch/PUOM0008/crsfaaron/fvs_stress/out_perseus_wo1
