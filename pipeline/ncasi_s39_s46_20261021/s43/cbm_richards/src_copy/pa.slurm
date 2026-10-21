#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s43b_pa
#SBATCH -t 01:00:00
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=16G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver/logs/pa_%j.out
module purge; module load gcc/12.3.0; module load R/4.5.2
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver
cd $T
md5sum scripts/04b_pseudoage.R
Rscript scripts/04b_pseudoage.R $T/out/fit_v2 $T/out/px_RESTRICTED $T/out/pseudo
