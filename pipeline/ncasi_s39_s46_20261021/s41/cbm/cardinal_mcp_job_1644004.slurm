#!/bin/bash
#SBATCH --job-name=s41_fia
#SBATCH --account=PUOM0008
#SBATCH --time=00:40:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm/logs/s41_fia_%j.out
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm
echo "346f4ef8928908a3fde00ddc1e3d0773  s41_fia_nsvb_components_v1.R" | md5sum -c - || exit 1
module purge; module load gcc/12.3.0 R/4.5.2
Rscript s41_fia_nsvb_components_v1.R

