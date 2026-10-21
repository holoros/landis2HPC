#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s43iH2
#SBATCH --time=00:45:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism/logs/%x_%j.log
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism
md5sum $T/h2_sdimax_pairs_s43i.R $T/h2_s43i.slurm /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs/work/pairs_*.csv
module purge; module load gcc/12.3.0 R/4.5.2
Rscript $T/h2_sdimax_pairs_s43i.R
