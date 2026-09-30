#!/bin/bash
source ~/opt/geos/activate.sh; cd ~/landis2_fb/scripts_20260929; W=~/landis2_fb/work_20260929
for ST in NH VT; do Rscript stage7_gate_instate_20260930.R $ST > $W/stage7g_$ST.log 2>&1; done
while ! grep -q STAGE7_CHAIN_DONE $W/stage7_chain.log; do sleep 30; done
for ST in MI WI; do [ -f $W/stage7g_$ST.log ] && grep -q "PASS\|FAIL" $W/stage7g_$ST.log || Rscript stage7_gate_instate_20260930.R $ST > $W/stage7g_$ST.log 2>&1; done
echo GATE_CHAIN_DONE $(date) >> $W/stage7_chain.log
