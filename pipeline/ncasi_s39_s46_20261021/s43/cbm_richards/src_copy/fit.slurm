#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s43b_fit
#SBATCH -t 01:00:00
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=16G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver/logs/fit_%j.out
module purge; module load gcc/12.3.0; module load R/4.5.2
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver
cd $T
md5sum scripts/01_fit_netdriver.R
Rscript scripts/01_fit_netdriver.R $T/out/fit
