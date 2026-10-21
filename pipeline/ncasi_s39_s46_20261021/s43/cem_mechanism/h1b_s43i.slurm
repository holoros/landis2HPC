#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s43iH1b
#SBATCH --time=01:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=128G
#SBATCH --array=0-5
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism/logs/%x_%A_%a.log
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism
A=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_ablation
S=(ME NH VT MI WI MN); ST=${S[$SLURM_ARRAY_TASK_ID]}
md5sum $T/h1b_score_s43i.R $T/h1b_s43i.slurm $A/engine_c/output/${ST}_20261019_c00base/per_plot_projections.rds
module purge; module load gcc/12.3.0 R/4.5.2
cd $A
CEM_OUT=$T/out Rscript $T/h1b_score_s43i.R $ST c00base $A/engine_c 2>&1 | grep -v -E "PLT_CN|LAT|LON"
