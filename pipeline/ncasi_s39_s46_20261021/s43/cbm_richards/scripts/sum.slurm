#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s43J_sum
#SBATCH -t 01:00:00
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=16G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards/logs/sum_%j.out
module purge; module load gcc/12.3.0; module load R/4.5.2
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards
cd $T
md5sum scripts/09J_summary.R
Rscript scripts/09J_summary.R $T/out /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver/out/fit_v2

