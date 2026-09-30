#!/bin/bash
# Stage 7 chain, session 32: 30 m ecoregion raster + state_finish for NH VT MI WI, sequential, detached
source ~/opt/geos/activate.sh
cd ~/landis2_fb/scripts_20260929
W=~/landis2_fb/work_20260929
for ST in NH VT MI WI; do
  echo "== $ST 7a start $(date)" >> $W/stage7_chain.log
  Rscript stage7_ecoregions30_20260930.R $ST > $W/stage7a_$ST.log 2>&1; echo "7a exit $? $(date)" >> $W/stage7_chain.log
  Rscript stage7_gate_instate_20260930.R $ST > $W/stage7g_$ST.log 2>&1; echo "7g exit $? $(date)" >> $W/stage7_chain.log
  Rscript state_finish_ecoregion_fb_20260930.R $ST > $W/stage7b_$ST.log 2>&1; echo "7b exit $? $(date)" >> $W/stage7_chain.log
done
echo "STAGE7_CHAIN_DONE $(date)" >> $W/stage7_chain.log
