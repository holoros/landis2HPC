#!/bin/bash
# build_plot_scenario_MN.sh
#
# Build a single-plot LANDIS-II scenario directory for an MN PERSEUS plot.
# 1-cell landscape with FIA-derived IC, restricted to the plot's L3 ecoregion.
# Adapted from build_plot_scenario_WA.sh for Minnesota (24 species, eco 46-52,
# long-format climate.csv: Year,Month,EcoregionId,tmin,tmax,precip).
#
# Usage: bash build_plot_scenario_MN.sh <PLOT_ID> <baseline> <none|perseus>

set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: bash build_plot_scenario_MN.sh <PLOT_ID> <baseline> <none|perseus>"
  exit 1
fi

PLOT=$1; CLIM=$2; HARV=$3

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
STATE=$LANDIS/states/MI
INPUTS=$LANDIS/states/MN/inputs
ICS=$STATE/perseus/plot_ics_full
RUNS=$STATE/perseus/runs
TOOLS=$LANDIS/tools
PATCH=$LANDIS/patches
SIF=$LANDIS/images/landis-ii_v8_allext_v1.0.sif
PLOT_ECO_CSV=$TOOLS/plot_to_ecoregion_MI.csv
# A working MN factorial run provides a long-format climate.csv template
CLIM_BASELINE=$LANDIS/states/MN/runs/factorial_landowner/MN_own_nipf_clim_ssp585_harv_none/climate.csv

PLOT_DIR=$RUNS/plot_${PLOT}__clim_${CLIM}_harv_${HARV}
IC_SOURCE=$ICS/plot_${PLOT}/initial_communities.csv

if [ ! -f "$IC_SOURCE" ]; then echo "ERROR: missing IC csv at $IC_SOURCE"; exit 2; fi
if [ ! -f "$PLOT_ECO_CSV" ]; then echo "ERROR: missing $PLOT_ECO_CSV"; exit 3; fi

RAW_ECO=$(awk -F',' -v p="$PLOT" 'NR>1 && $1==p {print $3}' "$PLOT_ECO_CSV" | tr -d '\r\n ')
if [ -z "$RAW_ECO" ]; then echo "ERROR: plot $PLOT not in $PLOT_ECO_CSV"; exit 4; fi
# MN EPA L3 ecoregions present in the FIA sample: 46-52
case "$RAW_ECO" in
  46) ECO=46; ECO_NAME='"Northern Glaciated Plains"' ;;
  47) ECO=47; ECO_NAME='"Western Corn Belt Plains"' ;;
  48) ECO=48; ECO_NAME='"Lake Agassiz Plain"' ;;
  49) ECO=49; ECO_NAME='"Northern Minnesota Wetlands"' ;;
  50) ECO=50; ECO_NAME='"Northern Lakes and Forests"' ;;
  51) ECO=51; ECO_NAME='"North Central Hardwood Forests"' ;;
  52) ECO=52; ECO_NAME='"Driftless Area"' ;;
  0)  echo "SKIP: plot $PLOT is in eco 0 (nodata)"; exit 5 ;;
  *)  echo "ERROR: unknown eco $RAW_ECO for plot $PLOT"; exit 6 ;;
esac

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

# 4. species + SpeciesData symlinks (full 24-species MN list)
ln -sf $INPUTS/species.txt        "$PLOT_DIR/species.txt"
ln -sf $INPUTS/SpeciesData.csv    "$PLOT_DIR/SpeciesData.csv"

# 5. SppEcoregionData filtered to this ECO
head -1 $INPUTS/SppEcoregionData.csv > "$PLOT_DIR/SppEcoregionData.csv"
awk -F',' -v e="$ECO" 'NR>1 && $2==e' $INPUTS/SppEcoregionData.csv >> "$PLOT_DIR/SppEcoregionData.csv"

# 6. climate.csv: transpose MN long format (Year,Month,EcoregionId,tmin,tmax,precip)
#    to the LANDIS Climate Library Monthly format expected by Biomass Succession:
#    Year,Month,Variable,<ECO>  with Variable in {precip,mintemp,maxtemp}.
#    If the chosen eco has no rows in the template, borrow eco 50 (Northern Lakes
#    & Forests) climate as a nearest-neighbor.
SRC_ECO=$ECO
if ! awk -F',' -v e="$ECO" 'NR>1 && $3==e{f=1} END{exit !f}' "$CLIM_BASELINE"; then
  SRC_ECO=50
fi
awk -F',' -v e="$ECO" -v se="$SRC_ECO" 'BEGIN{OFS=","; print "Year","Month","Variable",e}
  NR>1 && $3==se {
    print $1,$2,"precip",$6
    print $1,$2,"mintemp",$4
    print $1,$2,"maxtemp",$5
  }' "$CLIM_BASELINE" > "$PLOT_DIR/climate.csv"

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
$ECO   550

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

# 8. output-biomass.txt — exact proven WA format (MakeTable yes; first species on the
#    Species line; DeadPools both + {pool} MapNames produces biomass-TotalBiomass tifs
#    that the per-plot aggregator reads).
cat > "$PLOT_DIR/output-biomass.txt" <<EOF
LandisData  "Output Biomass"
Timestep   5
MakeTable  yes
Species  BF
         TAM
         WS
         BS
         RS
         JP
         RP
         WP
         CE
         HE
         RM
         SM
         YB
         PB
         BE
         WAS
         BAS
         QA
         BA
         WO
         RO
         BO
         BSW
         AE
MapNames   output/biomass/biomass-{species}-{timestep}.tif
DeadPools  both
MapNames   output/biomass/biomass-{pool}-{timestep}.tif
EOF

# 9. scenario.txt (no harvest for calibration; duration 100)
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
echo "Built MN scenario at $PLOT_DIR (eco $ECO from raw $RAW_ECO)"
