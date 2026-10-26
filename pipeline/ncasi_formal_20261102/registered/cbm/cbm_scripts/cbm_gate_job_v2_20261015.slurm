#!/bin/bash
#SBATCH --job-name=cbm_gate_v2
#SBATCH --account=PUOM0008
#SBATCH --time=00:45:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=6
#SBATCH --mem=32G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/logs/cbm_gate_v2_%j.out
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm
O=$D/rerun_v2_20261015
[ -e "$O" ] && { echo "ABORT: $O exists"; exit 1; }
mkdir -p $O/logs
cd $D
printf "ac2380a26bc0187bdf6c5f24c3896aec  scripts/cbm_gate_run_v2_20261015.py\n312853b8cc9a560cd4e312e6006e141b  scripts/cbm_gate_score_v4_20261015.py\n" | md5sum -c - || exit 1
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
export O
printf "%s\n" ME NH VT MI WI MN | xargs -P 6 -I{} bash -c 'python -u scripts/cbm_gate_run_v2_20261015.py {} noharv $O --years 10 > $O/logs/run_{}_noharv.log 2>&1; echo "{} rc=$?"'
echo "### harvest type assertions"
grep -h "^ASSERT" $O/logs/run_*_noharv.log
echo "### score v4"
python -u scripts/cbm_gate_score_v4_20261015.py $O 2>&1 | grep -v Pandas4Warning
echo "### compare noharv v4 against first pass"
python - <<PY
import pandas as pd
a=pd.read_csv("$D/cbm_gate_results_20261015.csv"); a=a[a.variant=="noharv"].set_index("state")
b=pd.read_csv("$O/cbm_gate_results_v4_20261015.csv").set_index("state")
c=["ratio_stock","ratio_gross","ratio_mort","ratio_net","ratio_grossB","ratio_mortB","model_removals_Tg_yr"]
for st in b.index:
    d=(b.loc[st,c]-a.loc[st,c]).abs().max()
    print(st, "max abs diff vs first pass", d, "IDENTICAL" if d==0 else "CHANGED")
pd.set_option("display.width",300)
print(b[["model_stock_Tg","model_gross_Tg_yr","model_mort_Tg_yr","model_net_Tg_yr","model_removals_Tg_yr","other_over_merch_turnover"]+c[:6]].round(3).to_string())
PY
