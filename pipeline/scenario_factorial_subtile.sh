#!/bin/bash
# scenario_factorial_subtile.sh
#
# Subtile Path 1 factorial. Each (state, tile, owner, climate, harvest) gets
# its own LANDIS run by inheriting the tile's working biomass succession
# config and adding owner-stratified harvest + climate-aware SppEcoregionData.
#
# Workaround for the v1.1 image UniversalCohorts segfault that fires
# probabilistically at full state scale. Per Maine v3 experience, ~80% of
# tiles complete cleanly; 5km subtile recovery handles the rest.
#
# 2026-05-05: now bind-mounts the patched Landis.Console.dll (assembly.GetType
# fix for dotnet/runtime #103222) into the container so Biomass Harvest and
# Original Wind plug-ins load. Provide --patch-dir or set the LANDIS_PATCH_DIR
# env var pointing at a directory holding the patched DLLs (Landis.Console.dll
# required, Landis.Utilities.dll optional). Override with --use-patch no for an
# unpatched run.
#
# Usage on Cardinal:
#   bash scenario_factorial_subtile.sh ME                # all 265 tiles, 36 scenarios
#   bash scenario_factorial_subtile.sh ME --tiles 5      # smoke test: 5 tiles
#   bash scenario_factorial_subtile.sh ME --owners ind --climate baseline --harvest baseline
#   bash scenario_factorial_subtile.sh ME --submit no    # dry run
#   bash scenario_factorial_subtile.sh ME --use-patch no # disable patched DLL overlay

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: bash scenario_factorial_subtile.sh <STATE> [--tiles N] [--owners <list>] [--climate <list>] [--harvest <list>] [--duration N] [--submit yes|no] [--use-patch yes|no] [--patch-dir <path>] [--wind yes|no]"
  exit 1
fi

ST=$1; shift

TILE_LIMIT=0       # 0 = all tiles
OWNER_LIST="ind nipf public"
CLIM_LIST="baseline ssp245 ssp585"
HARV_LIST="none baseline increased perseus"
DURATION=50
SUBMIT="yes"
GCM="HadGEM3-GC31-LL"
USE_PATCH="yes"
WIND="yes"
REBUILD_CACHE="no"        # force MA + stands cache rebuild even when files exist
SKIP_EXISTING="no"        # skip a scenario when its year-DURATION biomass tif is already present
QUEUE_LIMIT=900           # wait when squeue size reaches this many jobs (Cardinal QOS soft cap is ~1000)
QUEUE_POLL_SEC=30         # how long to sleep between queue checks
PATCH_DIR="${LANDIS_PATCH_DIR:-/fs/scratch/PUOM0008/crsfaaron/landis2/patches}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --tiles)          TILE_LIMIT=$2; shift 2 ;;
    --owners)         OWNER_LIST=$(echo $2 | tr ',' ' '); shift 2 ;;
    --climate)        CLIM_LIST=$(echo $2 | tr ',' ' '); shift 2 ;;
    --harvest)        HARV_LIST=$(echo $2 | tr ',' ' '); shift 2 ;;
    --duration)       DURATION=$2; shift 2 ;;
    --submit)         SUBMIT=$2; shift 2 ;;
    --use-patch)      USE_PATCH=$2; shift 2 ;;
    --patch-dir)      PATCH_DIR=$2; shift 2 ;;
    --wind)           WIND=$2; shift 2 ;;
    --rebuild-cache)  REBUILD_CACHE=$2; shift 2 ;;
    --skip-existing)  SKIP_EXISTING=$2; shift 2 ;;
    --queue-limit)    QUEUE_LIMIT=$2; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
TOOLS=/users/PUOM0008/crsfaaron/landis2/scratch/tools
INPUTS=$LANDIS/states/$ST/inputs
TILE_BASE=$LANDIS/states/$ST/runs/tile_array
SUBTILE_FACT=$LANDIS/states/$ST/runs/subtile_factorial

