#!/bin/bash
# check_t2v2_chains.sh — one-shot status snapshot for the WA and GA T2 v2 calibration
# chains running on Cardinal. Reports current iteration, candidates landed,
# best LL per iter, and a verdict (RUNNING / LANDED / STALLED).
#
# Usage:  bash check_t2v2_chains.sh
# Output: prints to stdout, one block per chain.
set -uo pipefail
LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
PER_WA=$LANDIS/states/WA/perseus/bayesian/wa_t2_v2
PER_GA=$LANDIS/states/GA/perseus/bayesian/ga_t2_v2

check_chain () {
  local NAME=$1; local ROOT=$2
  echo "===== $NAME ====="
  if [ ! -d "$ROOT" ]; then echo "  no chain dir"; return; fi
  # Last iteration touched
  local LAST_ITER
  LAST_ITER=$(ls -td $ROOT/${NAME}_iter*_cand*/ 2>/dev/null | head -1 | sed -E "s/.*${NAME}_iter([0-9]+)_cand.*/\1/")
  [ -z "$LAST_ITER" ] && { echo "  no iters yet"; return; }
  echo "  last iter: $LAST_ITER"
  # Per-iter best LL
  local i=0
  while [ $i -le $LAST_ITER ]; do
    local BEST_LL=""; local BEST_C=""; local NCAND=0
    for d in $ROOT/${NAME}_iter${i}_cand*/; do
      [ -d "$d" ] || continue
      NCAND=$((NCAND+1))
      local LL
      LL=$(cat $d/log_likelihood.txt 2>/dev/null || echo "")
      [ -z "$LL" ] && continue
      # Skip null LLs (failed candidates)
      awk "BEGIN { exit !($LL < 0) }" || continue
      if [ -z "$BEST_LL" ] || awk "BEGIN { exit !($LL > $BEST_LL) }"; then
        BEST_LL=$LL; BEST_C=$(basename $d)
      fi
    done
    if [ -n "$BEST_LL" ]; then
      echo "  iter $i: best $BEST_C LL=$BEST_LL ($NCAND cands)"
    else
      echo "  iter $i: $NCAND cands, no LL landed"
    fi
    i=$((i+1))
  done
  # Job state
  local NJOBS
  NJOBS=$(squeue --me -h -r -o "%j" 2>/dev/null | grep -c "$NAME\|${NAME%_v2}t2" || true)
  if [ "$NJOBS" -gt 0 ]; then
    echo "  jobs in queue: $NJOBS"
    echo "  verdict: RUNNING"
  else
    # Check if production_theta is fresher than last iter LL
    local PROD=$LANDIS/states/${NAME:0:2}/perseus/production_theta_${NAME}.csv
    if [ -f "$PROD" ]; then
      echo "  verdict: LANDED (production_theta exists)"
    else
      echo "  verdict: STALLED (no jobs, no production_theta)"
    fi
  fi
  echo ""
}

check_chain wa_t2_v2 $PER_WA
check_chain ga_t2_v2 $PER_GA
