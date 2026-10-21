#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s45kS
#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor/logs/%x_%A_%a.log
# s45 Track K (post unblinding follow-on, not gate eligible) scoring. Task index as run_k_s45.slurm.
# 2020 window: frozen s43c registered and netted scorers. 2010 window: frozen s43i early scorers.
# k20null: null md5 test only. k20net, k10net: also the mechanism summary.
set -u
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor
i=$SLURM_ARRAY_TASK_ID
STATES6=(ME NH VT MI WI MN)
CFGS=(k20ref k20null k20net k10ref k10net)
CFG=${CFGS[$(( i / 6 ))]}; ST=${STATES6[$(( i % 6 ))]}
TAG=${CFG}_postunblind_followon_not_gate_eligible
case $CFG in k20ref|k10ref) E=$T/engine_kref ;; *) E=$T/engine_k ;; esac
cd $T
md5sum score_k_s45.slurm cem_gate_score_s43c_reg.R cem_gate_score_s43c_netted.R cem_gate_score_s43i_early_reg.R cem_gate_score_s43i_early_netted.R nd_null_md5_s45.R nd_summary_s45.R
module purge
module load gcc/12.3.0 R/4.5.2
mkdir -p $T/scores/reg $T/scores/net
F="PLT_CN|LAT|LON"
if [ "$CFG" = "k20null" ]; then
  Rscript nd_null_md5_s45.R $ST 2>&1 | grep -v -E "$F"
else
  case $CFG in
    k20*) REG=cem_gate_score_s43c_reg.R; NET=cem_gate_score_s43c_netted.R; EY=2024 ;;
    k10*) REG=cem_gate_score_s43i_early_reg.R; NET=cem_gate_score_s43i_early_netted.R; EY=2019 ;;
  esac
  echo "=== score $ST $CFG reg ==="
  CEM_OUT=$T/scores/reg Rscript $REG $ST $TAG $E 2>&1 | grep -v -E "$F"
  echo "=== score $ST $CFG net ==="
  CEM_OUT=$T/scores/net Rscript $NET $ST $TAG $E 2>&1 | grep -v -E "$F"
  case $CFG in *net) echo "=== summary $ST $CFG ==="; Rscript nd_summary_s45.R $ST $CFG $EY 2>&1 | grep -v -E "$F" ;; esac
fi
echo "=== done $ST $CFG $(date) ==="
