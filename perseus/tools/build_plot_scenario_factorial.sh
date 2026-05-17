#!/bin/bash
# build_plot_scenario_factorial.sh
# Unified PERSEUS scenario builder for the climate × harvest × disturbance factorial.
#
# Usage:
#   bash build_plot_scenario_factorial.sh <STATE> <PLOT> <CLIM> <HARV> <DIST>
#
# STATE:    ME | GA | WA
# CLIM:     baseline | ssp245 | ssp585
# HARV:     none | baseline | perseus | intensified
# DIST:     none | wind | fire | bda | bda+wind | bda+fire | hurricane | hurricane+bda
#
# Wraps the per-state single-plot builders + adds disturbance extensions.

set -euo pipefail

if [ "$#" -lt 5 ]; then
  echo "Usage: $0 <STATE> <PLOT> <CLIM> <HARV> <DIST>"
  exit 1
fi

STATE=$1; PLOT=$2; CLIM=$3; HARV=$4; DIST=$5

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
TOOLS=$LANDIS/tools

# Per-state config
case "$STATE" in
  ME)
    # Maine uses existing build_plot_scenario.sh (ME-specific)
    BUILDER=$TOOLS/build_plot_scenario.sh
    BDA_AGENT=$TOOLS/Climate-BDA_Agent_SBW.txt
    BDA_SETUP=$TOOLS/Climate-BDA_SetUp_SBW.txt
    ;;
  GA)
    # Georgia — use t1 template approach (plot_1 baseline as template)
    BUILDER=$TOOLS/run_param_set_GA_t0.sh
    BDA_AGENT=$TOOLS/Climate-BDA_Agent_SPB.txt
    BDA_SETUP=$TOOLS/Climate-BDA_SetUp_SPB.txt
    ;;
  WA)
    BUILDER=$TOOLS/build_plot_scenario_WA.sh
    BDA_AGENT=$TOOLS/Climate-BDA_Agent_MPB.txt
    BDA_SETUP=$TOOLS/Climate-BDA_SetUp_MPB.txt
    ;;
  *)
    echo "ERROR: unknown STATE $STATE"; exit 2 ;;
esac

# Build the base scenario using the per-state single-plot builder.
# This assumes the per-state builder supports the requested (CLIM, HARV) combo.
case "$STATE" in
  WA)
    bash $BUILDER $PLOT $CLIM $HARV > /dev/null
    PLOT_DIR=$LANDIS/states/WA/perseus/runs/plot_${PLOT}__clim_${CLIM}_harv_${HARV}
    ;;
  ME|GA)
    bash $BUILDER $PLOT $CLIM $HARV > /dev/null
    PLOT_DIR=$LANDIS/states/${STATE}/perseus/runs/plot_${PLOT}__clim_${CLIM}_harv_${HARV}
    ;;
esac

if [ ! -d "$PLOT_DIR" ]; then
  echo "ERROR: base scenario builder did not produce $PLOT_DIR"
  exit 3
fi

# Tag the dir with the disturbance suffix
TAG_DIR=${PLOT_DIR}__dist_${DIST}
if [ "$TAG_DIR" != "$PLOT_DIR" ]; then
  rm -rf $TAG_DIR
  cp -r $PLOT_DIR $TAG_DIR
fi
PLOT_DIR=$TAG_DIR

# Add disturbance extensions to scenario.txt
DIST_LINES=""
case "$DIST" in
  none)
    DIST_LINES=""
    ;;
  wind)
    # Build single-ecoregion base-wind.txt
    if [ "$STATE" = "WA" ]; then
      # Use plot's actual ecoregion from declarations
      ECO=$(awk '/^>>Active/{next} /^yes/{print $2}' $PLOT_DIR/ecoregions.txt | head -1)
    else
      ECO=$(awk '/^>>Active/{next} /^yes/{print $2}' $PLOT_DIR/ecoregions.txt | head -1)
    fi
    cat > $PLOT_DIR/base-wind.txt <<EOF
LandisData "Original Wind"
Timestep    5
>> Ecoregion  Max  Mean  Min  Rotation
    $ECO     500   50    1   1000
WindSeverities
   5    0% to  20%   0.05
   4   20% to  50%   0.10
   3   50% to  70%   0.50
   2   70% to  85%   0.85
   1   85% to 100%   0.95
MapNames        output/wind/severity-{timestep}.tif
SummaryLogFile  output/wind/wind-summary-log.csv
EventLogFile    output/wind/wind-events-log.csv
EOF
    mkdir -p $PLOT_DIR/output/wind
    DIST_LINES='"Original Wind"        base-wind.txt'
    ;;
  fire)
    # Build single-region base-fire.txt + Spp_Table from SpeciesData
    ECO=$(awk '/^>>Active/{next} /^yes/{print $2}' $PLOT_DIR/ecoregions.txt | head -1)
    awk -F',' 'NR==1{for(i=1;i<=NF;i++) if($i=="FireTolerance") c=i} NR>1{print $1","$c}' $PLOT_DIR/SpeciesData.csv > $PLOT_DIR/OriginalFire_Spp_Table.csv
    sed -i '1i SpeciesCode,FireTolerance' $PLOT_DIR/OriginalFire_Spp_Table.csv
    cat > $PLOT_DIR/base-fire.txt <<EOF
