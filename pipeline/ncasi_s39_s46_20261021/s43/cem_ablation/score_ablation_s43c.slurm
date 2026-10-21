#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s43cemS
#SBATCH --time=03:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_ablation/logs/%x_%A_%a.log
# s43 Track C scoring: registered sign split (I/O path copy of s41d8) and netted residual (diagnostic).
set -u
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_ablation
i=$SLURM_ARRAY_TASK_ID
STATES6=(ME NH VT MI WI MN)
CFGS=(c00base c01noharv c02noswap c03nodist c04nosdi c05noclim c06nopotter c08alloff c09nodistsdi)
if [ $i -lt 54 ]; then CFG=${CFGS[$(( i / 6 ))]}; ST=${STATES6[$(( i % 6 ))]}; else CFG=c07noprod; ST=ME; fi
cd $T
md5sum score_ablation_s43c.slurm cem_gate_score_s43c_reg.R cem_gate_score_s43c_netted.R
module purge
module load gcc/12.3.0 R/4.5.2
mkdir -p $T/scores/reg $T/scores/net
echo "=== score $ST $CFG reg ==="
CEM_OUT=$T/scores/reg Rscript cem_gate_score_s43c_reg.R $ST $CFG $T/engine_c
echo "=== score $ST $CFG net ==="
CEM_OUT=$T/scores/net Rscript cem_gate_score_s43c_netted.R $ST $CFG $T/engine_c
echo "=== done $ST $CFG $(date) ==="