# Patched Landis.Console.dll bind-mount string. Empty when --use-patch no, or
# when no patched DLLs are found at PATCH_DIR. Composed once and reused in
# every scenario's job.slurm so we do not re-check the filesystem for 200+
# scenarios. md5 of the expected console DLL is a42d209f4faf2f2562cd5f63e32b8f8a.
PATCH_BIND=""
if [ "$USE_PATCH" = "yes" ]; then
  if [ -f "$PATCH_DIR/Landis.Console.dll" ]; then
    PATCH_BIND="--bind $PATCH_DIR/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll"
    if [ -f "$PATCH_DIR/Landis.Utilities.dll" ]; then
      PATCH_BIND="$PATCH_BIND --bind $PATCH_DIR/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll"
    fi
    echo "  patched DLLs: $PATCH_BIND"
  else
    echo "  WARN: --use-patch yes but $PATCH_DIR/Landis.Console.dll not found; harvest + wind will fail in v1.1 image"
  fi
fi

declare -A HARVEST_RATE=(
  [none]=0.000
  [baseline]=0.022
  [increased]=0.035
  [perseus]=0.022
)
declare -A HARVEST_PRESCR=(
  [none]=none
  [baseline]=PartialHarvest
  [increased]=PartialHarvest
  [perseus]=PerseusBA50
)

# Discover tiles
TILES=$(ls -d $TILE_BASE/tile_* 2>/dev/null | sort)
if [ -z "$TILES" ]; then
  echo "ERROR: no tiles under $TILE_BASE — Maine v3 tile structure required"
  exit 2
fi

if [ "$TILE_LIMIT" -gt 0 ]; then
  TILES=$(echo "$TILES" | head -$TILE_LIMIT)
fi
N_TILES=$(echo "$TILES" | wc -l)

# Compute total scenarios
N_OWNERS=$(echo $OWNER_LIST | wc -w)
N_CLIM=$(echo $CLIM_LIST | wc -w)
N_HARV=$(echo $HARV_LIST | wc -w)
TOTAL_PER_TILE=$((N_OWNERS * N_CLIM * N_HARV))
TOTAL=$((N_TILES * TOTAL_PER_TILE))

echo "============================================================"
echo "  $ST subtile factorial"
echo "============================================================"
echo "  tiles:     $N_TILES"
echo "  owners:    $N_OWNERS ($OWNER_LIST)"
echo "  climates:  $N_CLIM ($CLIM_LIST)"
echo "  harvests:  $N_HARV ($HARV_LIST)"
echo "  per tile:  $TOTAL_PER_TILE scenarios"
echo "  total:     $TOTAL scenarios"
echo "============================================================"

mkdir -p "$SUBTILE_FACT"
LOG=$SUBTILE_FACT/submission_log_$(date +%Y%m%d_%H%M).csv
echo "scenario,tile,owner,climate,harvest,run_dir,job_id,submitted_at" > "$LOG"

##############################################################################
# Per-state: get the species code list once
##############################################################################
SP_CODES=$(awk -F',' 'NR>1 {print $1}' "$INPUTS/SpeciesData.csv" | tr '\n' ' ')

SUBMITTED=0
FAILED_BUILD=0

