#!/bin/bash
#SBATCH --job-name=s42_fiayc
#SBATCH --account=PUOM0008
#SBATCH --time=02:00:00
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=24
#SBATCH --mem=160G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s42/cbm_fiayc/logs/s42fy_%j.out
# s42 cbm_fiayc: CBM-CFS3 in six states on the state FIA AGB yield curves (FIAYC, new curve
# configuration, not a gate change). Builds (ME reuses s41 MEYC3), annual node controls, 10 yr
# noharv gate runs scored with the unchanged v4 scorer, proposed dying-tree rescore (not filed),
# 50 yr 2x2-style runs (run_libcbm.py, events as in the 2x2 cell) for year 50 TEC.
set -uo pipefail
G=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015
O=$G/s42/cbm_fiayc
M=$G/s41/cbm_meyc
SC=$G/cbm/scripts/cbm_gate_score_v4_20261015.py
RUN=$M/s41meyc_run_v1.py
DT=$M/s41dt_rescore_v1.py
TEC=$G/s41/cbm_fvsrecal/s41cf_tec50_v1.py
RL=/users/PUOM0008/crsfaaron/cbm_states/cross_state/libcbm/run_libcbm.py
cd $O
printf "5ff8da961491eabdb5bb61799c1fc2e8  s42fy_build_v1.py\n5378baa06ec841f359900389d9120546  $RUN\n312853b8cc9a560cd4e312e6006e141b  $SC\n0f7821eefe79c33d6e07a54f63d7f161  $DT\n" | md5sum -c - || exit 1
md5sum $TEC $RL
for x in curves ctrl10 new10 tec50; do [ -e $O/$x ] && { echo "ABORT: $x exists"; exit 1; }; done
mkdir -p $O/curves $O/ctrl10 $O/new10 $O/tec50/ctrl $O/tec50/new $O/logs/st
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
F="Pandas4Warning|RuntimeWarning|warnings.warn|untested linux"
echo "### 1 builds (ME = s41 MEYC3 copied unchanged)"
mkdir -p $O/curves/ME
cp -rp $M/v3/curves/adapted_ME_MEYC3 $O/curves/ME/adapted_FIAYC
cp -rp $M/v2/curves/adapted_ME_CTRL_annual $O/curves/ME/adapted_CTRL_annual
python - <<PY
import pandas as pd
s = pd.read_csv("$M/v3/curves/s41meyc3_roundtrip_summary_20261016.csv"); s["state"] = "ME"; s["flag"] = ""
s.to_csv("$O/curves/ME/s42fy_ME_roundtrip_summary_20261016.csv", index=False)
PY
md5sum $O/curves/ME/adapted_FIAYC/growth_and_yield.csv
export O
printf "NH\nVT\nMI\nWI\nMN\n" | xargs -P 5 -I{} bash -c 'python -u s42fy_build_v1.py {} $O/curves/{}/b > $O/logs/st/build_{}.log 2>&1; echo "build {} rc=$?"'
for ST in NH VT MI WI MN; do
  echo "--- $ST"; grep -v -E "Warning|warn" $O/logs/st/build_$ST.log | grep -E "inventory:|CTRL|pass used|max_abs|FT[0-9]|md5 gy|done"
  mv $O/curves/$ST/b/* $O/curves/$ST/ && rmdir $O/curves/$ST/b
done
echo "### 2 runs: ctrl10, new10 (noharv 10 yr), tec50 ctrl and new (run_libcbm.py 50 yr, 2x2 events)"
for ST in ME NH VT MI WI MN; do
  echo "ctrl10 $ST"; echo "new10 $ST"; echo "tc $ST"; echo "tn $ST"
done | xargs -P 24 -L 1 bash -c '
  ST=$1; DB=/users/PUOM0008/crsfaaron/cbm_states/states/$ST/data/processed/cbm_defaults_$ST.db
  case $0 in
   ctrl10) python -u '$RUN' $ST $O/ctrl10 --src $O/curves/$ST/adapted_CTRL_annual --years 10 > $O/logs/st/ctrl10_$ST.log 2>&1;;
   new10)  python -u '$RUN' $ST $O/new10 --src $O/curves/$ST/adapted_FIAYC --years 10 > $O/logs/st/new10_$ST.log 2>&1;;
   tc) python -u '$RL' $O/curves/$ST/adapted_CTRL_annual/sit_config.json $O/tec50/ctrl/libcbm_pools_${ST}_FVS_FIAW_NEW_50yr.csv --years 50 --db-path $DB > $O/logs/st/tc_$ST.log 2>&1;;
   tn) python -u '$RL' $O/curves/$ST/adapted_FIAYC/sit_config.json $O/tec50/new/libcbm_pools_${ST}_FVS_FIAW_NEW_50yr.csv --years 50 --db-path $DB > $O/logs/st/tn_$ST.log 2>&1;;
  esac; echo "$0 $ST rc=$?"'
grep -h "^ASSERT\|events, moved" $O/logs/st/new10_*.log
echo "### 3 score v4 (unchanged)"
for X in ctrl10 new10; do echo "-- $X"; python -u $SC $O/$X 2>&1 | grep -v -E "$F" | head -8; done
echo "### 4 dying-tree rescore (proposed amended definition, not filed)"
python -u $DT $O/s42fy_dyingtree_rescore_20261016.csv $G/cbm/rerun_v2_20261015:registered_FVS_FIAW_NEW $O/ctrl10:ctrl_old_curves_annual $O/new10:FIAYC 2>&1 | grep -v -E "$F"
echo "### 5 TEC year 50"
python -u $TEC $O/s42fy_tec50_20261016.csv "registered_2x2:/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{ST}/libcbm_pools_{ST}_FVS_FIAW_NEW_50yr.csv" "ctrl_old_curves_annual:$O/tec50/ctrl/libcbm_pools_{ST}_FVS_FIAW_NEW_50yr.csv" "FIAYC:$O/tec50/new/libcbm_pools_{ST}_FVS_FIAW_NEW_50yr.csv" 2>&1 | grep -v -E "$F"
echo "### 6 aggregate tables"
python - <<PY
import pandas as pd, glob
c=["state","model_stock_Tg","fia_stock_Tg","ratio_stock","ratio_stock_woody","ratio_gross","ratio_mort","ratio_net","pass_stock","pass_gross","pass_mort","pass_net","gate_state","model_foliage_share_t0","net_closure_rel","model_gross_Tg_yr","fia_gross_Tg_yr","model_mort_Tg_yr","fia_mort_Tg_yr","model_net_Tg_yr","fia_net_Tg_yr"]
o=[]
for lab,d in (("registered_FVS_FIAW_NEW","$G/cbm/rerun_v2_20261015"),("ctrl_old_curves_annual","$O/ctrl10"),("FIAYC","$O/new10")):
    r=pd.read_csv(d+"/cbm_gate_results_v4_20261015.csv"); r=r[r.variant=="noharv"][c]; r.insert(0,"curves",lab); o.append(r)
G=pd.concat(o); G.to_csv("$O/s42fy_gate_table_20261016.csv",index=False)
pd.set_option("display.width",300); pd.set_option("display.max_columns",40); print(G.round(4).to_string())
R=pd.concat([pd.read_csv(f) for f in sorted(glob.glob("$O/curves/*/s42fy_*_roundtrip_summary_20261016.csv"))])
R.to_csv("$O/s42fy_roundtrip_summary_all_20261016.csv",index=False)
print(R[["state","ft","group","max_abs_err_pct","mean_abs_err_pct","n_ages_over_2pct","pass_2pct","flag"]].round(3).to_string())
PY
md5sum $O/s42fy_*.csv $O/curves/*/adapted_FIAYC/growth_and_yield.csv
echo DONE
