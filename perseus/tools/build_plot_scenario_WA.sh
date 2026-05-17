#!/bin/bash
# build_plot_scenario_WA.sh
#
# Build a single-plot LANDIS-II scenario directory for a WA PERSEUS plot.
# Each plot becomes a 1-cell landscape with the FIA-derived IC AND with
# scenario files restricted to a single ecoregion (the plot's actual L3
# ecoregion) so LANDIS validation does not stall on unbacked ecoregions.
#
# Usage:
#   bash build_plot_scenario_WA.sh <PLOT_ID> <climate> <harvest>
#   bash build_plot_scenario_WA.sh 1 baseline none
#
# Climates: baseline (more later)
# Harvests: none | perseus

set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: bash build_plot_scenario_WA.sh <PLOT_ID> <baseline> <none|perseus>"
  exit 1
fi

PLOT=$1
CLIM=$2
HARV=$3

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
STATE=$LANDIS/states/WA
INPUTS=$STATE/inputs
ICS=$STATE/perseus/plot_ics_full
RUNS=$STATE/perseus/runs
TOOLS=$LANDIS/tools
PATCH=$LANDIS/patches
SIF=$LANDIS/images/landis-ii_v8_allext_v1.0.sif
PLOT_ECO_CSV=$TOOLS/plot_to_ecoregion_WA.csv
CLIM_BASELINE=$STATE/runs/factorial_landowner/WA_own_ind_clim_baseline_harv_baseline/climate.csv

PLOT_DIR=$RUNS/plot_${PLOT}__clim_${CLIM}_harv_${HARV}
IC_SOURCE=$ICS/plot_${PLOT}/initial_communities.csv

if [ ! -f "$IC_SOURCE" ]; then
  echo "ERROR: missing IC csv at $IC_SOURCE"; exit 2
fi
if [ ! -f "$PLOT_ECO_CSV" ]; then
  echo "ERROR: missing $PLOT_ECO_CSV"; exit 3
fi

# Lookup ecoregion. Eco 3 (Willamette Valley) → 2 (Puget Lowland) as nearest
# Eco 15 (Northern Rockies) → 11 (Blue Mountains) as nearest
# Eco 0 (nodata) → skip
RAW_ECO=$(awk -F',' -v p="$PLOT" 'NR>1 && $1==p {print $3}' "$PLOT_ECO_CSV" | tr -d '\r\n ')
if [ -z "$RAW_ECO" ]; then
  echo "ERROR: plot $PLOT not in $PLOT_ECO_CSV"; exit 4
fi
case "$RAW_ECO" in
  0)   echo "SKIP: plot $PLOT is in eco 0 (nodata)"; exit 5;;
  3)   ECO=2;  ECO_NAME='"Willamette Valley (mapped to Puget Lowland)"' ;;
  15)  ECO=11; ECO_NAME='"Northern Rockies (mapped to Blue Mountains)"' ;;
  1)   ECO=1;  ECO_NAME='"Coast Range"' ;;
  2)   ECO=2;  ECO_NAME='"Puget Lowland"' ;;
  4)   ECO=4;  ECO_NAME='"Cascades"' ;;
  9)   ECO=9;  ECO_NAME='"Eastern Cascades Slopes and Foothills"' ;;
  10)  ECO=10; ECO_NAME='"Columbia Plateau"' ;;
  11)  ECO=11; ECO_NAME='"Blue Mountains"' ;;
  77)  ECO=77; ECO_NAME='"North Cascades"' ;;
  *)   echo "ERROR: unknown eco $RAW_ECO for plot $PLOT"; exit 6 ;;
esac

mkdir -p "$PLOT_DIR"

# 1. IC csv (rename column header from CohortAge so v8 accepts it)
cp "$IC_SOURCE" "$PLOT_DIR/initial-communities.csv"

# 2. Single-ecoregion ecoregions.txt
cat > "$PLOT_DIR/ecoregions.txt" <<EOF
LandisData "Ecoregions"
>>Active	MapCode	Name	Description
no	0	nodata	"non-forest"
yes	$ECO	$ECO	$ECO_NAME
EOF

# 3. 1×1 ecoregion raster
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 $SIF python3 - <<PY
from osgeo import gdal
import numpy as np
ds = gdal.GetDriverByName('GTiff').Create('$PLOT_DIR/ecoregions.tif', 1, 1, 1, gdal.GDT_Int32, options=['COMPRESS=DEFLATE'])
ds.GetRasterBand(1).WriteArray(np.array([[$ECO]], dtype=np.int32))
ds.GetRasterBand(1).SetNoDataValue(0)
ds.SetGeoTransform([0.0, 30.0, 0.0, 30.0, 0.0, -30.0])
ds = None
ds = gdal.GetDriverByName('GTiff').Create('$PLOT_DIR/initial-communities.tif', 1, 1, 1, gdal.GDT_Int32, options=['COMPRESS=DEFLATE'])
ds.GetRasterBand(1).WriteArray(np.array([[1]], dtype=np.int32))
ds.GetRasterBand(1).SetNoDataValue(0)
ds.SetGeoTransform([0.0, 30.0, 0.0, 30.0, 0.0, -30.0])
ds = None
PY

# 4. species + speciesData symlinks (full 25-species WA list)
ln -sf $INPUTS/species.txt        "$PLOT_DIR/species.txt"
ln -sf $INPUTS/SpeciesData.csv    "$PLOT_DIR/SpeciesData.csv"

