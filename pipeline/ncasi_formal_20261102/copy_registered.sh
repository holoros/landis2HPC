#!/bin/bash
# s49 formal_scripts step 1: copy the 50 registered scripts (syntax_check.tsv) into registered/<tool>/<origin>/<name>
# and verify each copy's md5 against manifest.tsv. Writes registered_md5.tsv. No script is executed.
set -u
B=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015
F=$B/s49/formal_scripts
M=$B/s48/formal_prep/manifest.tsv
S=$B/s48/formal_prep/syntax_check.tsv
OUT=$F/registered_md5.tsv
printf "manifest_path\tcopied_path\tmanifest_md5\tcopy_md5\tmatch\trole\n" > $OUT
n=0; ok=0
tail -n +2 $S | cut -f1 | while IFS= read -r p; do
  case "$p" in
    */cbm/*) tool=cbm ;;
    */cem/*|*/cem_ablation/*) tool=plot_imputation ;;
    */fvs/*|*/fvs-modern/*) tool=fvs ;;
    */osm/*) tool=osm ;;
    *) tool=landis ;;
  esac
  d=$(dirname "$p")
  origin=$(echo "$d" | sed -e "s#^$B/##" -e 's#^/users/PUOM0008/crsfaaron/#home_#' -e 's#^/fs/scratch/PUOM0008/crsfaaron/##' -e 's#/#_#g')
  dest=$F/registered/$tool/$origin/$(basename "$p")
  mkdir -p "$(dirname "$dest")"
  cp -p "$p" "$dest"
  mm=$(awk -F'\t' -v p="$p" '$1==p{print $2; exit}' $M)
  role=$(awk -F'\t' -v p="$p" '$1==p{print $3; exit}' $M)
  cm=$(md5sum "$dest" | cut -c1-32)
  if [ "$mm" = "$cm" ]; then match=yes; else match=no; fi
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$p" "$dest" "$mm" "$cm" "$match" "$role" >> $OUT
done
echo "rows: $(($(wc -l < $OUT)-1))  match yes: $(awk -F'\t' 'NR>1&&$5=="yes"' $OUT | wc -l)  no: $(awk -F'\t' 'NR>1&&$5=="no"' $OUT | wc -l)"
