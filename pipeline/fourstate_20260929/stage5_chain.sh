#!/bin/bash
# stage5_chain.sh: after the Daymet fetch finishes, build historic tables, synthetic futures, gates. niced.
W=$HOME/landis2_fb/work_20260929; SC=$HOME/landis2_fb/scripts_20260929
source ~/opt/geos/activate.sh
until tr -d '\0' < $W/stage5_fetch.log | grep -q ALLFETCHED; do sleep 60; done
for ST in NH VT MI WI; do
  nice -n 19 Rscript $SC/stage5_daymet_to_landis.R $ST
  nice -n 19 python3 $SC/build_synthetic_cmip6_fb.py $ST
  nice -n 19 Rscript $SC/stage5_gates_synthetic.R $ST
done
echo STAGE5_DONE
