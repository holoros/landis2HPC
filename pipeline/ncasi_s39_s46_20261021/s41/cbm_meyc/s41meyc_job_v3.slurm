#!/bin/bash
#SBATCH --job-name=s41_meyc3
#SBATCH --account=PUOM0008
#SBATCH --time=01:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=48G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_meyc/logs/s41_meyc3_%j.out
# s41 cbm_meyc v3: build v3 (damped per type correction), MEYC3 10 yr and 50 yr
# noharv runs, v4 scoring (unchanged), diagnostics. NEW CURVE CONFIGURATION, not a
# gate change; registered outputs read only; v1 and v2 outputs left as they are.
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_meyc
O=$D/v3
S40=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/scripts
MMD=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm/s41_merch_mort_diag_v1.py
cd $D
printf "b7f4207c50eb1837a207377ea6a80254  s41meyc_build_v3.py\n5378baa06ec841f359900389d9120546  s41meyc_run_v1.py\n9c183ad3742e2e82c39a35a37539576c  s41meyc_traj_v1.py\n312853b8cc9a560cd4e312e6006e141b  $S40/cbm_gate_score_v4_20261015.py\nc535c57410a51bfbf82f3079e90e7274  $MMD\n" | md5sum -c - || exit 1
[ -e $O ] && { echo "ABORT: $O exists"; exit 1; }
mkdir -p $O/logs
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
F="Pandas4Warning|RuntimeWarning|warnings.warn"
echo "### 1 build v3"
python -u s41meyc_build_v3.py $O/curves > $O/logs/build.log 2>&1; echo "build rc=$?"
grep -v -E "Warning|warn" $O/logs/build.log
echo "### 2 MEYC3 runs"
python -u s41meyc_run_v1.py ME $O/new10 --src $O/curves/adapted_ME_MEYC3 --years 10 > $O/logs/new10.log 2>&1 & P3=$!
python -u s41meyc_run_v1.py ME $O/new50 --src $O/curves/adapted_ME_MEYC3 --years 50 > $O/logs/new50.log 2>&1 & P4=$!
wait $P3; echo "new10 rc=$?"
grep -h "^ASSERT\|events" $O/logs/new10.log
python -u $S40/cbm_gate_score_v4_20261015.py $O/new10 2>&1 | grep -v -E "$F" | head -3
python -u $MMD $O/s41meyc3_merch_mort_diag_20261016.csv $D/base10:old_FVS_curves $D/v2/new10:new_MEYC2_curves $O/new10:new_MEYC3_curves 2>&1 | grep -v -E "$F"
wait $P4; echo "new50 rc=$?"
echo "### 3 50 yr trajectory (old = v1 base50; label new_MEYC_curves here = MEYC3)"
python -u s41meyc_traj_v1.py $D/base50 $O/new50 $O/new10 $O/s41meyc3 2>&1 | grep -v -E "Warning|warn"
echo "### gate table"
python - <<PY
import pandas as pd
c=["state","variant","model_stock_Tg","ratio_stock","ratio_stock_woody","ratio_gross","ratio_mort","ratio_net","pass_stock","pass_gross","pass_mort","pass_net","gate_state","model_foliage_share_t0","net_closure_rel","model_mort_turnover_Tg_yr","model_mort_disturbance_Tg_yr"]
o=[]
for lab,d in (("old_FVS_curves_registered_s40script","$D/base10"),("ctrl_old_curves_annual_nodes","$D/v2/ctrl10"),("new_MEYC1_10yr_nodes","$D/new10"),("new_MEYC2_curves","$D/v2/new10"),("new_MEYC3_curves","$O/new10")):
    r=pd.read_csv(d+"/cbm_gate_results_v4_20261015.csv"); r=r[(r.state=="ME")&(r.variant=="noharv")][c]; r.insert(0,"curves",lab); o.append(r)
G=pd.concat(o); G.to_csv("$O/s41meyc3_gate_table_ME_20261016.csv",index=False)
pd.set_option("display.width",300); print(G.round(4).to_string())
PY
md5sum $O/s41meyc3_*.csv $O/curves/*.csv $O/*/cbm_gate_results_v4_20261015.csv $O/curves/*/growth_and_yield.csv
