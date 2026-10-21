#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s41cemG
#SBATCH --time=10:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=200G
#SBATCH --array=0-25
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem/logs/%x_%A_%a.log
# s41 step G. Tasks 0-17: 2020 start gate runs (F1, F1+F2, F1+F2+M1) x six
# states. Tasks 18-25: 1999 anchored hindcasts for ME and MN under the unfixed
# copy (h0), F1 (h1), F1+F2 (h2), F1+F2+M1 (m1h).
set -u
W=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem
i=$SLURM_ARRAY_TASK_ID
STATES6=(ME NH VT MI WI MN)
if [ $i -lt 18 ]; then
  v=$(( i / 6 )); ST=${STATES6[$(( i % 6 ))]}
  ENG=(engine_fix1 engine_fix2 engine_fix2); TAGS=(f1gate f2gate m1gate); AGE=(0 0 1)
  E=$W/${ENG[$v]}; TAG=${TAGS[$v]}; NOAGE=${AGE[$v]}; MODE=gate
else
  j=$(( i - 18 )); v=$(( j / 2 )); STH=(ME MN); ST=${STH[$(( j % 2 ))]}
  ENG=(engine engine_fix1 engine_fix2 engine_fix2); TAGS=(h0hind h1hind h2hind m1hind); AGE=(0 0 0 1)
  E=$W/${ENG[$v]}; TAG=${TAGS[$v]}; NOAGE=${AGE[$v]}; MODE=hind
fi
md5sum $W/run_engine_fix_s41g.slurm $E/R/02_cem_matching.R $E/R/06_projection_engine.R $E/run_projection.R
module purge
module load gcc/12.3.0 R/4.4.0 proj/9.2.1 gdal/3.7.3 geos/3.12.0
export R_LIBS="${HOME}/R/cardinal_libs/4.4.0:${HOME}/R/cardinal_libs:${HOME}/R/x86_64-pc-linux-gnu-library/4.4"
unset R_LIBS_USER
export FIA_DATA_DIR=${HOME}/fia_data
if [ "$NOAGE" = "1" ]; then export CEM_NO_AGE_SAT=1; else unset CEM_NO_AGE_SAT; fi
cd $E
GEN="--untreated_donors --climate_rcp 4.5 --fixed_harvest_rate 0.10 --include_remeasured --use_brms_sdimax \
 --use_disturbance --use_potter_vcc --save_per_plot --skip_supply --skip_report_figs --no_econ \
 --use_owner_stratification --use_owner_balanced"
if [ "$ST" = "ME" ]; then
  EXTRA="--use_decoupled_climate --use_maine_econ --use_county_harvest --use_v4_prod_mult --v4_prod_mult_strength 1.0"
else EXTRA=""; fi
if [ "$MODE" = "gate" ]; then
  RUN="--n_sims 20 --cycles 2 --baseline_year 2020 --baseline_window 5"
else
  RUN="--n_sims 20 --cycles 5 --baseline_year 1999 --baseline_window 10 --bootstrap_plots --bootstrap_frac 0.9"
fi
echo "=== s41G $ST $TAG $E noage=$NOAGE $(date) ==="
Rscript run_projection.R --state $ST $RUN --cores ${SLURM_CPUS_PER_TASK} --scenario_set bau --tag $TAG $GEN $EXTRA 2>&1 \
  | grep -E "^=|Iteration [123]:|Total subjects|Identified|Matched:|Unmatched:" | grep -v -E "LAT|LON|PLT_CN"
echo "=== done $ST $TAG rc=${PIPESTATUS[0]} $(date) ==="
