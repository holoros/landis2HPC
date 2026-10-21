#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s41cemB
#SBATCH --time=08:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=200G
#SBATCH --array=0-5
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem/logs/%x_%A_%a.log
# s41 step B: one state targeted plot imputation run per state, start = the
# 2020 to 2024 FIA panel (baseline 2020, window 5, include_remeasured), two
# 5 year cycles (first ten years), BAU only, 20 sims, no plot bootstrap.
# Flags otherwise follow the l7b production launchers (ME: Maine set; others:
# the generic MN set). R 4.4.0 stack because the engine needs rFIA and sf.
set -u
W=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem
E=$W/engine
md5sum $W/run_engine_s41b.slurm $E/run_projection.R $E/R/06_projection_engine.R
STATES=(ME NH VT MI WI MN)
ST=${STATES[$SLURM_ARRAY_TASK_ID]}
module purge
module load gcc/12.3.0 R/4.4.0 proj/9.2.1 gdal/3.7.3 geos/3.12.0
export R_LIBS="${HOME}/R/cardinal_libs/4.4.0:${HOME}/R/cardinal_libs:${HOME}/R/x86_64-pc-linux-gnu-library/4.4"
unset R_LIBS_USER
export FIA_DATA_DIR=${HOME}/fia_data
cd $E
COMMON="--n_sims 20 --cycles 2 --cores ${SLURM_CPUS_PER_TASK} --scenario_set bau --tag s41gate \
 --baseline_year 2020 --baseline_window 5 --untreated_donors --climate_rcp 4.5 \
 --fixed_harvest_rate 0.10 --include_remeasured --use_brms_sdimax --use_disturbance \
 --use_potter_vcc --save_per_plot --skip_supply --skip_report_figs --no_econ \
 --use_owner_stratification --use_owner_balanced"
if [ "$ST" = "ME" ]; then
  EXTRA="--use_decoupled_climate --use_maine_econ --use_county_harvest --use_v4_prod_mult --v4_prod_mult_strength 1.0"
else
  EXTRA=""
fi
echo "=== s41 engine $ST $(date) ==="
Rscript run_projection.R --state $ST $COMMON $EXTRA 2>&1 | grep -v -E "LAT|LON|PLT_CN" 
echo "=== done $ST rc=${PIPESTATUS[0]} $(date) ==="
