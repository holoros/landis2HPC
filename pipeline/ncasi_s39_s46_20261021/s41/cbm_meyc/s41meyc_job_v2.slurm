#!/bin/bash
#SBATCH --job-name=s41_meyc2
#SBATCH --account=PUOM0008
#SBATCH --time=01:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_meyc/logs/s41_meyc2_%j.out
# s41 cbm_meyc v2: annual age class rebuild (build v2), control run (old curves on
# annual nodes), MEYC2 10 yr and 50 yr noharv runs, v4 scoring (unchanged),
# diagnostics. NEW CURVE CONFIGURATION, not a gate change; registered outputs read only.
# v1 outputs (base10, base50, new10, new50, curves) are left as they are.
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_meyc
O=$D/v2
S40=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/scripts
MMD=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm/s41_merch_mort_diag_v1.py
SRC=/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_ME/adapted_FVS_FIAW_NEW
cd $D
printf "0b1b19633c80e08baa69ceddd1d9065a  s41meyc_build_v2.py\n5378baa06ec841f359900389d9120546  s41meyc_run_v1.py\n9c183ad3742e2e82c39a35a37539576c  s41meyc_traj_v1.py\nac2380a26bc0187bdf6c5f24c3896aec  $S40/cbm_gate_run_v2_20261015.py\n312853b8cc9a560cd4e312e6006e141b  $S40/cbm_gate_score_v4_20261015.py\nc535c57410a51bfbf82f3079e90e7274  $MMD\n" | md5sum -c - || exit 1
[ -e $O ] && { echo "ABORT: $O exists"; exit 1; }
mkdir -p $O/logs
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
F="Pandas4Warning|RuntimeWarning|warnings.warn"
echo "### 1 build v2"
python -u s41meyc_build_v2.py $O/curves > $O/logs/build.log 2>&1; echo "build rc=$?"
grep -v -E "Warning|warn" $O/logs/build.log
echo "### 2 controls: run_v1 on registered config (script check), run_v1 on annual node control config"
python -u s41meyc_run_v1.py ME $O/orig10 --src $SRC --years 10 > $O/logs/orig10.log 2>&1 & P0=$!
python -u s41meyc_run_v1.py ME $O/ctrl10 --src $O/curves/adapted_ME_CTRL_annual --years 10 > $O/logs/ctrl10.log 2>&1 & P1=$!
echo "### 3 MEYC2 runs"
python -u s41meyc_run_v1.py ME $O/new10 --src $O/curves/adapted_ME_MEYC2 --years 10 > $O/logs/new10.log 2>&1 & P3=$!
python -u s41meyc_run_v1.py ME $O/new50 --src $O/curves/adapted_ME_MEYC2 --years 50 > $O/logs/new50.log 2>&1 & P4=$!
wait $P0; echo "orig10 rc=$?"; wait $P1; echo "ctrl10 rc=$?"; wait $P3; echo "new10 rc=$?"
grep -h "^ASSERT\|events" $O/logs/ctrl10.log $O/logs/new10.log
for X in orig10 ctrl10 new10; do echo "-- score $X"; python -u $S40/cbm_gate_score_v4_20261015.py $O/$X 2>&1 | grep -v -E "$F" | head -3; done
python -u $MMD $O/s41meyc2_merch_mort_diag_20261016.csv $D/base10:old_FVS_curves $O/ctrl10:ctrl_old_curves_annual $O/new10:new_MEYC2_curves 2>&1 | grep -v -E "$F"
wait $P4; echo "new50 rc=$?"
echo "### 4 50 yr trajectory (old = v1 base50, registered config via s40 run script)"
python -u s41meyc_traj_v1.py $D/base50 $O/new50 $O/new10 $O/s41meyc2 2>&1 | grep -v -E "Warning|warn"
echo "### gate table"
python - <<PY
import pandas as pd
c=["state","variant","model_stock_Tg","ratio_stock","ratio_stock_woody","ratio_gross","ratio_mort","ratio_net","pass_stock","pass_gross","pass_mort","pass_net","gate_state","model_foliage_share_t0","net_closure_rel","model_mort_turnover_Tg_yr","model_mort_disturbance_Tg_yr"]
o=[]
for lab,d in (("old_FVS_curves_registered_s40script","$D/base10"),("old_FVS_curves_runv1","$O/orig10"),("ctrl_old_curves_annual_nodes","$O/ctrl10"),("new_MEYC2_curves","$O/new10")):
    r=pd.read_csv(d+"/cbm_gate_results_v4_20261015.csv"); r=r[(r.state=="ME")&(r.variant=="noharv")][c]; r.insert(0,"curves",lab); o.append(r)
G=pd.concat(o); G.to_csv("$O/s41meyc2_gate_table_ME_20261016.csv",index=False)
pd.set_option("display.width",300); print(G.round(4).to_string())
PY
md5sum $O/s41meyc2_*.csv $O/curves/*.csv $O/*/cbm_gate_results_v4_20261015.csv
