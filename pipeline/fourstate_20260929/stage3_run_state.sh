#!/bin/bash
# stage3_run_state.sh <ST>: IC builder (v3, firebreather adaptation) -> stands + PLACEHOLDER MA -> gates. niced.
set -uo pipefail
ST=$1; FB=$HOME/landis2_fb; SC=$FB/scripts_20260929; IN=$FB/states/$ST/inputs
source ~/opt/geos/activate.sh
TM=$IN/${ST}_TM_22.tif
COND=$HOME/restricted/ncasi-modeleval/fia_data_landis/COND_CONUS_min_20260929.csv
echo "[$(date)] stage3 $ST start"
nice -n 19 Rscript $SC/build_initial_communities_v3_fb.R --state $ST --treemap $TM \
  --tree $FB/TREEMAP/TM2022/TreeMap2022_CONUS_Tree_Table.csv --cond $COND \
  --eco $IN/ecoregions_l3_270m_20260928.tif --lookup $IN/species_lookup_${ST}.R --out $IN
rc=$?; echo "[$(date)] builder rc=$rc"
[ $rc -eq 0 ] || exit $rc
nice -n 19 Rscript $SC/stage3_stands.R $ST $IN/initial_communities/initial-communities.tif $IN/initial_communities/initial_communities.txt
echo "[$(date)] stage3 $ST done rc=$?"
nice -n 19 Rscript $SC/stage6_placeholder_ma.R $ST
echo "[$(date)] stage6 $ST done rc=$?"
