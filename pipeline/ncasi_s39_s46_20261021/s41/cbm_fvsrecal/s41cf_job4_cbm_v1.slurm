#!/bin/bash
#SBATCH --job-name=s41cf_cbm
#SBATCH --account=PUOM0008
#SBATCH --time=03:00:00
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=24
#SBATCH --mem=160G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_fvsrecal/logs/s41cf_cbm_%j.out
# Steps 2 to 4: new curves from the recalibrated FVS runs through the same adapter; the FVS_FIAW_NEW cell rebuilt
# in a sandbox with old curves (reproduction) and new curves; noharv 10 yr gate runs scored with the unchanged v4
# scorer; diagnostics; curve start ratios; year 50 total ecosystem carbon.
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_fvsrecal
cd $D
for x in curves_new cbm_old cbm_new gate_old gate_new; do [ -e "$D/$x" ] && { echo "ABORT: $D/$x exists"; exit 1; }; done
md5sum -c MD5SUMS_s41cf_b.txt || exit 1
SC=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/scripts/cbm_gate_score_v4_20261015.py
MM=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm/s41_merch_mort_diag_v1.py
printf "312853b8cc9a560cd4e312e6006e141b  $SC\nc535c57410a51bfbf82f3079e90e7274  $MM\n" | md5sum -c - || exit 1
C=/users/PUOM0008/crsfaaron/cbm_states
REF=/users/PUOM0008/crsfaaron/fia_cem_projections/config/REF_FOREST_TYPE.csv
SNE=/users/PUOM0008/crsfaaron/ncasi_fvsne/out_20260907_frame/fvs-ne-stand-trajectories_DATA_2026-09-07.csv
SLS=/users/PUOM0008/crsfaaron/ncasi_fvsls/out_20260907_frame/fvs-ls-stand-trajectories_DATA_2026-09-07.csv
NNE=$D/fvs_ne/fvs-ne-stand-trajectories_DATA_2026-10-16.csv
NLS=$D/fvs_ls_v1_b/fvs-ls-stand-trajectories_DATA_2026-10-16.csv
mkdir -p $D/curves_new/adapter_out
echo "### new points: recal arm (labelled calibrated so the adapter emits sit_yield_<ST>_calibrated.csv), default arm from September"
( module purge; module load gcc/12.3.0 R/4.5.2
  LABELS=$D/ref_fvs_growth_points_DATA_2026-09-17.csv Rscript s41cf_points_v2.R $D/curves_new/points_recal.csv $REF \
    $SNE:default:default $NNE:recal:calibrated $SLS:default:default $NLS:recal:calibrated
  Rscript s41cf_adapter_v1.R $D/curves_new/points_recal.csv $D/curves_new/adapter_out > $D/curves_new/adapter.log 2>&1; echo "adapter rc=$?"
  sed -n '/--- fit summary ---/,/--- fitted strata ---/p' $D/curves_new/adapter.log
  echo "### new curves against old (calibrated arm), and default arm unchanged check"
  Rscript s41cf_cmp_sityield_v1.R $D/curves_new/adapter_out $C/states/%s/data/processed/sit_yield.csv $D/curves_new/new_vs_old_sityield.csv
  Rscript -e 'library(data.table); D<-commandArgs(TRUE)[1]; o<-fread(file.path(D,"repro_b/adapter_out/yield_curves_long_DATA_2026-09-17.csv")); n<-fread(file.path(D,"curves_new/adapter_out/yield_curves_long_DATA_2026-09-17.csv")); m<-merge(o,n,by=c("state","arm","TYPGRPCD","stand_age")); cat("default arm max abs diff", max(abs(m[arm=="default"]$vol_m3_ha.x-m[arm=="default"]$vol_m3_ha.y)), "\n"); r<-m[arm=="calibrated" & stand_age %in% c(25,50,75,100,150), .(old=mean(vol_m3_ha.x), new=mean(vol_m3_ha.y)), by=.(state,stand_age)]; r[,ratio:=new/old]; print(r); fwrite(r, file.path(D,"s41cf_curve_mean_by_age_old_new_20261016.csv"))' $D
)
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
echo "python $(which python3)"
echo "### sandbox CBM chain, old curves (reproduction) and new curves, six states in parallel"
mkdir -p $D/cbm_old $D/cbm_new
for ST in ME NH VT MI WI MN; do
  echo "old $ST $C/states/$ST/data/processed/sit_yield.csv"
  echo "new $ST $D/curves_new/adapter_out/sit_yield_${ST}_calibrated.csv"
done | xargs -P 12 -L 1 bash -c 'bash s41cf_cbmchain_v1.sh $1 $2 '"$D"'/cbm_$0 > '"$D"'/cbm_$0/chain_$1.log 2>&1; echo "chain $0 $1 rc=$?"'
for T in old new; do for ST in ME NH VT MI WI MN; do echo "--- $T $ST"; cat $D/cbm_$T/chain_$ST.log; done; done
echo "### reproduction: sandbox old-curve adapted config against the registered 2x2 adapted_FVS_FIAW_NEW"
for ST in ME NH VT MI WI MN; do
  E=/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_$ST/adapted_FVS_FIAW_NEW
  for f in $(ls $E); do
    a=$(md5sum < $E/$f | cut -c1-32); b=$(md5sum < $D/cbm_old/$ST/adapted_FVS_FIAW_NEW/$f 2>/dev/null | cut -c1-32)
    [ "$a" = "$b" ] && s=SAME || s=DIFF; echo "$ST $f $s"
  done
