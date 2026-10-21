#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s41verify1
#SBATCH --time=00:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=32G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/verify/v1_%j.log
module purge; module load gcc/12.3.0 R/4.5.2
Rscript /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/verify/v1.R
