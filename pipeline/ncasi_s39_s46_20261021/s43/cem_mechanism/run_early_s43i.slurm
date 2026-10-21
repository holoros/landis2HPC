#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --array=0-23
#SBATCH --job-name=s43iEW
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=200G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism/logs/%x_%A_%a.log
# s43 Track C ablation. Engine copy engine_c = s41 engine_fix2 (F1+F2) plus one
# line guard CEM_NO_DONOR_SWAP at E:365 (default off). Age ramp kept. Flags as
# s41 run_engine_fix_s41g.slurm (job 15576378) f2gate. Tasks 0-53: config
# c = i/6 x state i%6; task 54: c07noprod ME only.
set -u
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism
E=$T/engine_i
i=$SLURM_ARRAY_TASK_ID
STATES6=(ME NH VT MI WI MN)
CFGS=(e00base e03nodist e04nosdi e08alloff)
CFG=${CFGS[$(( i / 6 ))]}; ST=${STATES6[$(( i % 6 ))]}
md5sum $T/run_early_s43i.slurm $E/R/02_cem_matching.R $E/R/06_projection_engine.R $E/run_projection.R
module purge
module load gcc/12.3.0 R/4.4.0 proj/9.2.1 gdal/3.7.3 geos/3.12.0
export R_LIBS="${HOME}/R/cardinal_libs/4.4.0:${HOME}/R/cardinal_libs:${HOME}/R/x86_64-pc-linux-gnu-library/4.4"
unset R_LIBS_USER
export FIA_DATA_DIR=${HOME}/fia_data
unset CEM_NO_AGE_SAT
unset CEM_NO_DONOR_SWAP
HARV="--fixed_harvest_rate 0.10"; CLIM="--climate_rcp 4.5"; SDI="--use_brms_sdimax"; DIST="--use_disturbance"; POT="--use_potter_vcc"
PROD="--use_v4_prod_mult --v4_prod_mult_strength 1.0"
case $CFG in
  e00base) ;;
  c01noharv) HARV="--fixed_harvest_rate 0.10 --no_harvest_all" ;;
  c02noswap) export CEM_NO_DONOR_SWAP=1 ;;
  e03nodist) DIST="" ;;
  e04nosdi) SDI="" ;;
  c05noclim) CLIM="" ;;
  c06nopotter) POT="" ;;
  c07noprod) PROD="" ;;
  e08alloff) HARV="--fixed_harvest_rate 0.10 --no_harvest_all"; export CEM_NO_DONOR_SWAP=1; DIST=""; SDI=""; CLIM=""; POT=""; PROD="" ;;
  c09nodistsdi) DIST=""; SDI="" ;;
esac
cd $E
GEN="--untreated_donors $CLIM $HARV --include_remeasured $SDI \
 $DIST $POT --save_per_plot --skip_supply --skip_report_figs --no_econ \
 --use_owner_stratification --use_owner_balanced"
if [ "$ST" = "ME" ]; then
  EXTRA="--use_decoupled_climate --use_maine_econ --use_county_harvest $PROD"
else EXTRA=""; fi
RUN="--n_sims 20 --cycles 2 --baseline_year 2010 --baseline_window 5"
echo "=== s43I early $ST $CFG swapguard=${CEM_NO_DONOR_SWAP:-0} $(date) ==="
echo "ARGS: --state $ST $RUN --scenario_set bau --tag $CFG $GEN $EXTRA"
Rscript run_projection.R --state $ST $RUN --cores ${SLURM_CPUS_PER_TASK} --scenario_set bau --tag $CFG $GEN $EXTRA 2>&1 \
  | grep -E "^=|Iteration [123]:|Total subjects|Identified|Matched:|Unmatched:|override|Fixed harvest|Climate RCP|Error" | grep -v -E "LAT|LON|PLT_CN|CN="
echo "=== done $ST $CFG rc=${PIPESTATUS[0]} $(date) ==="