LandisData "Original Fire"
Timestep  5
Species_CSV_File ./OriginalFire_Spp_Table.csv
>> Region   Code   Mean  Min  Max  Prob  k
   eco_$ECO  $ECO    100    4   400  0.001  100
InitialFireRegionsMap   ./fire-regions.tif
  FuelCurveTable
  eco_$ECO  10  20  50  70  120
  WindCurveTable
  eco_$ECO  -1  -1   1  10  20
  FireDamageTable
     20%   -2
     50%   -1
     85%    0
    100%    1
MapNames        output/fire/severity-{timestep}.tif
LogFile         output/fire/fire-log.csv
SummaryLogFile  output/fire/fire-summary-log.csv
EOF
    # 1×1 fire-regions tif (value=ECO)
    apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 $LANDIS/images/landis-ii_v8_allext_v1.0.sif python3 -c "
from osgeo import gdal
import numpy as np
ds = gdal.GetDriverByName('GTiff').Create('$PLOT_DIR/fire-regions.tif', 1, 1, 1, gdal.GDT_Int32, options=['COMPRESS=DEFLATE'])
ds.GetRasterBand(1).WriteArray(np.array([[$ECO]], dtype=np.int32))
ds.GetRasterBand(1).SetNoDataValue(0)
ds.SetGeoTransform([0.0, 30.0, 0.0, 30.0, 0.0, -30.0])
ds = None
" 2>/dev/null
    mkdir -p $PLOT_DIR/output/fire
    DIST_LINES='"Original Fire"        base-fire.txt'
    ;;
  bda)
    cp $BDA_SETUP $PLOT_DIR/
    cp $BDA_AGENT $PLOT_DIR/
    mkdir -p $PLOT_DIR/output/climateBda
    SETUP_BN=$(basename $BDA_SETUP)
    DIST_LINES="\"Climate BDA\"          $SETUP_BN"
    ;;
  bda+wind)
    cp $BDA_SETUP $PLOT_DIR/
    cp $BDA_AGENT $PLOT_DIR/
    mkdir -p $PLOT_DIR/output/climateBda $PLOT_DIR/output/wind
    ECO=$(awk '/^>>Active/{next} /^yes/{print $2}' $PLOT_DIR/ecoregions.txt | head -1)
    cat > $PLOT_DIR/base-wind.txt <<EOF
LandisData "Original Wind"
Timestep    5
>> Ecoregion  Max  Mean  Min  Rotation
    $ECO     500   50    1   1000
WindSeverities
   5    0% to  20%   0.05
   4   20% to  50%   0.10
   3   50% to  70%   0.50
   2   70% to  85%   0.85
   1   85% to 100%   0.95
MapNames        output/wind/severity-{timestep}.tif
SummaryLogFile  output/wind/wind-summary-log.csv
EventLogFile    output/wind/wind-events-log.csv
EOF
    SETUP_BN=$(basename $BDA_SETUP)
    DIST_LINES='"Original Wind"        base-wind.txt
"Climate BDA"          '"$SETUP_BN"
    ;;
  bda+fire)
    cp $BDA_SETUP $PLOT_DIR/
    cp $BDA_AGENT $PLOT_DIR/
    mkdir -p $PLOT_DIR/output/climateBda $PLOT_DIR/output/fire
    ECO=$(awk '/^>>Active/{next} /^yes/{print $2}' $PLOT_DIR/ecoregions.txt | head -1)
    awk -F',' 'NR==1{for(i=1;i<=NF;i++) if($i=="FireTolerance") c=i} NR>1{print $1","$c}' $PLOT_DIR/SpeciesData.csv > $PLOT_DIR/OriginalFire_Spp_Table.csv
    sed -i '1i SpeciesCode,FireTolerance' $PLOT_DIR/OriginalFire_Spp_Table.csv
    cat > $PLOT_DIR/base-fire.txt <<EOF
LandisData "Original Fire"
Timestep  5
Species_CSV_File ./OriginalFire_Spp_Table.csv
>> Region   Code   Mean  Min  Max  Prob  k
   eco_$ECO  $ECO    100    4   400  0.001  100
InitialFireRegionsMap   ./fire-regions.tif
  FuelCurveTable
  eco_$ECO  10  20  50  70  120
  WindCurveTable
  eco_$ECO  -1  -1   1  10  20
  FireDamageTable
     20%   -2
     50%   -1
     85%    0
    100%    1
