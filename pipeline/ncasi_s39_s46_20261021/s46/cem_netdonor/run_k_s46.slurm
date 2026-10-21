#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s46kE
#SBATCH --time=02:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=80G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cem_netdonor/logs/%x_%A_%a.log
# s46 Track K amended (post unblinding follow-on, not gate eligible). Flags identical to s45 run_k_s45.slurm
# (= s43 c00base for 2020, e00base for 2010). Task i: CFGS[i/6], STATES6[i%6].
# u3,u4,u5: engine_unf (verbatim s43 engine_c md5 set), unfixed reruns, identical seeds.
# f20a,f20b: engine_fix, determinism pair (separate jobs, same core count). f20c: engine_fix, core count diagnostic.
# f20s: engine_fix, different seed (CEM_SEED_OFFSET). k20null/k20net/k10net: engine_fixk (fix + s45 netting). k10ref: engine_fix.
set -u
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cem_netdonor
S45=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor
i=$SLURM_ARRAY_TASK_ID
STATES6=(ME NH VT MI WI MN)
CFGS=(u3 u4 u5 f20a f20b f20c f20s k20null k20net k10ref k10net)
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
unset CEM_NO_AGE_SAT CEM_NO_DONOR_SWAP CEM_NETDONOR CEM_NETDONOR_NULL CEM_NETDONOR_DIAG CEM_NETDONOR_TAB_DIR CEM_NETDONOR_STATES CEM_SEED_OFFSET
case $CFG in
  u3|u4|u5) E=$T/engine_unf ;;
  f20a|f20b|f20c|f20s|k10ref) E=$T/engine_fix ;;
  *) E=$T/engine_fixk; export CEM_NETDONOR=1 CEM_NETDONOR_TAB_DIR=$S45/work CEM_NETDONOR_STATES=$DS
     export CEM_NETDONOR_DIAG=$T/work/diag/${CFG}_${ST}; rm -rf $CEM_NETDONOR_DIAG; mkdir -p $CEM_NETDONOR_DIAG ;;
esac
[ "$CFG" = "k20null" ] && export CEM_NETDONOR_NULL=1
[ "$CFG" = "f20s" ] && export CEM_SEED_OFFSET=104729
case $CFG in k10*) BY=2010 ;; *) BY=2020 ;; esac
TAG=${CFG}_postunblind_followon_not_gate_eligible
echo "nproc=$(nproc) SLURM_CPUS_PER_TASK=${SLURM_CPUS_PER_TASK} host=$(hostname)"
md5sum $T/run_k_s46.slurm $E/R/*.R $E/run_projection.R
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
echo "=== s46K $ST $CFG netdonor=${CEM_NETDONOR:-0} null=${CEM_NETDONOR_NULL:-0} seedoff=${CEM_SEED_OFFSET:-0} donors=$DS $(date) ==="
echo "ARGS: --state $ST $RUN --scenario_set bau --tag $TAG $GEN $EXTRA"
Rscript run_projection.R --state $ST $RUN --cores ${SLURM_CPUS_PER_TASK} --scenario_set bau --tag $TAG $GEN $EXTRA 2>&1 \
  | grep -E "^=|Iteration [123]:|Total subjects|Identified|Matched:|Unmatched:|override|Fixed harvest|Climate RCP|Error|s45 Track K|s46|Disturbance @" | grep -v -E "LAT|LON|PLT_CN|CN="
echo "=== done $ST $CFG rc=${PIPESTATUS[0]} $(date) ==="
