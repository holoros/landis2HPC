#!/bin/bash
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}" LD_PRELOAD="${LD_PRELOAD:-}" PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}"; source ~/opt/geos/activate.sh
cd ~/jobs/ncasi_s36_20261006/rebuild
Rscript gate_rebuild_20261006.R MI WI; rc=$?; echo "GATE_RC=$rc"
[ $rc -eq 0 ] && { Rscript anchor_ic_fourstate_fb_20261006.R MI WI; echo "ANCHOR_RC=$?"; }
echo DONE
