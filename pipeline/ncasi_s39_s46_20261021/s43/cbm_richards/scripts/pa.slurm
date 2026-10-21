#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s43J_pa
#SBATCH -t 01:00:00
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=16G
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards/logs/pa_%j.out
module purge; module load gcc/12.3.0; module load R/4.5.2
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards
md5sum scripts/04J_pseudoage.R
Rscript scripts/04J_pseudoage.R /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_richards/out /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver/out/px_RESTRICTED /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver/out/fit_v2
