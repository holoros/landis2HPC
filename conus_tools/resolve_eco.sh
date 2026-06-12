#!/bin/bash
# resolve_eco.sh  —  data-driven ecoregion resolver for build_plot_scenario_<ST>.sh
#
# Drop-in replacement for the hardcoded `case "$RAW_ECO" in ... esac` block that
# caused the WI/MI silent failure (and the latent GA/OH gaps). Resolves a raw
# plot ecoregion to its model ecoregion and name using two data files instead of
# shell code, so onboarding a state or ecoregion is a CSV edit, never a code edit:
#
#   eco_crosswalk_<ST>.csv   raw_eco,model_eco[,eco_name,kind]   (optional; identity if absent)
#   ecoregion_names.csv      eco_code,eco_name                   (required)
#
# It fails LOUDLY on an unknown ecoregion (missing name) rather than silently
# producing an empty SppEcoregionData and a header-only trajectory.
#
# Usage inside a build script, after RAW_ECO is read from plot_to_ecoregion:
#   ST=MI
#   source "$(dirname "$0")/../conus_tools/resolve_eco.sh"
#   resolve_eco "$RAW_ECO" "$ST"      # sets $ECO and $ECO_NAME, or exits non-zero
#
# Overridable paths: ECO_XWALK_DIR (default = dir of this script's ../tools),
# ECO_NAMES (default = this script's dir/ecoregion_names.csv).

resolve_eco() {
  local raw="$1" st="$2"
  local here names xwalk
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  names="${ECO_NAMES:-$here/ecoregion_names.csv}"
  xwalk="${ECO_XWALK:-${ECO_XWALK_DIR:-$here/../tools}/eco_crosswalk_${st}.csv}"

  if [ -z "$raw" ]; then echo "ERROR resolve_eco: empty raw ecoregion"; exit 4; fi
  if [ "$raw" = "0" ]; then echo "SKIP: eco 0 (nodata)"; exit 5; fi
  if [ ! -f "$names" ]; then echo "ERROR resolve_eco: names table not found: $names"; exit 7; fi

  # raw -> model via crosswalk; identity if no crosswalk row
  if [ -f "$xwalk" ]; then
    ECO=$(awk -F, -v r="$raw" 'NR>1 && $1==r{print $2; exit}' "$xwalk")
  fi
  [ -z "${ECO:-}" ] && ECO="$raw"

  local nm
  nm=$(awk -F, -v c="$ECO" 'NR>1 && $1==c{print $2; exit}' "$names")
  if [ -z "$nm" ]; then
    echo "ERROR resolve_eco: ecoregion $ECO (raw $raw) has no name in $names."
    echo "  Add a row to ecoregion_names.csv, or add a raw->model remap to $xwalk,"
    echo "  then run compose_sppeco_baseline.R so the baseline covers ecoregion $ECO."
    exit 6
  fi
  ECO_NAME="\"$nm\""
  export ECO ECO_NAME
}
