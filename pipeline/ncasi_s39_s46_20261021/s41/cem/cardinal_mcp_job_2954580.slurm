#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s41cemA4
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=24G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem/logs/%x_%j.log
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem
md5sum diag_grm_gross_s41a4.R
module purge; module load gcc/12.3.0 R/4.5.2
Rscript diag_grm_gross_s41a4.R

