#!/bin/bash
#SBATCH --job-name=cbm_gate_score2
#SBATCH --account=PUOM0008
#SBATCH --time=00:15:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/logs/cbm_score2_%j.out
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm
cd $D
echo "1b82310b5acd8fd300c5c857d5f74ae3  scripts/cbm_gate_score_20261015.py" | md5sum -c - || exit 1
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
python -u scripts/cbm_gate_score_20261015.py $D 2>&1 | grep -v Pandas4Warning
python - <<'EOF'
import pandas as pd
R=pd.read_csv("cbm_gate_results_20261015.csv"); R=R[R.variant=="noharv"]
c=["state","model_stock_Tg","fia_stock_Tg","model_gross_Tg_yr","fia_gross_Tg_yr","model_mort_Tg_yr","model_mort_turnover_Tg_yr","model_mort_disturbance_Tg_yr","fia_mort_Tg_yr","model_net_Tg_yr","fia_net_Tg_yr","model_grossB_Tg_yr","model_mortB_Tg_yr","model_foliage_share_t0","model_stock_Mg_ha","model_net_Mg_ha_yr","area_model_ha"]
pd.set_option("display.width",300); print(R[c].round(3).to_string())
EOF

