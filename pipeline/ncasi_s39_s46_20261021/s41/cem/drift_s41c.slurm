#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s41cemC
#SBATCH --time=03:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=240G
#SBATCH --array=0-1
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem/logs/%x_%A_%a.log
set -u
W=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem
cd $W
md5sum drift_s41c.slurm drift_decomp_s41c.R
module purge
module load gcc/12.3.0 R/4.5.2
if [ "$SLURM_ARRAY_TASK_ID" = "0" ]; then
  Rscript drift_decomp_s41c.R ME_20260520_rcp45_hadgem2_wear_econ_l7b 120 ME NH VT
else
  Rscript drift_decomp_s41c.R MN_20260520_rcp45_wear_l7b 110 MN MI WI
fi
