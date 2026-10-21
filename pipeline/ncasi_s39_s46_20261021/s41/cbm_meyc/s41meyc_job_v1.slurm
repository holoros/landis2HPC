#!/bin/bash
#SBATCH --job-name=s41_meyc
#SBATCH --account=PUOM0008
#SBATCH --time=01:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_meyc/logs/s41_meyc_%j.out
# s41 cbm_meyc: ME baseline reproduction, MEYC new curve configuration build,
# 10 yr and 50 yr noharv runs, v4 scoring (unchanged), diagnostics. NEW CURVE
# CONFIGURATION, not a gate change; registered cell outputs read only.
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_meyc
S40=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/scripts
MMD=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm/s41_merch_mort_diag_v1.py
cd $D
printf "c95fc1a8ac819c2d301fd884b5bbd767  s41meyc_build_v1.py\n5378baa06ec841f359900389d9120546  s41meyc_run_v1.py\n9c183ad3742e2e82c39a35a37539576c  s41meyc_traj_v1.py\nac2380a26bc0187bdf6c5f24c3896aec  $S40/cbm_gate_run_v2_20261015.py\n312853b8cc9a560cd4e312e6006e141b  $S40/cbm_gate_score_v4_20261015.py\nc535c57410a51bfbf82f3079e90e7274  $MMD\n" | md5sum -c - || exit 1
for X in base10 base50 curves new10 new50; do [ -e $D/$X ] && { echo "ABORT: $X exists"; exit 1; }; done
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
python -c "import libcbm, pandas; print('libcbm', getattr(libcbm,'__version__','?'), 'pandas', pandas.__version__)"
echo "### 1 baseline reproduction (s40 run script, unchanged) + old curve 50 yr"
python -u $S40/cbm_gate_run_v2_20261015.py ME noharv $D/base10 --years 10 > logs/base10.log 2>&1 & P1=$!
python -u $S40/cbm_gate_run_v2_20261015.py ME noharv $D/base50 --years 50 > logs/base50.log 2>&1 & P2=$!
echo "### 2 build MEYC curves"
python -u s41meyc_build_v1.py $D/curves > logs/build.log 2>&1; echo "build rc=$?"
grep -v -E "Warning|warn" logs/build.log
wait $P1; echo "base10 rc=$?"
python -u $S40/cbm_gate_score_v4_20261015.py $D/base10 2>&1 | grep -v -E "Pandas4Warning|RuntimeWarning|warnings.warn" | head -6
echo "### 3 MEYC runs"
python -u s41meyc_run_v1.py ME $D/new10 --src $D/curves/adapted_ME_MEYC --years 10 > logs/new10.log 2>&1 & P3=$!
python -u s41meyc_run_v1.py ME $D/new50 --src $D/curves/adapted_ME_MEYC --years 50 > logs/new50.log 2>&1 & P4=$!
wait $P3; echo "new10 rc=$?"
grep -h "^ASSERT" logs/base10.log logs/new10.log
python -u $S40/cbm_gate_score_v4_20261015.py $D/new10 2>&1 | grep -v -E "Pandas4Warning|RuntimeWarning|warnings.warn" | head -6
python -u $MMD $D/s41meyc_merch_mort_diag_20261016.csv $D/base10:old_FVS_curves $D/new10:new_MEYC_curves 2>&1 | grep -v -E "RuntimeWarning|warnings.warn"
wait $P2; echo "base50 rc=$?"; wait $P4; echo "new50 rc=$?"
echo "### 4 50 yr trajectory"
python -u s41meyc_traj_v1.py $D/base50 $D/new50 $D/new10 $D/s41meyc 2>&1 | grep -v -E "Warning|warn"
echo "### gate table"
python - <<PY
import pandas as pd
c=["state","variant","model_stock_Tg","ratio_stock","ratio_stock_woody","ratio_gross","ratio_mort","ratio_net","pass_stock","pass_gross","pass_mort","pass_net","gate_state","model_foliage_share_t0","net_closure_rel","model_mort_turnover_Tg_yr","model_mort_disturbance_Tg_yr"]
o=[]
for lab,d in (("old_FVS_curves","$D/base10"),("new_MEYC_curves","$D/new10")):
    r=pd.read_csv(d+"/cbm_gate_results_v4_20261015.csv"); r=r[(r.state=="ME")&(r.variant=="noharv")][c]; r.insert(0,"curves",lab); o.append(r)
G=pd.concat(o); G.to_csv("$D/s41meyc_gate_table_ME_20261016.csv",index=False)
pd.set_option("display.width",300); print(G.round(4).to_string())
PY
md5sum $D/s41meyc_*.csv $D/curves/*.csv $D/new10/cbm_gate_results_v4_20261015.csv $D/base10/cbm_gate_results_v4_20261015.csv
