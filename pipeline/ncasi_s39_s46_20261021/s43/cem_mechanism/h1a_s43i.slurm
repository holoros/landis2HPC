#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s43iH1a
#SBATCH --time=01:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --array=0-13
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism/logs/%x_%A_%a.log
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism
S=(ME NH VT MI WI MN NY MA CT RI IA IL OH IN)
md5sum $T/h1a_agent_split_s43i.R $T/h1a_s43i.slurm
module purge; module load gcc/12.3.0 R/4.5.2
Rscript $T/h1a_agent_split_s43i.R ${S[$SLURM_ARRAY_TASK_ID]}