done
python3 - <<PY
import pandas as pd, numpy as np
for st in ["ME","NH","VT","MI","WI","MN"]:
    a = pd.read_csv(f"/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{st}/libcbm_pools_{st}_FVS_FIAW_NEW_50yr.csv")
    b = pd.read_csv(f"$D/cbm_old/{st}/libcbm_pools_{st}_FVS_FIAW_NEW_50yr.csv")
    c = [x for x in a.columns if x in b.columns and x != "timestep"]
    print(st, "50 yr pools old-curve sandbox vs registered 2x2: max rel diff", float(np.nanmax(np.abs(b[c].values - a[c].values) / np.maximum(np.abs(a[c].values), 1e-9))))
PY
python3 - <<PY
import pandas as pd
for st in ["ME","NH","VT","MI","WI","MN"]:
    o = pd.read_csv(f"$D/cbm_old/{st}/adapted_FVS_FIAW_NEW/growth_and_yield.csv"); n = pd.read_csv(f"$D/cbm_new/{st}/adapted_FVS_FIAW_NEW/growth_and_yield.csv")
    vc = [c for c in o.columns if c.startswith("v") and c[1:].isdigit()]
    print(st, "adapted yield rows old", len(o), "new", len(n), "same strata", (o[["c1","c2","c3","leading_species"]].values == n[["c1","c2","c3","leading_species"]].values).all(),
          "mean v5 old", round(o["v5"].mean(), 2), "new", round(n["v5"].mean(), 2), "mean v10 old", round(o["v10"].mean(), 2), "new", round(n["v10"].mean(), 2))
    for f in ["inventory.csv", "classifiers.csv", "disturbance_events.csv", "disturbance_types.csv", "age_classes.csv", "transition_rules.csv"]:
        a = open(f"$D/cbm_old/{st}/adapted_FVS_FIAW_NEW/{f}").read(); b = open(f"$D/cbm_new/{st}/adapted_FVS_FIAW_NEW/{f}").read()
        if a != b: print("   ", st, f, "DIFFERS between old and new curve builds")
PY
echo "### gate runs, noharv, 10 yr, old and new curves"
mkdir -p $D/gate_old/logs $D/gate_new/logs
for T in old new; do for ST in ME NH VT MI WI MN; do echo "$T $ST"; done; done | xargs -P 12 -L 1 bash -c \
  'python -u s41cf_cbm_run_v3.py $1 noharv '"$D"'/gate_$0 --years 10 --src '"$D"'/cbm_$0/$1/adapted_FVS_FIAW_NEW --db '"$C"'/states/$1/data/processed/cbm_defaults_$1.db > '"$D"'/gate_$0/logs/run_$1.log 2>&1; echo "gate $0 $1 rc=$?"'
grep -h "^ASSERT" $D/gate_new/logs/run_*.log
for T in old new; do echo "### score v4 $T"; python -u $SC $D/gate_$T 2>&1 | grep -v -E "Pandas4Warning|RuntimeWarning|warnings.warn" | head -14; done
python3 - <<PY
import pandas as pd
a = pd.read_csv("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/rerun_v2_20261015/cbm_gate_results_v4_20261015.csv").set_index("state")
b = pd.read_csv("$D/gate_old/cbm_gate_results_v4_20261015.csv").set_index("state")
c = ["ratio_stock","ratio_gross","ratio_mort","ratio_net","ratio_stock_woody"]
for st in b.index: print(st, "old-curve sandbox gate vs registered s40 v4: max abs diff", float((b.loc[st, c] - a.loc[st, c]).abs().max()))
PY
echo "### merchantable-only mortality diagnostic (unchanged s41 script)"
python -u $MM $D/s41cf_merch_mort_diag_20261016.csv $D/gate_old:old_curves $D/gate_new:new_curves 2>&1 | grep -v -E "RuntimeWarning|warnings.warn"
echo "### curve volume at inventory ages over FIA VOLCFNET"
mkdir -p $D/work_ratio
python -u s41cf_curve_ratio_v1.py $D/s41cf_curve_start_ratio_old_20261016.csv old "$D/cbm_old/{ST}/adapted_FVS_FIAW_NEW" $D/work_ratio 2>&1 | grep -v -E "Warning|warn"
python -u s41cf_curve_ratio_v1.py $D/s41cf_curve_start_ratio_new_20261016.csv new "$D/cbm_new/{ST}/adapted_FVS_FIAW_NEW" $D/work_ratio 2>&1 | grep -v -E "Warning|warn"
echo "### year 50 total ecosystem carbon (2x2 F15 metric)"
python -u s41cf_tec50_v1.py $D/s41cf_tec50_20261016.csv \
  "registered_2x2:/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{ST}/libcbm_pools_{ST}_FVS_FIAW_NEW_50yr.csv" \
  "old_curves_sandbox:$D/cbm_old/{ST}/libcbm_pools_{ST}_FVS_FIAW_NEW_50yr.csv" \
  "new_curves:$D/cbm_new/{ST}/libcbm_pools_{ST}_FVS_FIAW_NEW_50yr.csv"
cp $D/gate_old/cbm_gate_results_v4_20261015.csv $D/s41cf_gate_results_v4_oldcurves_20261016.csv
cp $D/gate_new/cbm_gate_results_v4_20261015.csv $D/s41cf_gate_results_v4_newcurves_20261016.csv
cp $D/gate_new/cbm_gate_annual_components_v4_20261015.csv $D/s41cf_gate_annual_components_v4_newcurves_20261016.csv
md5sum $D/s41cf_*.csv $D/curves_new/adapter_out/sit_yield_*_calibrated.csv
echo DONE
