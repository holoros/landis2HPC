#!/bin/bash
# check_t2v2_chains.sh — status snapshot for PERSEUS Tier 2 CMA-ES calibration chains
# on Cardinal. Reports, per chain: last iteration, candidates landed, best LL per iter,
# and a verdict (RUNNING / PROMOTED / LANDED / STALLED).
#
# v2 (2026-05-31): two correctness fixes plus generalization.
#   1. Promotion is now detected at the path the harvester actually writes,
#      $CHAIN_DIR/theta_best_production.csv (harvest_t2_chains.py line ~123), instead of
#      the never-written states/<ST>/perseus/production_theta_<chain>.csv. This stops
#      landed-and-harvested chains (WA/GA v2) from falsely reading as STALLED.
#   2. STALLED is now reserved for genuine early death: no queue job, no promotion, and
#      the chain never produced a scored iteration beyond iter0. A finished-but-unharvested
#      chain reads LANDED, not STALLED.
#   3. With no args, scans every states/<ST>/perseus/bayesian/<chain> automatically, so
#      the monitor covers the CONUS expansion (IN, OH, and future states) without edits.
#
# Usage:
#   bash check_t2v2_chains.sh                 # scan all chains
#   bash check_t2v2_chains.sh wa_t2_v2 ga_t2_v2   # only named chains (any state)
set -uo pipefail
LANDIS=${LANDIS:-/fs/scratch/PUOM0008/crsfaaron/landis2}

check_chain () {
  local ROOT=$1
  local NAME; NAME=$(basename "$ROOT")
  echo "===== $NAME ====="
  if [ ! -d "$ROOT" ]; then echo "  no chain dir"; echo ""; return; fi

  # Last iteration touched (highest iterN among candidate dirs).
  # Use find (not a bare glob) so an empty match never degrades to `ls .`; keep digits only.
  local LAST_ITER
  LAST_ITER=$(find "$ROOT" -maxdepth 1 -type d -name "${NAME}_iter*_cand*" 2>/dev/null \
    | sed -E "s/.*_iter([0-9]+)_cand.*/\1/" | grep -E '^[0-9]+$' | sort -n | tail -1)
  if [ -z "$LAST_ITER" ]; then
    echo "  no iters yet"
  else
    echo "  last iter: $LAST_ITER"
  fi

  # Per-iter best (least-negative) signed LL, counting only negative (valid) LLs.
  local scored_iters=0
  local i=0
  while [ -n "$LAST_ITER" ] && [ "$i" -le "$LAST_ITER" ]; do
    local BEST_LL="" BEST_C="" NCAND=0
    for d in "$ROOT"/${NAME}_iter${i}_cand*/; do
      [ -d "$d" ] || continue
      NCAND=$((NCAND+1))
      local LL; LL=$(cat "$d/log_likelihood.txt" 2>/dev/null || echo "")
      [ -z "$LL" ] && continue
      awk "BEGIN { exit !($LL < 0) }" || continue
      if [ -z "$BEST_LL" ] || awk "BEGIN { exit !($LL > $BEST_LL) }"; then
        BEST_LL=$LL; BEST_C=$(basename "$d")
      fi
    done
    if [ -n "$BEST_LL" ]; then
      echo "  iter $i: best $BEST_C LL=$BEST_LL ($NCAND cands)"
      scored_iters=$((scored_iters+1))
    else
      echo "  iter $i: $NCAND cands, no LL landed"
    fi
    i=$((i+1))
  done

  # Verdict
  local NJOBS
  NJOBS=$(squeue --me -h -r -o "%j" 2>/dev/null | grep -cE "(^|[^A-Za-z])${NAME}([^A-Za-z]|$)" || true)
  if [ "${NJOBS:-0}" -gt 0 ]; then
    echo "  jobs in queue: $NJOBS"
    echo "  verdict: RUNNING"
  elif [ -f "$ROOT/theta_best_production.csv" ]; then
    local PROD_TAG; PROD_TAG=$(awk -F, 'NR==2{print $2}' "$ROOT/theta_best_production.csv" 2>/dev/null)
    echo "  verdict: PROMOTED (theta_best_production.csv present)"
  elif [ "$scored_iters" -gt 1 ]; then
    echo "  verdict: LANDED (finished, not yet harvested — run harvest_t2_chains.py)"
  else
    echo "  verdict: STALLED (no jobs, no promotion, <=1 scored iter — likely died early)"
  fi
  echo ""
}

if [ "$#" -gt 0 ]; then
  # Named chains: resolve each under any state's bayesian dir.
  for name in "$@"; do
    found=""
    for d in "$LANDIS"/states/*/perseus/bayesian/"$name"; do
      [ -d "$d" ] && { check_chain "$d"; found=1; }
    done
    [ -z "$found" ] && { echo "===== $name ====="; echo "  no chain dir found under any state"; echo ""; }
  done
else
  # Scan all chains across all states.
  shopt -s nullglob
  any=""
  for d in "$LANDIS"/states/*/perseus/bayesian/*; do
    [ -d "$d" ] || continue
    case "$(basename "$d")" in
      *_iter*_cand*) continue ;;  # skip candidate dirs
    esac
    check_chain "$d"; any=1
  done
  [ -z "$any" ] && echo "no calibration chains found under $LANDIS/states/*/perseus/bayesian/"
fi
