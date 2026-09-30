#!/bin/bash
# stage3_queues.sh A|B : two worker queues (brief: at most 2 parallel workers, nice 19).
# A: wait stage2 NH+VT -> merge COND -> stage3 NH -> stage3 VT -> wait stage2 MI -> stage3 MI
# B: wait stage2 MI (chained after WI) and merged COND -> stage3 WI
W=$HOME/landis2_fb/work_20260929; SC=$HOME/landis2_fb/scripts_20260929
waitfor() { until grep -q "$2" "$1" 2>/dev/null; do sleep 60; done; }
source ~/opt/geos/activate.sh
if [ "$1" = A ]; then
  waitfor $W/stage2_NH.log "stage2 done NH"; waitfor $W/stage2_VT.log "stage2 done VT"
  nice -n 19 Rscript $SC/stage3_cond_merge.R > $W/stage3_cond_merge.log 2>&1; echo "COND_MERGE_DONE" >> $W/stage3_cond_merge.log
  bash $SC/stage3_run_state.sh NH > $W/stage3_NH.log 2>&1
  bash $SC/stage3_run_state.sh VT > $W/stage3_VT.log 2>&1
  waitfor $W/stage2_MI.log "stage2 done MI"
  bash $SC/stage3_run_state.sh MI > $W/stage3_MI.log 2>&1
else
  waitfor $W/stage2_MI.log "stage2 done MI"; waitfor $W/stage3_cond_merge.log "COND_MERGE_DONE"
  bash $SC/stage3_run_state.sh WI > $W/stage3_WI.log 2>&1
fi
echo "queue $1 finished $(date)"
