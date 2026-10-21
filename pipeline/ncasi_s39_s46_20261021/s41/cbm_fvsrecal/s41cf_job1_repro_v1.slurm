#!/bin/bash
#SBATCH --job-name=s41cf_j1
#SBATCH --account=PUOM0008
#SBATCH --time=00:40:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_fvsrecal/logs/s41cf_j1_%j.out
# Step 1: rebuild the September FVS_FIAW_NEW curves from the existing calibrated FVS frame runs
# through the project yield adapter, and compare with the curves CBM used. Plus read-only probes.
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_fvsrecal
cd $D
O=$D/repro
[ -e "$O" ] && { echo "ABORT: $O exists"; exit 1; }
md5sum -c MD5SUMS_s41cf_a.txt || exit 1
mkdir -p $O/adapter_out
REF=/users/PUOM0008/crsfaaron/fia_cem_projections/config/REF_FOREST_TYPE.csv
NE=/users/PUOM0008/crsfaaron/ncasi_fvsne/out_20260907_frame/fvs-ne-stand-trajectories_DATA_2026-09-07.csv
LS=/users/PUOM0008/crsfaaron/ncasi_fvsls/out_20260907_frame/fvs-ls-stand-trajectories_DATA_2026-09-07.csv
module purge; module load gcc/12.3.0 R/4.5.2
Rscript -e 'for (p in c("data.table","minpack.lm")) cat(p, requireNamespace(p, quietly=TRUE), as.character(tryCatch(packageVersion(p), error=function(e) NA)), "\n")'
echo "### points from September frame trajectories"
COMPARE=$D/ref_fvs_growth_points_DATA_2026-09-17.csv Rscript s41cf_points_v1.R $O/points_sept_rebuilt.csv $REF \
  $NE:default:default $NE:calibrated:calibrated $LS:default:default $LS:calibrated:calibrated
echo "### adapter on rebuilt points"
Rscript s41cf_adapter_v1.R $O/points_sept_rebuilt.csv $O/adapter_out > $O/adapter.log 2>&1; echo "adapter rc=$?"
grep -E "loaded|fallback fits|wrote" $O/adapter.log
echo "### sit_yield vs the files CBM read (states/<ST>/data/processed/sit_yield.csv)"
Rscript s41cf_cmp_sityield_v1.R $O/adapter_out /users/PUOM0008/crsfaaron/cbm_states/states/%s/data/processed/sit_yield.csv $O/repro_sityield_vs_cbm.csv
echo "### coefficient table vs September"
Rscript -e 'library(data.table); a<-fread(commandArgs(TRUE)[1]); b<-fread(commandArgs(TRUE)[2]); m<-merge(a,b,by=c("state","arm","TYPGRPCD")); cat("rows", nrow(a), nrow(b), nrow(m), " max abs diff b0", max(abs(m$b0.x-m$b0.y),na.rm=TRUE), "b1", max(abs(m$b1.x-m$b1.y),na.rm=TRUE), "b2", max(abs(m$b2.x-m$b2.y),na.rm=TRUE), " scope mismatches", sum(m$fit_scope.x!=m$fit_scope.y), "\n")' $O/adapter_out/yield_curve_coefficients_DATA_2026-09-17.csv $D/ref_yield_curve_coefficients_DATA_2026-09-17.csv
echo "### probes (read only)"
C=/users/PUOM0008/crsfaaron/cbm_states
grep -n -E "sys.path|import ft_group|from ft_group|to_csv\(|shutil.copy|write_text|open\([^)]*['\"]w" $C/shared/tools/build_gcbm_input_state.py | head -30
echo ---
grep -n -E "sys.path|ft_group|to_csv\(|shutil.copy|write_text|open\([^)]*['\"]w|CBM_STATES_ROOT|cross_state" $C/cross_state/libcbm/build_libcbm_state_bundle.py | head -40
echo ---
grep -n -E "sys.path|to_csv\(|shutil.copy|write_text|CBM_STATES_ROOT|states/|processed" $C/cross_state/libcbm/adapt_state_to_libcbm.py | head -40
echo ---
grep -n -E "CBM_STATES_ROOT|states/|to_csv|argparse|add_argument" $C/cross_state/libcbm/run_libcbm.py | head -20
ls -la $C/cross_state/libcbm/ME | head -30
for ST in ME NH VT MI WI MN; do echo "$ST $(ls -t $C/states/$ST/data/processed/pixel_attributes_fia_*.csv | head -1) area $(awk -F, 'NR>1{s+=$2}END{printf "%.0f", s}' $C/states/$ST/data/processed/fia_expns_grp_areas_${ST}.csv) md5 sit_yield $(md5sum < $C/states/$ST/data/processed/sit_yield.csv | cut -c1-12) gcbmdb $(stat -c %y $C/states/$ST/data/processed/gcbm_input_${ST}.db)"; done
ls -la /users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_ME/adapted_FVS_FIAW_NEW
head -3 /users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_ME/adapted_FVS_FIAW_NEW/growth_and_yield.csv | cut -c1-300
cat /users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_ME/adapted_FVS_FIAW_NEW/age_classes.csv | head -25 | tr '\n' ' '; echo
du -sh $C/states/*/config 2>/dev/null | tr '\n' ' '; echo
ls $C/states/ME/config
md5sum $O/adapter_out/*.csv $O/points_sept_rebuilt.csv $O/repro_sityield_vs_cbm.csv
echo DONE
