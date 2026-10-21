#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s41cemA66
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=96G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem/logs/%x_%j.log
set -u
W=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem
cd $W
md5sum obs_grm_2024_s41a6.R obs_grm_2024_s41a6.slurm
module purge
module load gcc/12.3.0 R/4.5.2
Rscript obs_grm_2024_s41a6.R
