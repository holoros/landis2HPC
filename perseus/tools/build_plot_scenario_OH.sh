#!/bin/bash
# build_plot_scenario_OH.sh
#
# Build a single-plot LANDIS-II scenario directory for an OH PERSEUS plot.
# 1-cell landscape with FIA-derived IC, restricted to the plot's EPA L3
# ecoregion. PRISM_OH_l3.csv is already in wide format (Year,Month,Variable,
# <eco_cols>) so the climate.csv is just a column subset.
#
# Usage: bash build_plot_scenario_OH.sh <PLOT_ID> <baseline> <none|perseus>

set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: bash build_plot_scenario_OH.sh <PLOT_ID> <baseline> <none|perseus>"
  exit 1
fi

PLOT=$1; CLIM=$2; HARV=$3

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
STATE=$LANDIS/states/OH
INPUTS=$STATE/inputs
ICS=$STATE/perseus/plot_ics_full
RUNS=$STATE/perseus/runs
TOOLS=$LANDIS/tools
PATCH=$LANDIS/patches
SIF=$LANDIS/images/landis-ii_v8_allext_v1.0.sif
PLOT_ECO_CSV=$TOOLS/plot_to_ecoregion_OH.csv
PRISM_WIDE=$INPUTS/PRISM_OH_l3.csv

PLOT_DIR=$RUNS/plot_${PLOT}__clim_${CLIM}_harv_${HARV}
IC_SOURCE=$ICS/plot_${PLOT}/initial_communities.csv

if [ ! -f "$IC_SOURCE" ]; then echo "ERROR: missing IC csv at $IC_SOURCE"; exit 2; fi
if [ ! -f "$PLOT_ECO_CSV" ]; then echo "ERROR: missing $PLOT_ECO_CSV"; exit 3; fi
if [ ! -f "$PRISM_WIDE" ]; then echo "ERROR: missing $PRISM_WIDE"; exit 4; fi

RAW_ECO=$(awk -F',' -v p="$PLOT" 'NR>1 && $1==p && $3+0>0 {print $3; exit}' "$PLOT_ECO_CSV" | tr -d '\r\n ')
if [ -z "$RAW_ECO" ]; then echo "ERROR: plot $PLOT not in $PLOT_ECO_CSV"; exit 5; fi
# OH EPA L3 ecoregions present in the FIA sample: 55, 57, 61, 70, 71, 83
case "$RAW_ECO" in
  55) ECO=55; ECO_NAME='"Eastern Corn Belt Plains"' ;;
  57) ECO=57; ECO_NAME='"Huron/Erie Lake Plains"' ;;
  61) ECO=61; ECO_NAME='"Erie Drift Plain"' ;;
  70) ECO=70; ECO_NAME='"Western Allegheny Plateau"' ;;
  71) ECO=71; ECO_NAME='"Interior Plateau"' ;;
  83) ECO=83; ECO_NAME='"Eastern Great Lakes Lowlands"' ;;
  0)  echo "SKIP: plot $PLOT is in eco 0 (nodata)"; exit 6 ;;
  *)  echo "ERROR: unknown eco $RAW_ECO for plot $PLOT"; exit 7 ;;
esac

# Verify the eco has a column in PRISM_WIDE
HEADER=$(head -1 "$PRISM_WIDE" | tr -d '\r')   # strip CR: PRISM_*_l3.csv may be CRLF
if ! echo "$HEADER" | tr ',' '\n' | grep -qx "$ECO"; then
  echo "ERROR: eco $ECO not in $PRISM_WIDE header ($HEADER)"; exit 8
fi
# Find the column index of $ECO in PRISM_WIDE (1-based)
ECO_COL=$(echo "$HEADER" | awk -F',' -v e="$ECO" '{for(i=1;i<=NF;i++) if($i==e) {print i; exit}}')

mkdir -p "$PLOT_DIR"

# 1. IC csv
cp "$IC_SOURCE" "$PLOT_DIR/initial-communities.csv"

# 2. Single-ecoregion ecoregions.txt
cat > "$PLOT_DIR/ecoregions.txt" <<EOF
LandisData "Ecoregions"
>>Active	MapCode	Name	Description
no	0	nodata	"non-forest"
yes	$ECO	$ECO	$ECO_NAME
EOF

# 3. 1x1 ecoregion + IC rasters
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 $SIF python3 - <<PY
from osgeo import gdal
import numpy as np
ds = gdal.GetDriverByName('GTiff').Create('$PLOT_DIR/ecoregions.tif', 1, 1, 1, gdal.GDT_Int32, options=['COMPRESS=DEFLATE'])
ds.GetRasterBand(1).WriteArray(np.array([[$ECO]], dtype=np.int32))
ds.GetRasterBand(1).SetNoDataValue(0)
ds.SetGeoTransform([0.0, 30.0, 0.0, 30.0, 0.0, -30.0]); ds = None
ds = gdal.GetDriverByName('GTiff').Create('$PLOT_DIR/initial-communities.tif', 1, 1, 1, gdal.GDT_Int32, options=['COMPRESS=DEFLATE'])
ds.GetRasterBand(1).WriteArray(np.array([[1]], dtype=np.int32))
ds.GetRasterBand(1).SetNoDataValue(0)
ds.SetGeoTransform([0.0, 30.0, 0.0, 30.0, 0.0, -30.0]); ds = None
PY

