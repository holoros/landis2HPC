#!/bin/bash
# Session 36, 6 Oct 2026 (Aaron approved decision 1). Rebuild the stage three initial communities with
# the DRYBIO patched builder, same arguments as scripts_20260929/stage3_run_state.sh, but written to
# inputs/rebuild_20261006/initial_communities/ so the current ICs stay in place until the gates pass.
# Stands and the PLACEHOLDER MA are not rebuilt: they read only the IC raster and age list, which the patch does not touch.
# Usage: rebuild_ic_20261006.sh ST [ST ...]   (states run sequentially)
set -uo pipefail
FB=$HOME/landis2_fb; SC=$FB/scripts_20260929
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" LD_PRELOAD="${LD_PRELOAD:-}" PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"; source ~/opt/geos/activate.sh
for ST in "$@"; do
  IN=$FB/states/$ST/inputs; OUT=$IN/rebuild_20261006
  [ -e "$OUT/initial_communities/cohort_biomass_by_mapcode.csv" ] && { echo "[$(date)] $ST already rebuilt, skip"; continue; }
  echo "[$(date)] rebuild $ST start"
  nice -n 19 Rscript $SC/build_initial_communities_v3_fb.R --state $ST --treemap $IN/${ST}_TM_22.tif \
    --tree $FB/TREEMAP/TM2022/TreeMap2022_CONUS_Tree_Table.csv \
    --cond $HOME/restricted/ncasi-modeleval/fia_data_landis/COND_CONUS_min_20260929.csv \
    --eco $IN/ecoregions_l3_270m_20260928.tif --lookup $IN/species_lookup_${ST}.R --out $OUT > $HOME/jobs/ncasi_s36_20261006/rebuild/build_${ST}.log 2>&1
  echo "[$(date)] rebuild $ST rc=$?"
done
echo "[$(date)] queue done: $*"