MapNames        output/fire/severity-{timestep}.tif
LogFile         output/fire/fire-log.csv
SummaryLogFile  output/fire/fire-summary-log.csv
EOF
    apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 $LANDIS/images/landis-ii_v8_allext_v1.0.sif python3 -c "
from osgeo import gdal
import numpy as np
ds = gdal.GetDriverByName('GTiff').Create('$PLOT_DIR/fire-regions.tif', 1, 1, 1, gdal.GDT_Int32, options=['COMPRESS=DEFLATE'])
ds.GetRasterBand(1).WriteArray(np.array([[$ECO]], dtype=np.int32))
ds.GetRasterBand(1).SetNoDataValue(0)
ds.SetGeoTransform([0.0, 30.0, 0.0, 30.0, 0.0, -30.0])
ds = None
" 2>/dev/null
    SETUP_BN=$(basename $BDA_SETUP)
    DIST_LINES='"Original Fire"        base-fire.txt
"Climate BDA"          '"$SETUP_BN"
    ;;
  hurricane)
    # Hurricane v3 (GA-specific). Requires Int32 exposure tifs at 135°/180°/225°
    # and the EvennessWindReductions CSV. Per-plot exposure value=1 (full exposure)
    # for single-cell scenarios; landscape-scale runs would use real exposure maps.
    if [ "$STATE" != "GA" ]; then
      echo "WARNING: hurricane disturbance only validated for GA; building anyway"
    fi
    cp $TOOLS/Hurricane_GA.txt $PLOT_DIR/
    cp $TOOLS/EvennessWindReductions_GA.csv $PLOT_DIR/
    # Build the 3 Int32 single-cell exposure tifs (1 = full exposure)
    apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
      $LANDIS/images/landis-ii_v8_allext_v1.0.sif python3 - <<PY 2>/dev/null
from osgeo import gdal
import numpy as np
for deg in [135, 180, 225]:
    ds = gdal.GetDriverByName('GTiff').Create(
        '$PLOT_DIR/Hurricane_exposure_' + str(deg) + '_GA.tif', 1, 1, 1, gdal.GDT_Int32,
        options=['COMPRESS=DEFLATE'])
    ds.GetRasterBand(1).WriteArray(np.array([[1]], dtype=np.int32))
    ds.SetGeoTransform([0.0, 30.0, 0.0, 30.0, 0.0, -30.0])
    ds = None
PY
    mkdir -p $PLOT_DIR/output/hurricane
    DIST_LINES='"Hurricane"            Hurricane_GA.txt'
    ;;
  hurricane+bda)
    # Hurricane + Climate BDA combined (GA factorial cell)
    cp $TOOLS/Hurricane_GA.txt $PLOT_DIR/
    cp $TOOLS/EvennessWindReductions_GA.csv $PLOT_DIR/
    cp $BDA_SETUP $PLOT_DIR/
    cp $BDA_AGENT $PLOT_DIR/
    apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
      $LANDIS/images/landis-ii_v8_allext_v1.0.sif python3 - <<PY 2>/dev/null
from osgeo import gdal
import numpy as np
for deg in [135, 180, 225]:
    ds = gdal.GetDriverByName('GTiff').Create(
        '$PLOT_DIR/Hurricane_exposure_' + str(deg) + '_GA.tif', 1, 1, 1, gdal.GDT_Int32,
        options=['COMPRESS=DEFLATE'])
    ds.GetRasterBand(1).WriteArray(np.array([[1]], dtype=np.int32))
    ds.SetGeoTransform([0.0, 30.0, 0.0, 30.0, 0.0, -30.0])
    ds = None
PY
    mkdir -p $PLOT_DIR/output/hurricane $PLOT_DIR/output/climateBda
    SETUP_BN=$(basename $BDA_SETUP)
    DIST_LINES='"Hurricane"            Hurricane_GA.txt
"Climate BDA"          '"$SETUP_BN"
    ;;
  *)
    echo "ERROR: unknown DIST $DIST"; exit 4 ;;
esac

# Inject disturbance lines into scenario.txt before "Output Biomass"
if [ -n "$DIST_LINES" ]; then
  # Build new scenario.txt with disturbance lines inserted
  python3 - <<PY
with open("$PLOT_DIR/scenario.txt") as f:
    lines = f.readlines()
out = []
for line in lines:
    if '"Output Biomass"' in line:
        for d in """$DIST_LINES""".strip().split("\n"):
            out.append(d + "\n")
    out.append(line)
with open("$PLOT_DIR/scenario.txt", "w") as f:
    f.writelines(out)
PY
fi

echo "Built factorial cell at $PLOT_DIR"
echo "  state=$STATE plot=$PLOT clim=$CLIM harv=$HARV dist=$DIST"
