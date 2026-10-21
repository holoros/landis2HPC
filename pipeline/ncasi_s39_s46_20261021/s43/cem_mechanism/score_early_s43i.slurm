#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s43iES
#SBATCH --time=03:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --array=0-23
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism/logs/%x_%A_%a.log
# Track I early window scoring: registered sign split and netted, 2019 evaluation, FIA side targets.
set -u
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism
i=$SLURM_ARRAY_TASK_ID
STATES6=(ME NH VT MI WI MN)
CFGS=(e00base e03nodist e04nosdi e08alloff)
CFG=${CFGS[$(( i / 6 ))]}; ST=${STATES6[$(( i % 6 ))]}
cd $T
md5sum score_early_s43i.slurm cem_gate_score_s43i_early_reg.R cem_gate_score_s43i_early_netted.R
module purge
module load gcc/12.3.0 R/4.5.2
mkdir -p $T/scores/reg $T/scores/net
echo "=== score $ST $CFG reg ==="
CEM_OUT=$T/scores/reg Rscript cem_gate_score_s43i_early_reg.R $ST $CFG $T/engine_i 2>&1 | grep -v -E "PLT_CN|LAT|LON"
echo "=== score $ST $CFG net ==="
CEM_OUT=$T/scores/net Rscript cem_gate_score_s43i_early_netted.R $ST $CFG $T/engine_i 2>&1 | grep -v -E "PLT_CN|LAT|LON"
echo "=== done $ST $CFG $(date) ==="