# 5. SppEcoregionData filtered to this ECO only
head -1 $INPUTS/SppEcoregionData.csv > "$PLOT_DIR/SppEcoregionData.csv"
awk -F',' -v e="$ECO" 'NR>1 && $2==e' $INPUTS/SppEcoregionData.csv >> "$PLOT_DIR/SppEcoregionData.csv"

# 6. climate.csv filtered to this ECO only (Year, Month, Variable, <ECO>)
awk -F',' -v e="$ECO" 'BEGIN{OFS=","}
  NR==1 {
    for(i=1;i<=NF;i++) if($i==e) c=i;
    if(c==0){print "ERR: eco "e" not in climate.csv" > "/dev/stderr"; exit 1}
    print $1,$2,$3,$c; next
  }
  {print $1,$2,$3,$c}
' $CLIM_BASELINE > "$PLOT_DIR/climate.csv"

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

# 8. output-biomass.txt — all 25 WA species
cat > "$PLOT_DIR/output-biomass.txt" <<EOF
LandisData  "Output Biomass"
Timestep   5
MakeTable  yes
Species  DF
         WH
         WC
         PSF
         GF
         NF
         SS
         ES
         AF
         WF
         LP
         PP
         WP
         WBP
         MH
         WL
         IC
         PY
         BM
         RA
         PM
         PB
         QA
         BCW
         GO
MapNames   output/biomass/biomass-{species}-{timestep}.tif
DeadPools  both
MapNames   output/biomass/biomass-{pool}-{timestep}.tif
EOF

# 9. Optional harvest extension
SCEN_HARV=""
if [ "$HARV" = "perseus" ]; then
  SCEN_HARV='"Biomass Harvest" biomass-harvest.txt'
  apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 $SIF python3 - <<PY
from osgeo import gdal
import numpy as np
for n in ('management-area.tif','stands.tif'):
    ds = gdal.GetDriverByName('GTiff').Create('$PLOT_DIR/'+n, 1, 1, 1, gdal.GDT_Int32, options=['COMPRESS=DEFLATE'])
    ds.GetRasterBand(1).WriteArray(np.array([[1]], dtype=np.int32))
    ds.GetRasterBand(1).SetNoDataValue(0)
    ds.SetGeoTransform([0.0, 30.0, 0.0, 30.0, 0.0, -30.0])
    ds = None
PY
  cat > "$PLOT_DIR/biomass-harvest.txt" <<HARV_EOF
LandisData  "Biomass Harvest"

Timestep    5

ManagementAreas  ./management-area.tif
Stands           ./stands.tif

Prescription PerseusBA50
    StandRanking     Random
    MinimumAge       5
    SiteSelection    Complete
    CohortsRemoved   SpeciesList
        DF    1-1000(50%)
        WH    1-500(50%)
        WC    1-1500(50%)
        PSF   1-400(50%)
        GF    1-300(50%)
        NF    1-500(50%)
        SS    1-700(50%)
        ES    1-500(50%)
        AF    1-250(50%)
        WF    1-350(50%)
        LP    1-300(50%)
        PP    1-600(50%)
        WP    1-500(50%)
        WBP   1-400(50%)
        MH    1-500(50%)
        WL    1-700(50%)
        IC    1-500(50%)
        PY    1-300(50%)
        BM    1-250(50%)
        RA    1-100(50%)
        PM    1-400(50%)
        PB    1-150(50%)
        QA    1-150(50%)
        BCW   1-200(50%)
        GO    1-500(50%)

HarvestImplementations
>>  MgmtArea  Prescription      HarvestArea     BeginTime  EndTime
    1         PerseusBA50       2%              0          100

PrescriptionMaps    output/harvest/biomass-harvest-{timestep}.tif
BiomassMaps         output/harvest/biomass-harvest-biomass-{timestep}.tif
EventLog            output/harvest/harvest-event-log.csv
SummaryLog          output/harvest/harvest-summary-log.csv
HARV_EOF
fi

# 10. scenario.txt
cat > "$PLOT_DIR/scenario.txt" <<EOF
LandisData  Scenario

Duration   100
Species    species.txt
Ecoregions ecoregions.txt
EcoregionsMap ecoregions.tif
CellLength    30

"Biomass Succession"   biomass-succession.txt
${SCEN_HARV}
"Output Biomass"       output-biomass.txt

RandomNumberSeed   42
EOF

# 11. job.slurm with patched DLL bind mounts
PATCH_BIND="--bind $PATCH/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll"
[ -f $PATCH/Landis.Utilities.dll ] && PATCH_BIND="$PATCH_BIND --bind $PATCH/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll"

cat > "$PLOT_DIR/job.slurm" <<SLURM
#!/bin/bash
#SBATCH --job-name=wa_${PLOT}_${CLIM:0:3}_${HARV:0:1}
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH --output=$PLOT_DIR/job.out
#SBATCH --error=$PLOT_DIR/job.err

cd $PLOT_DIR
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  $PATCH_BIND \\
  --bind $PLOT_DIR:$PLOT_DIR --pwd $PLOT_DIR \\
  $SIF \\
  dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt
SLURM

mkdir -p "$PLOT_DIR/output/biomass" "$PLOT_DIR/output/harvest"

echo "Built scenario at $PLOT_DIR (eco $ECO from raw $RAW_ECO)"
echo "Submit with: sbatch $PLOT_DIR/job.slurm"
