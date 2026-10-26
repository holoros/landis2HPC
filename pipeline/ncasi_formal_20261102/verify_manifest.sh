#!/bin/bash
# verify_manifest.sh: check files against the pinned NCASI formal manifest (protocol v2 rule 1, v3 item 5).
# Usage: verify_manifest.sh [-m manifest.tsv] PATH... | -f LISTFILE | - (paths on stdin)
# For every path: looks up its md5 in manifest.tsv (columns: path, md5, role) and compares with md5sum.
# Prints one line per path: OK | MISMATCH | MISSING (file absent) | NOT_IN_MANIFEST.
# Exit 0 only when every path is OK; exit 1 on any MISMATCH, MISSING or NOT_IN_MANIFEST; exit 2 on usage error.
set -u
MANIFEST=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s48/formal_prep/manifest.tsv
paths=()
while [ $# -gt 0 ]; do
  case "$1" in
    -m) MANIFEST=$2; shift 2 ;;
    -f) while IFS= read -r l; do [ -n "$l" ] && paths+=("$l"); done < "$2"; shift 2 ;;
    -)  while IFS= read -r l; do [ -n "$l" ] && paths+=("$l"); done; shift ;;
    -h|--help) sed -n '2,7p' "$0"; exit 2 ;;
    *)  paths+=("$1"); shift ;;
  esac
done
[ -r "$MANIFEST" ] || { echo "manifest not readable: $MANIFEST" >&2; exit 2; }
[ ${#paths[@]} -gt 0 ] || { echo "no paths given" >&2; exit 2; }
bad=0; ok=0
for p in "${paths[@]}"; do
  exp=$(awk -F'\t' -v p="$p" 'NR>1 && $1==p {print $2; exit}' "$MANIFEST")
  if [ -z "$exp" ]; then echo "NOT_IN_MANIFEST  $p"; bad=$((bad+1)); continue; fi
  if [ ! -f "$p" ]; then echo "MISSING          $p"; bad=$((bad+1)); continue; fi
  got=$(md5sum "$p" | cut -c1-32)
  if [ "$got" = "$exp" ]; then echo "OK               $p"; ok=$((ok+1))
  else echo "MISMATCH         $p  expected $exp got $got"; bad=$((bad+1)); fi
done
echo "verify_manifest: $ok OK, $bad not OK, manifest $MANIFEST ($(md5sum < "$MANIFEST" | cut -c1-32), $(($(wc -l < "$MANIFEST")-1)) rows)"
[ $bad -eq 0 ]
