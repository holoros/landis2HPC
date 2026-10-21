#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s46kS
#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cem_netdonor/logs/%x_%A_%a.log
# s46 Track K amended (post unblinding follow-on, not gate eligible) scoring. Task index as run_k_s46.slurm.
# 2020 window: frozen s43c registered scorer (+ netted for k20net), per sim appendix persim_s46.R.
# 2010 window: frozen s43i early scorers. md5 comparisons against f20a (fixed baseline) for f20b, f20c, f20s, k20null.
set -u
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cem_netdonor
i=$SLURM_ARRAY_TASK_ID
STATES6=(ME NH VT MI WI MN)
CFGS=(u3 u4 u5 f20a f20b f20c f20s k20null k20net k10ref k10net)
CFG=${CFGS[$(( i / 6 ))]}; ST=${STATES6[$(( i % 6 ))]}
TAG=${CFG}_postunblind_followon_not_gate_eligible
case $CFG in u3|u4|u5) E=$T/engine_unf ;; f20a|f20b|f20c|f20s|k10ref) E=$T/engine_fix ;; *) E=$T/engine_fixk ;; esac
REFT=f20a_postunblind_followon_not_gate_eligible
cd $T
md5sum score_k_s46.slurm cem_gate_score_s43c_reg.R cem_gate_score_s43c_netted.R cem_gate_score_s43i_early_reg.R cem_gate_score_s43i_early_netted.R persim_s46.R nd_md5cmp_s46.R nd_summary_s46.R
module purge
module load gcc/12.3.0 R/4.5.2
mkdir -p $T/scores/reg $T/scores/net $T/scores/persim
F="PLT_CN|LAT|LON"
case $CFG in f20b|f20c|f20s|k20null)
  echo "=== md5cmp $ST $CFG vs f20a ==="
  Rscript nd_md5cmp_s46.R $ST ${CFG}_vs_f20a $T/engine_fix $REFT $E $TAG 2>&1 | grep -v -E "$F" ;;
esac
case $CFG in
  k10*) echo "=== score $ST $CFG reg ==="; CEM_OUT=$T/scores/reg Rscript cem_gate_score_s43i_early_reg.R $ST $TAG $E 2>&1 | grep -v -E "$F"
        echo "=== score $ST $CFG net ==="; CEM_OUT=$T/scores/net Rscript cem_gate_score_s43i_early_netted.R $ST $TAG $E 2>&1 | grep -v -E "$F" ;;
  k20null) ;;
  *) echo "=== score $ST $CFG reg ==="; CEM_OUT=$T/scores/reg Rscript cem_gate_score_s43c_reg.R $ST $TAG $E 2>&1 | grep -v -E "$F"
     echo "=== persim $ST $CFG ==="; CEM_OUT=$T/scores/persim Rscript persim_s46.R $ST $TAG $E 2>&1 | grep -v -E "$F" | tail -8
     case $CFG in k20net) echo "=== score $ST $CFG net ==="; CEM_OUT=$T/scores/net Rscript cem_gate_score_s43c_netted.R $ST $TAG $E 2>&1 | grep -v -E "$F" ;; esac ;;
esac
case $CFG in k20net) EY=2024 ;; k10net) EY=2019 ;; *) EY=0 ;; esac
[ $EY -gt 0 ] && { echo "=== summary $ST $CFG ==="; Rscript nd_summary_s46.R $ST $CFG $EY 2>&1 | grep -v -E "$F"; }
echo "=== done $ST $CFG $(date) ==="
