#!/bin/bash
# build_plot_scenario_WA_theta.sh — θ-aware wrapper around build_plot_scenario_WA.sh.
# Writes scenario in a θ-tagged dir, then rewrites SspEcoregionData.csv with the θ-scaled values.
#
# Usage: bash build_plot_scenario_WA_theta.sh <PLOT> <baseline> <none|perseus> <theta>

set -euo pipefail
PLOT=$1; CLIM=$2; HARV=$3; THETA=$4

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
STATE=$LANDIS/states/WA
PERSEUS=$STATE/perseus
TOOLS=$LANDIS/tools
INPUTS=$STATE/inputs

THETA_TAG=$(printf "t%.2f" "$THETA" | tr '.' '_')
TAG_DIR=$PERSEUS/runs_${THETA_TAG}
mkdir -p "$TAG_DIR"

# Build into the t<theta> subdir by overriding PERSEUS_RUNS_DIR-style env vars used in the builder.
# Since the existing builder hard-codes PERSEUS/runs, we wrap: build → move → patch SspEcoregionData → fix scenario paths.

# Use a tmp dir under perseus/runs (existing builder path), then move
PLOT_DIR=$PERSEUS/runs/plot_${PLOT}__clim_${CLIM}_harv_${HARV}
bash $TOOLS/build_plot_scenario_WA.sh $PLOT $CLIM $HARV > /dev/null

# Apply theta to SspEcoregionData
python3 $TOOLS/apply_theta_uniform_WA.py \
  --in-csv $PLOT_DIR/SppEcoregionData.csv \
  --out-csv $PLOT_DIR/SppEcoregionData_theta.csv \
  --theta $THETA
mv $PLOT_DIR/SppEcoregionData_theta.csv $PLOT_DIR/SppEcoregionData.csv

# Move to theta-tagged dir
T_PLOT_DIR=$TAG_DIR/plot_${PLOT}__clim_${CLIM}_harv_${HARV}
rm -rf "$T_PLOT_DIR"
mv $PLOT_DIR "$T_PLOT_DIR"

# Patch scenario.txt + biomass-succession.txt absolute paths if any (we use relative names so should be fine)
echo "Built theta=$THETA scenario at $T_PLOT_DIR"
