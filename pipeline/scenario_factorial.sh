#!/bin/bash
# scenario_factorial.sh
#
# Build a climate x harvest factorial of LANDIS-II scenarios for one state.
# Generates the run directory + SLURM submission for every cell of the factorial.
#
# Default factorial (12 scenarios per state):
#   Climate: baseline_PRISM | ssp245 | ssp585       (3 levels)
#   Harvest: none | baseline | increased | perseus  (4 levels)
#
# Each scenario directory contains:
#   - SpeciesData.csv               (state-specific calibrated)
#   - SppEcoregionData.csv          (climate-aware from PnET-II if non baseline)
#   - species.txt                   (state-specific calibrated)
#   - ecoregions.txt                (state-specific)
#   - initial-communities.tif       (state IC raster)
#   - biomass-succession.txt        (with state climate config)
#   - biomass-harvest.txt           (if harvest level != none)
#   - base-wind.txt                 (always: Lorimer & White wind regime)
#   - scenario.txt                  (top level wiring)
#   - landis_array.slurm            (SLURM submission script)
#
# Usage on Cardinal:
#   bash scenario_factorial.sh ME              # all 12 scenarios for Maine
#   bash scenario_factorial.sh WA              # all 12 for WA
#   bash scenario_factorial.sh ME --climate ssp245 --harvest perseus
#   bash scenario_factorial.sh ME --duration 100 --submit no   # dry run

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: bash scenario_factorial.sh <STATE> [--climate <c>] [--harvest <h>] [--duration N] [--submit yes|no]"
  echo "  STATE: ME | MN | GA | WA"
  echo "  --climate: baseline | ssp245 | ssp585 | all (default all)"
  echo "  --harvest: none | baseline | increased | perseus | all (default all)"
  echo "  --duration: simulation length in years (default 50)"
  echo "  --submit: actually sbatch (default yes)"
  exit 1
fi

ST=$1; shift
CLIMATE_LIST="all"
HARVEST_LIST="all"
DURATION=100
SUBMIT="yes"
GCM="HadGEM3-GC31-LL"

while [[ $# -gt 0 ]]; do
  case $1 in
    --climate)  CLIMATE_LIST=$2; shift 2 ;;
    --harvest)  HARVEST_LIST=$2; shift 2 ;;
    --duration) DURATION=$2; shift 2 ;;
    --submit)   SUBMIT=$2; shift 2 ;;
    --gcm)      GCM=$2; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
TOOLS=/users/PUOM0008/crsfaaron/landis2/scratch/tools
INPUTS=$LANDIS/states/$ST/inputs
FACT_DIR=$LANDIS/states/$ST/runs/factorial
mkdir -p "$FACT_DIR"

# Resolve "all" to the full level list
if [ "$CLIMATE_LIST" = "all" ]; then CLIMATE_LIST="baseline ssp245 ssp585"; fi
if [ "$HARVEST_LIST" = "all" ]; then HARVEST_LIST="none baseline increased perseus"; fi

# Harvest level -> rate + prescription
declare -A HARVEST_RATE=(
  [none]=0.000
  [baseline]=0.022       # S-L 2025 study-wide mean
  [increased]=0.035      # +60% PERSEUS factorial high
  [perseus]=0.022        # rate same as baseline but PerseusBA50 prescription
)
declare -A HARVEST_PRESCR=(
  [none]=none
  [baseline]=PartialHarvest
  [increased]=PartialHarvest
  [perseus]=PerseusBA50
)

##############################################################################
# Resolve baseline assets (must exist from Phase 1)
##############################################################################
for f in SpeciesData.csv SppEcoregionData.csv species.txt ecoregions.txt \
         initial-communities.tif; do
  if [ ! -f "$INPUTS/$f" ]; then
    echo "ERROR: missing $INPUTS/$f. Run state pipeline first."
    exit 2
  fi
done

