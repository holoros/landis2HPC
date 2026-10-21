#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s45kU
#SBATCH --time=00:15:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor/logs/%x_%j.log
set -u
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor
cd $T
module purge
module load gcc/12.3.0 R/4.5.2
md5sum nd_unit_tests_s45.R engine_k/R/16_netdonor_fns.R
Rscript nd_unit_tests_s45.R