for TILE_DIR in $TILES; do
  TILE=$(basename "$TILE_DIR")

  # Sanity: tile must have its own IC, eco, ecoregions
  for f in initial-communities.tif ecoregions.tif ecoregions.txt biomass_succession.txt; do
    if [ ! -f "$TILE_DIR/$f" ]; then
      echo "  WARN: $TILE missing $f, skipping"
      continue 2
    fi
  done

  ##############################################################################
  # Per tile work, hoisted out of the (clim, harv) loops.
  #
  # LANDIS-II loads the landscape from ecoregions.tif, then validates every
  # other map (initial-communities, management-area, stands) against ECO's
  # row x column dimensions. Some tiles in tile_array have IC at 666x667 or
  # 667x666 while ECO is 667x667 because IC was rasterized to active forest
  # extent. We must size MA and stands to ECO so Biomass Harvest does not
  # reject them. Build/cache once per tile.
  ##############################################################################
  ECO_TIF=$TILE_DIR/ecoregions.tif
  TILE_IC_CSV=$SUBTILE_FACT/_cache/${TILE}_initial_communities.csv
  TILE_STANDS=$SUBTILE_FACT/_cache/${TILE}_stands.tif
  mkdir -p $SUBTILE_FACT/_cache

  # Build IC CSV once per tile (cheap, awk only).
  if [ ! -f "$TILE_IC_CSV" ]; then
    awk '
      BEGIN { print "MapCode,SpeciesName,CohortAge,CohortBiomass"; mc=0 }
      /^LandisData/ { next }
      /^[[:space:]]*$/ { next }
      /^[[:space:]]*>>/ { next }
      /^MapCode/ { mc=$2; next }
      mc > 0 && /^[[:space:]]+[A-Z]/ {
        sp=$1
        for (i=2; i<=NF; i++) print mc","sp","$i",0"
      }
    ' "$TILE_DIR/initial_communities.txt" > "$TILE_IC_CSV"
  fi

  # Read ECO geotransform / size once via apptainer python (one call per tile).
  if [ ! -f "$TILE_STANDS" ] || [ "$REBUILD_CACHE" = "yes" ]; then
    ECO_INFO=$(apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
      $LANDIS/images/landis-ii_v8_allext_v1.0.sif python3 -c "
from osgeo import gdal
ds = gdal.Open('$ECO_TIF')
gt = ds.GetGeoTransform()
xs, ys = ds.RasterXSize, ds.RasterYSize
ll_x = gt[0]
ur_y = gt[3]
ll_y = ur_y + gt[5]*ys
ur_x = ll_x + gt[1]*xs
print(f'{xs} {ys} {ll_x} {ll_y} {ur_x} {ur_y}')
" 2>/dev/null)
    ECO_XS=$(echo $ECO_INFO | awk '{print $1}')
    ECO_YS=$(echo $ECO_INFO | awk '{print $2}')
    ECO_TE="$(echo $ECO_INFO | awk '{print $3, $4, $5, $6}')"
  else
    # Cache hit: cheap gdalinfo via host R/python is not available, so fall
    # back to reading dims with file(1) is brittle. Just trust the cache and
    # let LANDIS error if dims drift (--rebuild-cache yes forces a refresh).
    ECO_XS=""; ECO_YS=""; ECO_TE=""
  fi

  # Build stands raster (sized to ECO) once per tile.
  if [ ! -f "$TILE_STANDS" ] || [ "$REBUILD_CACHE" = "yes" ]; then
    apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
      $LANDIS/images/landis-ii_v8_allext_v1.0.sif python3 -c "
from osgeo import gdal
import numpy as np
ds = gdal.Open('$ECO_TIF')
a = ds.GetRasterBand(1).ReadAsArray()
mask = a > 0
sids = np.zeros_like(a, dtype=np.int32)
sids[mask] = np.arange(1, int(mask.sum())+1, dtype=np.int32)
drv = gdal.GetDriverByName('GTiff')
out = drv.Create('$TILE_STANDS', ds.RasterXSize, ds.RasterYSize, 1, gdal.GDT_Int32,
                 options=['COMPRESS=DEFLATE','PREDICTOR=2','TILED=YES'])
out.SetGeoTransform(ds.GetGeoTransform()); out.SetProjection(ds.GetProjection())
out.GetRasterBand(1).WriteArray(sids); out.GetRasterBand(1).SetNoDataValue(0)
out = None
" 2>/dev/null
  fi

  for OWNER in $OWNER_LIST; do
    OWNER_MA_SRC=$INPUTS/management-area_${OWNER}.tif
    if [ ! -f "$OWNER_MA_SRC" ]; then continue; fi

    # Per (tile, owner) MA crop. Builds once per (tile, owner) across all
    # (clim, harv) iterations.
    TILE_OWNER_MA=$SUBTILE_FACT/_cache/${TILE}_${OWNER}_ma.tif
    if [ ! -f "$TILE_OWNER_MA" ] || [ "$REBUILD_CACHE" = "yes" ]; then
      # Need ECO_TE/XS/YS even if stands was cached but MA isn't. Read once.
      if [ -z "$ECO_TE" ]; then
        ECO_INFO=$(apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
          $LANDIS/images/landis-ii_v8_allext_v1.0.sif python3 -c "
from osgeo import gdal
ds = gdal.Open('$ECO_TIF')
gt = ds.GetGeoTransform()
xs, ys = ds.RasterXSize, ds.RasterYSize
print(f'{xs} {ys} {gt[0]} {gt[3]+gt[5]*ys} {gt[0]+gt[1]*xs} {gt[3]}')
" 2>/dev/null)
        ECO_XS=$(echo $ECO_INFO | awk '{print $1}')
        ECO_YS=$(echo $ECO_INFO | awk '{print $2}')
        ECO_TE="$(echo $ECO_INFO | awk '{print $3, $4, $5, $6}')"
      fi
      apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
        $LANDIS/images/landis-ii_v8_allext_v1.0.sif \
        gdalwarp -q -overwrite \
          -te $ECO_TE -ts $ECO_XS $ECO_YS \
          -ot Int32 -dstnodata 0 \
          -co COMPRESS=DEFLATE -co PREDICTOR=2 -co TILED=YES \
          "$OWNER_MA_SRC" "$TILE_OWNER_MA" 2>/dev/null
    fi

    for CLIM in $CLIM_LIST; do
      for HARV in $HARV_LIST; do
        SCENARIO="${TILE}__own_${OWNER}_clim_${CLIM}_harv_${HARV}"
        RUN=$SUBTILE_FACT/$SCENARIO
        mkdir -p "$RUN/output"

        ##############################################################
        # Per scenario: symlink tile-level inputs (small, shared)
        ##############################################################
        ln -sf "$TILE_DIR/initial-communities.tif"        "$RUN/initial-communities.tif"
        ln -sf "$TILE_DIR/ecoregions.tif"                 "$RUN/ecoregions.tif"
        cp    "$TILE_DIR/ecoregions.txt"                 "$RUN/ecoregions.txt"
        cp    "$TILE_DIR/biomass_succession.txt"         "$RUN/biomass-succession.txt"

        ln -sf "$TILE_IC_CSV" "$RUN/initial_communities.csv"
        sed -i 's|biomass-succession_InitialCommunities.csv|initial_communities.csv|g' "$RUN/biomass-succession.txt"
        ln -sf "$TILE_DIR/initial_communities.txt" "$RUN/initial_communities.txt" 2>/dev/null || true
        cp    "$TILE_DIR/biomass-succession_ClimateGenerator.txt" "$RUN/biomass-succession_ClimateGenerator.txt" 2>/dev/null || true
        for cf in PRISM_maine_l3.csv PRISM_${ST}_l3.csv climate.csv; do
          [ -f "$TILE_DIR/$cf" ] && ln -sf "$TILE_DIR/$cf" "$RUN/$cf"
        done
        cp    "$INPUTS/species.txt"                      "$RUN/species.txt"
        cp    "$INPUTS/SpeciesData.csv"                  "$RUN/SpeciesData.csv"

        ln -sf "$TILE_OWNER_MA" "$RUN/management-area.tif"
        ln -sf "$TILE_STANDS" "$RUN/stands.tif"

        ##############################################################
        # Climate-aware SppEcoregionData
        ##############################################################
        if [ "$CLIM" = "baseline" ]; then
          ln -sf "$INPUTS/SppEcoregionData.csv" "$RUN/SppEcoregionData.csv"
        else
          PNET_OUT=$LANDIS/states/$ST/pnet2/${GCM}_${CLIM}/SppEcoregionData_${ST}_${GCM}_${CLIM}.csv
          if [ -f "$PNET_OUT" ]; then
            ln -sf "$PNET_OUT" "$RUN/SppEcoregionData.csv"
          else
            ln -sf "$INPUTS/SppEcoregionData.csv" "$RUN/SppEcoregionData.csv"
          fi
        fi

        ##############################################################
        # Per-scenario harvest config (only if HARV != none)
        ##############################################################
        HARV_LINE=""
        if [ "$HARV" != "none" ]; then
          RATE=${HARVEST_RATE[$HARV]}
          PRESCR=${HARVEST_PRESCR[$HARV]}

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
          # LANDIS-II Biomass Harvest expects HarvestArea as a percentage with %
          # suffix (e.g. "2.2%"), not a fraction. Convert here.
          RATE_PCT=$(awk -v r=$RATE 'BEGIN{printf "%.1f%%", r*100}')
          cat >> "$RUN/biomass-harvest.txt" <<HARV_TAIL

HarvestImplementations
>>  MgmtArea  Prescription      HarvestArea     BeginTime  EndTime
    1         ${PRESCR}         ${RATE_PCT}     0          ${DURATION}

PrescriptionMaps    output/harvest/biomass-harvest-{timestep}.tif
BiomassMaps         output/harvest/biomass-harvest-biomass-{timestep}.tif
EventLog            output/harvest/harvest-event-log.csv
SummaryLog          output/harvest/harvest-summary-log.csv
HARV_TAIL
          mkdir -p "$RUN/output/harvest"
          HARV_LINE='"Biomass Harvest"      biomass-harvest.txt'
        fi

        ##############################################################
        # Wind config — Original Wind v4 parser reads Timestep, then the
        # ecoregion EventParameters table (no keyword), then WindSeverities.
        # See LANDIS-II-Foundation/Extension-Base-Wind src/InputParameterParser.cs.
        # Severity classes are numbered 5 (least mortality) to 1 (most).
        ##############################################################
        ACTIVE_ECO=$(awk '/^yes/ {print $2}' "$RUN/ecoregions.txt")
        cat > "$RUN/base-wind.txt" <<WIND_HEAD
LandisData "Original Wind"

Timestep    5

>>             ___ Event Size ___   Rotation
>> Ecoregion    Max   Mean    Min   Period
>> ---------   ----   ----   ----   --------
WIND_HEAD
        for eco in $ACTIVE_ECO; do
          printf '    %s          500    50      1     1000\n' "$eco" \
            >> "$RUN/base-wind.txt"
        done
        cat >> "$RUN/base-wind.txt" <<WIND_TAIL

WindSeverities

 >>            Cohort Age       Mortality
 >> Severity   % of longevity   Probability
 >> --------   --------------   -----------
       5          0% to  20%       0.05
       4         20% to  50%       0.10
       3         50% to  70%       0.50
       2         70% to  85%       0.85
       1         85% to 100%       0.95

MapNames        output/wind/severity-{timestep}.tif
SummaryLogFile  output/wind/wind-summary-log.csv
EventLogFile    output/wind/wind-events-log.csv
WIND_TAIL
        mkdir -p "$RUN/output/wind"

        ##############################################################
        # Top-level scenario.txt
        ##############################################################
        # The official Foundation v1.1 image registers Biomass Harvest and
        # Original Wind in extensions.xml but the .NET 8 plugin loader fails
        # to resolve their types (dotnet/runtime #103222). With the patched
        # Landis.Console.dll bind-mounted into the container the loader works
        # and we can list both extensions here. When --harvest none and
        # --wind no, the EXTENSIONS block falls back to succession-only.
        EXT_HARVEST_LINE=""
        if [ -n "$HARV_LINE" ]; then
          EXT_HARVEST_LINE="$HARV_LINE"
        fi
        EXT_WIND_LINE=""
        if [ "$WIND" = "yes" ]; then
          EXT_WIND_LINE='"Original Wind"        base-wind.txt'
        fi
        cat > "$RUN/scenario.txt" <<SC
LandisData  Scenario

Duration   $DURATION
Species    species.txt
Ecoregions ecoregions.txt
EcoregionsMap ecoregions.tif
CellLength    30

>>------------------ EXTENSIONS ------------------
"Biomass Succession"   biomass-succession.txt
$EXT_HARVEST_LINE
$EXT_WIND_LINE

>>------------------ OUTPUT ------------------
"Output Biomass"       output-biomass.txt

RandomNumberSeed   42
SC

        # Output Biomass needs one species per line after "Species" keyword
        SP_LINES=$(echo $SP_CODES | tr ' ' '\n' | awk 'NR==1 {print "Species  " $1; next} {print "         " $1}')
        cat > "$RUN/output-biomass.txt" <<OUT
LandisData  "Output Biomass"
Timestep   5
MakeTable  yes
$SP_LINES
MapNames   output/biomass/biomass-{species}-{timestep}.tif
DeadPools  both
MapNames   output/biomass/biomass-{pool}-{timestep}.tif
OUT

        mkdir -p "$RUN/output/biomass"

        ##############################################################
        # Skip if year-DURATION biomass output is already present.
        ##############################################################
        if [ "$SKIP_EXISTING" = "yes" ] && \
           [ -f "$RUN/output/biomass/biomass-TotalBiomass-${DURATION}.tif" ]; then
          echo "$SCENARIO,$TILE,$OWNER,$CLIM,$HARV,$RUN,skipped_existing,$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG"
          SUBMITTED=$((SUBMITTED + 1))
          continue
        fi

        ##############################################################
        # SLURM
        ##############################################################
        cat > "$RUN/job.slurm" <<SLURM
#!/bin/bash
#SBATCH --job-name=st_${ST}_${OWNER:0:3}_${CLIM:0:3}_${HARV:0:3}
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=$RUN/job.out
#SBATCH --error=$RUN/job.err

cd $RUN
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  $PATCH_BIND \\
  --bind $RUN:$RUN --pwd $RUN \\
  $LANDIS/images/landis-ii_v8_allext_v1.0.sif \\
  dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt
SLURM

        ##############################################################
        # Throttle: wait while the queue is at or above QUEUE_LIMIT to
        # avoid the QOS soft cap (~1000 jobs) that produces sbatch errors.
        ##############################################################
        if [ "$SUBMIT" = "yes" ] && [ "$QUEUE_LIMIT" -gt 0 ]; then
          while :; do
            QSIZE=$(squeue -u $USER --noheader 2>/dev/null | wc -l)
            if [ "$QSIZE" -lt "$QUEUE_LIMIT" ]; then break; fi
            echo "  queue at $QSIZE >= $QUEUE_LIMIT, sleeping ${QUEUE_POLL_SEC}s..."
            sleep $QUEUE_POLL_SEC
          done
        fi

        JOBID="dry_run"
        if [ "$SUBMIT" = "yes" ]; then
          JOBID=$(sbatch --parsable "$RUN/job.slurm" 2>/dev/null) || JOBID="submit_failed"
          [ "$JOBID" != "submit_failed" ] && echo "$JOBID" > "$RUN/last_jobid.txt"
        fi

        echo "$SCENARIO,$TILE,$OWNER,$CLIM,$HARV,$RUN,$JOBID,$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG"
        SUBMITTED=$((SUBMITTED + 1))

        # Print every 100th submission so we can see progress
        if [ $((SUBMITTED % 100)) -eq 0 ]; then
          echo "  submitted $SUBMITTED of $TOTAL"
        fi
      done
    done
  done
done

echo
echo "============================================================"
echo "  Subtile factorial complete"
echo "  Submitted: $SUBMITTED of $TOTAL planned"
echo "  Log: $LOG"
echo "============================================================"
