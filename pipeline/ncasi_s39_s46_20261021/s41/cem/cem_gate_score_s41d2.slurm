#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s41cemD2
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --array=0-5
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem/logs/%x_%A_%a.log
set -u
W=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem
cd $W
md5sum cem_gate_score_s41d2.slurm cem_gate_score_s41d2.R
STATES=(ME NH VT MI WI MN)
module purge
module load gcc/12.3.0 R/4.5.2
Rscript cem_gate_score_s41d2.R ${STATES[$SLURM_ARRAY_TASK_ID]}