##############################################################################
# Resolve the CALIBRATED production SppEcoregionData (Tier 2). Preferred over
# the literature Tier 0 sitting in inputs/. Without this the factorial silently
# runs uncalibrated parameters (e.g. WA Douglas-fir ANPPmax 1850 vs 430).
##############################################################################
CAL_SPP=""
if [ -f "$INPUTS/SppEcoregionData_calibrated.csv" ]; then
  CAL_SPP="$INPUTS/SppEcoregionData_calibrated.csv"
else
  CAL_SPP=$(ls "$LANDIS"/states/"$ST"/perseus/statewide/*_calibrated/SppEcoregionData_*_calibrated.csv 2>/dev/null | head -1 || true)
fi
if [ -n "$CAL_SPP" ]; then
  echo "Using CALIBRATED SppEcoregionData: $CAL_SPP"
else
  echo "WARNING: no calibrated SppEcoregionData for $ST; using literature Tier 0 in inputs/. RESULTS WILL BE UNCALIBRATED."
fi
BASE_SPP="${CAL_SPP:-$INPUTS/SppEcoregionData.csv}"

##############################################################################
# Build each scenario
##############################################################################
TOTAL_JOBS=0
SCENARIO_LOG=$FACT_DIR/factorial_log_$(date +%Y%m%d_%H%M).csv
echo "scenario,climate,harvest,run_dir,job_id,submitted_at" > "$SCENARIO_LOG"

for CLIM in $CLIMATE_LIST; do
  for HARV in $HARVEST_LIST; do
    SCENARIO="${ST}_clim_${CLIM}_harv_${HARV}"
    RUN=$FACT_DIR/$SCENARIO
    mkdir -p "$RUN/output"

    echo "==========================================================="
    echo "  $SCENARIO"
    echo "==========================================================="

    # ---- Stage baseline assets ----
    cp "$INPUTS/SpeciesData.csv"         "$RUN/SpeciesData.csv"
    cp "$INPUTS/species.txt"             "$RUN/species.txt"
    cp "$INPUTS/ecoregions.txt"          "$RUN/ecoregions.txt"
    cp "$INPUTS/initial-communities.tif" "$RUN/initial-communities.tif"
    # IC text file. Biomass Succession v7 (Universal Cohorts) REQUIRES the CSV
    # format "MapCode,SpeciesName,CohortAge,CohortBiomass". The legacy
    # LandisData "Initial Communities" age-list format (initial_communities.txt)
    # has no biomass column and SEGFAULTS the Universal parser during landscape
    # init, so we require a Universal-format statewide IC and fail loudly rather
    # than silently producing a crashing run.
    IC_SRC=""
    for cand in "$INPUTS/initial-communities.csv" "$INPUTS/initial-communities_universal.csv"; do
      if [ -f "$cand" ] && head -1 "$cand" | grep -qi "MapCode,SpeciesName"; then
        IC_SRC="$cand"; break
      fi
    done
    if [ -n "$IC_SRC" ]; then
      cp "$IC_SRC" "$RUN/initial-communities.csv"
    else
      echo "ERROR: no Universal-format statewide IC (MapCode,SpeciesName,CohortAge,CohortBiomass) in $INPUTS."
      echo "       The legacy initial_communities.txt is NOT compatible with Biomass Succession v7."
      echo "       Generate the statewide Universal IC before running the factorial (see handoff)."
      exit 4
    fi

    # ---- Climate aware SppEcoregionData ----
    if [ "$CLIM" = "baseline" ]; then
      cp "$BASE_SPP" "$RUN/SppEcoregionData.csv"
      CLIM_FILE="$INPUTS/PRISM_${ST}_l3.csv"
    else
      PNET_OUT=$LANDIS/states/$ST/pnet2/${GCM}_${CLIM}/SppEcoregionData_${ST}_${GCM}_${CLIM}.csv
      if [ -f "$PNET_OUT" ]; then
        cp "$PNET_OUT" "$RUN/SppEcoregionData.csv"
        CLIM_FILE=$LANDIS/states/$ST/pnet2/${GCM}_${CLIM}/CMIP6_${ST}_${GCM}_${CLIM}.csv
      else
        echo "  WARN: no PnET-II refined params for $CLIM (run run_pnet2_state.sh first)"
        echo "  Falling back to calibrated baseline SppEcoregionData for now"
        cp "$BASE_SPP" "$RUN/SppEcoregionData.csv"
        CLIM_FILE="$INPUTS/PRISM_${ST}_l3.csv"
      fi
    fi
    [ -f "$CLIM_FILE" ] && cp "$CLIM_FILE" "$RUN/climate.csv"

    # ---- biomass succession config ----
    cat > "$RUN/biomass-succession.txt" <<BSX
LandisData "Biomass Succession"

Timestep             5
SeedingAlgorithm     WardSeedDispersal
InitialCommunities       initial-communities.csv
InitialCommunitiesMap    initial-communities.tif
ClimateConfigFile        climate-generator.txt

MinRelativeBiomass
>>  Shade   Eco_all
    Class
    1       0.20
    2       0.40
    3       0.60
    4       0.80
    5       1.00

SufficientLight
>>  Shade   ProbEstablish (1..5)
    1       1.0   0.5   0.0   0.0   0.0
    2       1.0   1.0   0.5   0.0   0.0
    3       1.0   1.0   1.0   0.5   0.0
    4       1.0   1.0   1.0   1.0   0.5
    5       1.0   1.0   1.0   1.0   1.0

SpeciesDataFile        SpeciesData.csv

EcoregionParameters
>>  AET (mm)
$(awk -F'\t' 'NR>3 && $1=="yes" {printf "%s\t600\n", $3}' "$RUN/ecoregions.txt")

SpeciesEcoregionDataFile  SppEcoregionData.csv

FireReductionParameters
>>  Severity   WoodLitter   Litter
    1          0.0          0.5
    2          0.0          0.75
    3          0.5          1.0

HarvestReductionParameters
>>  Name             WoodLitter  Litter  Cohort
    PerseusBA50      0.5         0.15    1.0
    PartialHarvest   0.5         0.15    1.0
BSX

    # ---- Climate generator ----
    cat > "$RUN/climate-generator.txt" <<CGEN
LandisData "Climate Config"
ClimateTimeSeries          Monthly_AverageAllYears
ClimateFile                climate.csv
SpinUpClimateTimeSeries    Monthly_AverageAllYears
SpinUpClimateFile          climate.csv
GenerateClimateOutputFiles yes
UsingFireClimate           no
CGEN

    # ---- Harvest config (only if harvest != none) ----
    HARV_LINE=""
    if [ "$HARV" != "none" ]; then
      RATE=${HARVEST_RATE[$HARV]}
      PRESCR=${HARVEST_PRESCR[$HARV]}

      # Stage stands.tif + management-area.tif (built once per state via build_stands.sh)
      for f in stands.tif management-area.tif; do
        if [ -f "$INPUTS/$f" ]; then
          ln -sf "$INPUTS/$f" "$RUN/$f"
        else
          echo "ERROR: missing $INPUTS/$f. Run: bash $TOOLS/build_stands.sh $ST"
          exit 3
        fi
      done

      # Pull species codes for prescription generation
      SP_CODES=$(awk -F',' 'NR>1 {print $1}' "$RUN/SpeciesData.csv" | tr '\n' ' ')

      # Inline biomass-harvest.txt. We write the species cohort block via a
      # second heredoc so % characters never reach printf and bash quoting
      # stays simple.
      cat > "$RUN/biomass-harvest.txt" <<HARV_HEAD
LandisData  "Biomass Harvest"

Timestep    5

ManagementAreas  ./management-area.tif
Stands           ./stands.tif

Prescription ${PRESCR}
    StandRanking     Random
    MinimumAge       5
    SiteSelection    Complete
    CohortsRemoved   SpeciesList
HARV_HEAD

      for sp in $SP_CODES; do
        printf '        %s    1-400(50%%)\n' "$sp" >> "$RUN/biomass-harvest.txt"
      done

      cat >> "$RUN/biomass-harvest.txt" <<HARV_TAIL

HarvestImplementations
>>  MgmtArea  Prescription      HarvestAreas
    1         ${PRESCR}         ${RATE}

PrescriptionMaps    output/harvest/biomass-harvest-{timestep}.tif
BiomassMaps         output/harvest/biomass-harvest-biomass-{timestep}.tif
EventLog            output/harvest/harvest-event-log.csv
SummaryLog          output/harvest/harvest-summary-log.csv
HARV_TAIL

      HARV_LINE='"Biomass Harvest"      biomass-harvest.txt'
    fi

    # ---- Wind config (always on, Lorimer & White 2003) ----
    cat > "$RUN/base-wind.txt" <<WIND
LandisData "Original Wind"
Timestep    5
EventSizeMean    50
EventSizeMin     1
EventSizeMax     500
RotationPeriod   1000
WindSeverities
>>  Cohort age proportion         Severity
    20%                            5
    50%                            4
    85%                            3
    100%                           2
WindReductionParameters
WIND

    # ---- Top level scenario.txt ----
    cat > "$RUN/scenario.txt" <<SC
LandisData  Scenario

Duration   $DURATION
Species    species.txt
Ecoregions ecoregions.txt
EcoregionsMap ecoregions.tif
CellLength    30

>>------------------ EXTENSIONS ------------------
"Biomass Succession"   biomass-succession.txt
${HARV_LINE}
"Original Wind"            base-wind.txt

>>------------------ OUTPUT ------------------
"Output Biomass"       output-biomass.txt

RandomNumberSeed   42
SC

    cat > "$RUN/output-biomass.txt" <<OUT
LandisData "Output Biomass"
Timestep    5
Species
$(awk -F',' 'NR>1 {print $1}' "$RUN/SpeciesData.csv")
MapNames    output/biomass/biomass-{species}-{timestep}.tif
DeadPools   no
OUT

    # ---- Copy state ecoregion raster (needed by scenario.txt) ----
    cp "$INPUTS/${ST}_ecoregion_l3.tif" "$RUN/ecoregions.tif" 2>/dev/null || true

    # ---- SLURM script ----
    cat > "$RUN/job.slurm" <<SLURM
#!/bin/bash
#SBATCH --job-name=fact_${ST}_${CLIM:0:3}_${HARV:0:3}
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --output=$RUN/job.out
#SBATCH --error=$RUN/job.err

cd $RUN
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  --bind $RUN:$RUN --pwd $RUN \\
  $LANDIS/images/landis-ii_v8_allext_v1.0.sif \\
  dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt
SLURM

    # ---- Submit ----
    JOBID="dry_run"
    if [ "$SUBMIT" = "yes" ]; then
      JOBID=$(sbatch --parsable "$RUN/job.slurm")
      echo "  Submitted: $JOBID"
      echo "$JOBID" > "$RUN/last_jobid.txt"
    else
      echo "  Built (no submit, --submit no)"
    fi

    echo "$SCENARIO,$CLIM,$HARV,$RUN,$JOBID,$(date '+%Y-%m-%d %H:%M:%S')" >> "$SCENARIO_LOG"
    TOTAL_JOBS=$((TOTAL_JOBS + 1))
  done
done

echo
echo "==========================================================="
echo "  Factorial complete: $TOTAL_JOBS scenarios"
echo "  Log: $SCENARIO_LOG"
echo "  Monitor: bash $TOOLS/monitor_factorial.sh $ST"
echo "==========================================================="
