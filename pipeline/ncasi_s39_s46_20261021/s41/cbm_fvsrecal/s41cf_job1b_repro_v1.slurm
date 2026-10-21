#!/bin/bash
#SBATCH --job-name=s41cf_j1b
#SBATCH --account=PUOM0008
#SBATCH --time=00:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=24G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_fvsrecal/logs/s41cf_j1b_%j.out
# Step 1 retry: same as job 1 but forest type group labels per stand taken from the September points file
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_fvsrecal
cd $D
O=$D/repro_b
[ -e "$O" ] && { echo "ABORT: $O exists"; exit 1; }
printf "%s  s41cf_points_v2.R\n" $(cat MD5_points_v2.txt) | md5sum -c - || exit 1
md5sum -c MD5SUMS_s41cf_a.txt || exit 1
mkdir -p $O/adapter_out
REF=/users/PUOM0008/crsfaaron/fia_cem_projections/config/REF_FOREST_TYPE.csv
NE=/users/PUOM0008/crsfaaron/ncasi_fvsne/out_20260907_frame/fvs-ne-stand-trajectories_DATA_2026-09-07.csv
LS=/users/PUOM0008/crsfaaron/ncasi_fvsls/out_20260907_frame/fvs-ls-stand-trajectories_DATA_2026-09-07.csv
module purge; module load gcc/12.3.0 R/4.5.2
LABELS=$D/ref_fvs_growth_points_DATA_2026-09-17.csv COMPARE=$D/ref_fvs_growth_points_DATA_2026-09-17.csv Rscript s41cf_points_v2.R $O/points_sept_rebuilt.csv $REF \
  $NE:default:default $NE:calibrated:calibrated $LS:default:default $LS:calibrated:calibrated
Rscript s41cf_adapter_v1.R $O/points_sept_rebuilt.csv $O/adapter_out > $O/adapter.log 2>&1; echo "adapter rc=$?"
grep -E "loaded|fallback fits" $O/adapter.log
Rscript s41cf_cmp_sityield_v1.R $O/adapter_out /users/PUOM0008/crsfaaron/cbm_states/states/%s/data/processed/sit_yield.csv $O/repro_sityield_vs_cbm.csv
Rscript -e 'library(data.table); a<-fread(commandArgs(TRUE)[1]); b<-fread(commandArgs(TRUE)[2]); m<-merge(a,b,by=c("state","arm","TYPGRPCD")); cat("coef rows", nrow(a), nrow(b), nrow(m), " max abs diff b0", max(abs(m$b0.x-m$b0.y),na.rm=TRUE), "b1", max(abs(m$b1.x-m$b1.y),na.rm=TRUE), "b2", max(abs(m$b2.x-m$b2.y),na.rm=TRUE), "\n")' $O/adapter_out/yield_curve_coefficients_DATA_2026-09-17.csv $D/ref_yield_curve_coefficients_DATA_2026-09-17.csv
cmp $O/points_sept_rebuilt.csv $D/ref_fvs_growth_points_DATA_2026-09-17.csv && echo "points file BYTE IDENTICAL to September"
md5sum $O/points_sept_rebuilt.csv $O/adapter_out/sit_yield_*_calibrated.csv
