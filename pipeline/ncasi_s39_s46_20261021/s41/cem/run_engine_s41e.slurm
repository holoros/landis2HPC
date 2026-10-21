#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s41cemE
#SBATCH --time=03:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=200G
#SBATCH --array=0-3
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem/logs/%x_%A_%a.log
# s41 step E: attribution runs for the engine residual. Same as step B for NH
# and MN, with either the BRMS SDImax cap or the episodic disturbance module
# switched off. Diagnostic only; not gate runs.
set -u
W=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem
E=$W/engine
md5sum $W/run_engine_s41e.slurm $E/run_projection.R $E/R/06_projection_engine.R
ST=(NH NH MN MN); VAR=(nosdi nodist nosdi nodist)
S=${ST[$SLURM_ARRAY_TASK_ID]}; V=${VAR[$SLURM_ARRAY_TASK_ID]}
module purge
module load gcc/12.3.0 R/4.4.0 proj/9.2.1 gdal/3.7.3 geos/3.12.0
export R_LIBS="${HOME}/R/cardinal_libs/4.4.0:${HOME}/R/cardinal_libs:${HOME}/R/x86_64-pc-linux-gnu-library/4.4"
unset R_LIBS_USER
export FIA_DATA_DIR=${HOME}/fia_data
cd $E
SDI="--use_brms_sdimax"; DIST="--use_disturbance"
[ "$V" = "nosdi" ] && SDI=""
[ "$V" = "nodist" ] && DIST=""
echo "=== s41 engine $S $V $(date) ==="
Rscript run_projection.R --state $S --n_sims 20 --cycles 2 --cores ${SLURM_CPUS_PER_TASK} --scenario_set bau --tag s41${V} \
 --baseline_year 2020 --baseline_window 5 --untreated_donors --climate_rcp 4.5 \
 --fixed_harvest_rate 0.10 --include_remeasured $SDI $DIST \
 --use_potter_vcc --save_per_plot --skip_supply --skip_report_figs --no_econ \
 --use_owner_stratification --use_owner_balanced 2>&1 | grep -E "^=|Identified|Total subjects" | head -20
echo "=== done $S $V rc=${PIPESTATUS[0]} $(date) ==="
