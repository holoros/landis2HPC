#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s41cemD7
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --array=0-9
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem/logs/%x_%A_%a.log
# tasks 0 to 5: gate runs; 6 to 9: step E attribution runs (start after E finishes)
set -u
W=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem
cd $W
md5sum cem_gate_score_s41d7.slurm cem_gate_score_s41d7.R
STATES=(ME NH VT MI WI MN NH NH MN MN)
TAGS=(s41gate s41gate s41gate s41gate s41gate s41gate s41nosdi s41nodist s41nosdi s41nodist)
i=$SLURM_ARRAY_TASK_ID
if [ $i -ge 6 ]; then
  for k in $(seq 1 240); do ls -d $W/engine/output/${STATES[$i]}_*_${TAGS[$i]} >/dev/null 2>&1 && [ -f $(ls -d $W/engine/output/${STATES[$i]}_*_${TAGS[$i]} | head -1)/per_plot_projections.rds ] && break; sleep 30; done
  sleep 180
fi
module purge
module load gcc/12.3.0 R/4.5.2
Rscript cem_gate_score_s41d7.R ${STATES[$i]} ${TAGS[$i]}
