#!/bin/bash
# stage1_install.sh: copy stage one 270 m L3 ecoregion rasters and candidate Ecoregions tables
# beside existing files in ~/landis2_fb/states/<ST>/inputs (never over them). Records md5.
set -euo pipefail
S1=$HOME/jobs/landis_stage1_20260928/out
FB=$HOME/landis2_fb
for ST in NH VT MI WI; do
  D=$FB/states/$ST/inputs; mkdir -p "$D"
  for f in ecoregions_l3_270m_20260928.tif ecoregions_candidate_20260928.txt stage1_report_${ST}.txt; do
    src=$S1/$ST/$f; dst=$D/$f
    if [ -e "$dst" ]; then
      if cmp -s "$src" "$dst"; then echo "$ST $f already installed (identical)"; else echo "FAIL $ST $f exists and differs; not overwritten"; fi
    else
      cp -p "$src" "$dst"; echo "$ST installed $f"
    fi
    a=$(md5sum < "$src" | cut -d' ' -f1); b=$(md5sum < "$dst" | cut -d' ' -f1)
    [ "$a" = "$b" ] && echo "PASS | $ST | stage1 | md5_match:$f | $b" || echo "FAIL | $ST | stage1 | md5_match:$f | $a vs $b"
  done
done
