#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s43J_fit2
#SBATCH -t 01:00:00
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=16G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards/logs/fit_%j.out
module purge; module load gcc/12.3.0; module load R/4.5.2
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards
cd $T
rm -rf $T/out/fit_p90 $T/out/fit_p95 $T/out/fit_p99
md5sum scripts/01J_fit_richards.R
Rscript scripts/01J_fit_richards.R $T/out