# 4. species + SpeciesData symlinks
ln -sf $INPUTS/species.txt        "$PLOT_DIR/species.txt"
ln -sf $INPUTS/SpeciesData.csv    "$PLOT_DIR/SpeciesData.csv"

# 5. SppEcoregionData filtered to this ECO
head -1 $INPUTS/SppEcoregionData.csv > "$PLOT_DIR/SppEcoregionData.csv"
awk -F',' -v e="$ECO" 'NR>1 && $2==e' $INPUTS/SppEcoregionData.csv >> "$PLOT_DIR/SppEcoregionData.csv"

# 6. climate.csv: extract the ECO column from PRISM_WIDE
#    Header: Year,Month,Variable,<ECO>
#    Body:   <year>,<month>,<variable>,<value at ECO_COL>
awk -F',' -v c="$ECO_COL" -v e="$ECO" 'BEGIN{OFS=","; print "Year","Month","Variable",e}
  NR>1 {print $1,$2,$3,$c}' <(tr -d '\r' < "$PRISM_WIDE") > "$PLOT_DIR/climate.csv"

# climate-generator.txt
cat > "$PLOT_DIR/climate-generator.txt" <<EOF
LandisData "Climate Config"
ClimateTimeSeries          Monthly_AverageAllYears
ClimateFile                climate.csv
SpinUpClimateTimeSeries    Monthly_AverageAllYears
SpinUpClimateFile          climate.csv
GenerateClimateOutputFiles yes
UsingFireClimate           no
EOF

# 7. biomass-succession.txt restricted to single ECO
cat > "$PLOT_DIR/biomass-succession.txt" <<EOF
LandisData "Biomass Succession"

Timestep             5
SeedingAlgorithm     WardSeedDispersal
InitialCommunities       initial-communities.csv
InitialCommunitiesMap    initial-communities.tif
ClimateConfigFile        climate-generator.txt

MinRelativeBiomass
>> Shade  Percent Max Biomass per ecoregion
        $ECO
    1  20%
    2  40%
    3  60%
    4  80%
    5  100%

SufficientLight
>>  Spp Shade  Probability by Actual Shade
>>             0    1    2    3    4    5
    1   1.0  0.5  0.0  0.0  0.0  0.0
    2   1.0  1.0  0.5  0.0  0.0  0.0
    3   1.0  1.0  1.0  0.5  0.0  0.0
    4   1.0  1.0  1.0  1.0  0.5  0.0
    5   1.0  1.0  1.0  1.0  1.0  0.5

SpeciesDataFile        SpeciesData.csv

EcoregionParameters
>>  AET (mm)
$ECO   600

SpeciesEcoregionDataFile  SppEcoregionData.csv

FireReductionParameters
>>  Severity   WoodLitter   Litter
    1          0.0          0.5
    2          0.0          0.75
    3          0.5          1.0

HarvestReductionParameters
>>  Name             WoodLitter  Litter  Cohort_Wood  Cohort_Leaf
    PerseusBA50      0.5         0.15    0.5          0.0
EOF

# 8. output-biomass.txt — IN's 23 species list (matches SpeciesData.csv order)
cat > "$PLOT_DIR/output-biomass.txt" <<EOF
LandisData  "Output Biomass"
Timestep   5
MakeTable  yes
Species  WO
         NRO
         BO
         POST
         SHO
         SHA_HK
         MOK_HK
         SM
         RM
         YP
         BE
         WAS
         BAS
         BSW
         WALN
         SWEETGUM
         BLACKGUM
         SYC
         SASSAFRAS
         DOGWOOD
         EWP
         QA
         AE
MapNames   output/biomass/biomass-{species}-{timestep}.tif
DeadPools  both
MapNames   output/biomass/biomass-{pool}-{timestep}.tif
EOF

# 9. scenario.txt
cat > "$PLOT_DIR/scenario.txt" <<EOF
LandisData  Scenario

Duration   100
Species    species.txt
Ecoregions ecoregions.txt
EcoregionsMap ecoregions.tif
CellLength    30

"Biomass Succession"   biomass-succession.txt
"Output Biomass"       output-biomass.txt

RandomNumberSeed   42
EOF

mkdir -p "$PLOT_DIR/output/biomass"
echo "Built OH scenario at $PLOT_DIR (eco $ECO from raw $RAW_ECO, PRISM col $ECO_COL)"
