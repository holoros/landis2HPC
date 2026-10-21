#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s41cemI
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --array=0-26
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem/logs/%x_%A_%a.log
# s41 step I: scores the step G runs (job 15576378) as each finishes.
# Tasks 0-17 gate (cem_gate_score_s41d8.R), 18-25 hindcast (s40 scorer, verbatim
# copy), 26 out of scope area (scope_s41h.R, after the f2gate runs).
set -u
W=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem
G=15576378
i=$SLURM_ARRAY_TASK_ID
cd $W
md5sum score_fix_s41i.slurm cem_gate_score_s41d8.R scope_s41h.R hindcast_cem_gates_20261015_s40copy.R
waitfor() { for k in $(seq 1 1400); do grep -q "=== done" $W/logs/s41cemG_${G}_$1.log 2>/dev/null && return 0; sleep 30; done; return 1; }
module purge
module load gcc/12.3.0 R/4.5.2
STATES6=(ME NH VT MI WI MN)
if [ $i -lt 18 ]; then
  waitfor $i || exit 1
  v=$(( i / 6 )); ST=${STATES6[$(( i % 6 ))]}
  ENG=(engine_fix1 engine_fix2 engine_fix2); TAGS=(f1gate f2gate m1gate)
  Rscript cem_gate_score_s41d8.R $ST ${TAGS[$v]} ${ENG[$v]}
elif [ $i -lt 26 ]; then
  waitfor $i || exit 1
  j=$(( i - 18 )); v=$(( j / 2 )); STH=(ME MN); ST=${STH[$(( j % 2 ))]}
  ENG=(engine engine_fix1 engine_fix2 engine_fix2); TAGS=(h0hind h1hind h2hind m1hind)
  A=$(basename $(ls -d $W/${ENG[$v]}/output/${ST}_*_${TAGS[$v]} | head -1))
  export FIA_CEM_DIR=$W/hind_${TAGS[$v]}_${ST}
  mkdir -p $FIA_CEM_DIR
  Rscript hindcast_cem_gates_20261015_s40copy.R --state $ST --archive $A --fia_dir $HOME/fia_data --out_dir $W/${ENG[$v]}/output 2>&1 \
    | grep -E "^(SUMMARY|ANCHOR|Subject plot count|Error|  After)"
else
  for t in 6 7 8 9 10 11; do waitfor $t || exit 1; done
  Rscript scope_s41h.R
fi
