#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s45kE
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=80G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor/logs/%x_%A_%a.log
# s45 Track K (post unblinding follow-on, not gate eligible). Flags identical to s43 run_ablation_s43c.slurm c00base
# (2020) and s43 run_early_s43i.slurm e00base (2010). Task i: config CFGS[i/6], state STATES6[i%6].
# k20ref/k10ref: engine_kref (verbatim s43 engine_c). k20null: engine_k, netting on, donor mortality forced to 0.
# k20net/k10net: engine_k, netting on.
set -u
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor
i=$SLURM_ARRAY_TASK_ID
STATES6=(ME NH VT MI WI MN)
CFGS=(k20ref k20null k20net k10ref k10net)
CFG=${CFGS[$(( i / 6 ))]}; ST=${STATES6[$(( i % 6 ))]}
case $ST in
  ME) DS="ME,NH,VT,NY,MA,CT,RI" ;; NH) DS="NH,ME,VT,MA,CT" ;; VT) DS="VT,NH,NY,MA,ME" ;;
  WI) DS="WI,MN,MI,IA,IL" ;; MN) DS="MN,WI,MI,IA" ;; MI) DS="MI,WI,MN,OH,IN" ;;
esac
module purge
module load gcc/12.3.0 R/4.4.0 proj/9.2.1 gdal/3.7.3 geos/3.12.0
export R_LIBS="${HOME}/R/cardinal_libs/4.4.0:${HOME}/R/cardinal_libs:${HOME}/R/x86_64-pc-linux-gnu-library/4.4"
unset R_LIBS_USER
export FIA_DATA_DIR=${HOME}/fia_data
unset CEM_NO_AGE_SAT CEM_NO_DONOR_SWAP CEM_NETDONOR CEM_NETDONOR_NULL CEM_NETDONOR_DIAG CEM_NETDONOR_TAB_DIR CEM_NETDONOR_STATES
case $CFG in
  k20ref|k10ref) E=$T/engine_kref ;;
  *) E=$T/engine_k; export CEM_NETDONOR=1 CEM_NETDONOR_TAB_DIR=$T/work CEM_NETDONOR_STATES=$DS
     export CEM_NETDONOR_DIAG=$T/work/diag/${CFG}_${ST}; rm -rf $CEM_NETDONOR_DIAG; mkdir -p $CEM_NETDONOR_DIAG ;;
esac
[ "$CFG" = "k20null" ] && export CEM_NETDONOR_NULL=1
case $CFG in k20*) BY=2020 ;; k10*) BY=2010 ;; esac
TAG=${CFG}_postunblind_followon_not_gate_eligible
md5sum $T/run_k_s45.slurm $E/R/02_cem_matching.R $E/R/06_projection_engine.R $E/run_projection.R
[ -f $E/R/16_netdonor_fns.R ] && md5sum $E/R/16_netdonor_fns.R
HARV="--fixed_harvest_rate 0.10"; CLIM="--climate_rcp 4.5"; SDI="--use_brms_sdimax"; DIST="--use_disturbance"; POT="--use_potter_vcc"
PROD="--use_v4_prod_mult --v4_prod_mult_strength 1.0"
cd $E
GEN="--untreated_donors $CLIM $HARV --include_remeasured $SDI \
 $DIST $POT --save_per_plot --skip_supply --skip_report_figs --no_econ \
 --use_owner_stratification --use_owner_balanced"
if [ "$ST" = "ME" ]; then
  EXTRA="--use_decoupled_climate --use_maine_econ --use_county_harvest $PROD"
else EXTRA=""; fi
RUN="--n_sims 20 --cycles 2 --baseline_year $BY --baseline_window 5"
echo "=== s45K $ST $CFG netdonor=${CEM_NETDONOR:-0} null=${CEM_NETDONOR_NULL:-0} donors=$DS $(date) ==="
echo "ARGS: --state $ST $RUN --scenario_set bau --tag $TAG $GEN $EXTRA"
Rscript run_projection.R --state $ST $RUN --cores ${SLURM_CPUS_PER_TASK} --scenario_set bau --tag $TAG $GEN $EXTRA 2>&1 \
  | grep -E "^=|Iteration [123]:|Total subjects|Identified|Matched:|Unmatched:|override|Fixed harvest|Climate RCP|Error|s45 Track K|Disturbance @" | grep -v -E "LAT|LON|PLT_CN|CN="
echo "=== done $ST $CFG rc=${PIPESTATUS[0]} $(date) ==="
