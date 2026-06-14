#!/bin/bash
## build_inputs_state.sh - state-generalized GCBM input tiler (from build_inputs.sh).
## Reprojects a state's source-raster stack (gcbm_rasters_2022_<ST>) to WGS84 and slices it
## into the 1deg / 4000x4000 tiles moja FLINT expects. Generalizes the Maine-only build_inputs.sh:
##   - tile list computed from the state stack extent (build_tile_list_state.py), not hardcoded
##   - mean annual temperature taken per state (--mat), NOT Maine's 5.67 degC (would bias growth
##     for warmer/cooler states - the key CONUS parameterization requirement)
##   - <st>_ source prefixes and gcbm_<ST>_tiled output dir
## The CBM AIDB (cbm_defaults_maine.db) is the generic CBM defaults DB and is reused for all states.
##
## Usage: build_inputs_state.sh <ST> <MAT_degC>
##   e.g. build_inputs_state.sh MN 4.1   (per-state MAT from PRISM; see derive_state_mat.sh)
set -euo pipefail
ST="${1:?usage: build_inputs_state.sh <ST> <MAT_degC>}"
MAT="${2:?supply per-state mean annual temperature in degC (do NOT default to Maine 5.67)}"
st="$(echo "$ST" | tr 'A-Z' 'a-z')"
PROJECT_ROOT=${PROJECT_ROOT:-$HOME/cbm_maine}
SRC_DIR=$PROJECT_ROOT/data/processed/gcbm_rasters_2022_${ST}
DST_DIR=$PROJECT_ROOT/data/processed/gcbm_${ST}_tiled
[ -d "$SRC_DIR" ] || { echo "missing source stack $SRC_DIR (run build_state_gcbm_stack.R $ST first)"; exit 1; }
mkdir -p "$DST_DIR/db" "$DST_DIR/layers/tiled" "$DST_DIR/_wgs84" "$DST_DIR/configs"
cp "$PROJECT_ROOT/data/processed/cbm_defaults_maine.db" "$DST_DIR/db/" 2>/dev/null || true

WGS_DIR="$DST_DIR/_wgs84"
reproject() { local src="$1"; local out="$WGS_DIR/$(basename "$src" .tif)_wgs84.tif"
  [ -f "$out" ] || gdalwarp -overwrite -t_srs EPSG:4326 -tr 0.00025 0.00025 -r near \
      -multi -wo NUM_THREADS=8 -co COMPRESS=DEFLATE -co TILED=YES "$src" "$out" >&2
  printf '%s' "$out"; }
FORTYPE_WGS=$(reproject "$SRC_DIR/${st}_fortypcd.tif")
STDAGE_WGS=$(reproject "$SRC_DIR/${st}_stdage.tif")
ECOREGION_WGS=$(reproject "$SRC_DIR/${st}_ecoregion_l3.tif")
DIST_WGS=$(reproject "$SRC_DIR/${st}_lcms_cause_2022.tif")

## constant MAT raster at the per-state value (collapses input to MAT via -scale dst_min==dst_max)
MAT_WGS="$WGS_DIR/${st}_mat_wgs84.tif"
[ -f "$MAT_WGS" ] || gdal_translate -of GTiff -ot Float32 -scale 0 65535 "$MAT" "$MAT" \
    -a_nodata -3.4e38 -co COMPRESS=DEFLATE -co TILED=YES "$ECOREGION_WGS" "$MAT_WGS" >&2

## tile list from the WGS84 stack extent (1 deg tiles intersecting the state)
read_extent_tiles() {  # echo "X Y" pairs of integer-degree tile corners covering the raster
  gdalinfo "$1" 2>/dev/null | awk '
    /Lower Left/  {gsub(/[(),]/," "); xmin=$3; ymin=$4}
    /Upper Right/ {gsub(/[(),]/," "); xmax=$3; ymax=$4}
    END { for (x=int(xmin)-1; x<=int(xmax); x++) for (y=int(ymin)-1; y<=int(ymax); y++) printf "%d %d ", x, y }'
}
TILE_LIST=$(read_extent_tiles "$ECOREGION_WGS")
echo "$ST tiles: $TILE_LIST"

slice_to_tiles() { local src="$1"; local outdir="$2"; local prefix="$3"; mkdir -p "$outdir"
  set -- $TILE_LIST
  while [ $# -ge 2 ]; do X=$1; Y=$2; XMAX=$((X+1)); YMAX=$((Y+1))
    gdal_translate -projwin $X $YMAX $XMAX $Y -outsize 4000 4000 \
      -co COMPRESS=DEFLATE -co TILED=YES "$src" "$outdir/${prefix}_${X}_${Y}.tiff" 2>/dev/null \
      || echo "  skip empty tile $X $Y"; shift 2; done; }
slice_to_tiles "$STDAGE_WGS"    "$DST_DIR/layers/tiled/initial_age"              "initial_age_moja.tiff"
slice_to_tiles "$FORTYPE_WGS"   "$DST_DIR/layers/tiled/classifier_forest_type"  "Classifier1_moja.tiff"
slice_to_tiles "$ECOREGION_WGS" "$DST_DIR/layers/tiled/classifier_ecoregion"    "Classifier2_moja.tiff"
slice_to_tiles "$MAT_WGS"       "$DST_DIR/layers/tiled/mean_annual_temperature" "mean_annual_temperature_moja.tiff"
slice_to_tiles "$DIST_WGS"      "$DST_DIR/layers/tiled/disturbances_2022"       "disturbances_2022_moja.tiff"

cp "$PROJECT_ROOT/tools/gcbm_maine"/*.json "$DST_DIR/configs/" 2>/dev/null || true
cp "$PROJECT_ROOT/tools/gcbm_maine"/*.cfg  "$DST_DIR/configs/" 2>/dev/null || true
cp "$PROJECT_ROOT/data/external/gcbm_templates/templates/templates"/{pools_cbm,modules_cbm,modules_output,spinup,internal_variables}.json "$DST_DIR/configs/" 2>/dev/null || true
echo "Done. $ST GCBM input bundle at $DST_DIR (MAT=$MAT degC)"; du -sh "$DST_DIR"
