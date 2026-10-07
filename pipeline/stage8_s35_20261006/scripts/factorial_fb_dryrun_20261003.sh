#!/bin/bash
# LANDIS stage eight, factorial DRY RUN for the firebreather four state trees (NH VT MI WI).
# Session 34, 3 Oct 2026. Assembles the 3 climate x 4 harvest scenario text files per state
# and a manifest of every input with status READY, PENDING (needs a decision Aaron owes) or
# BLOCKED (input does not exist yet). NEVER SUBMITS: there is no sbatch call in this file,
# and the job script is written as job.slurm.DRYRUN.
#
# Adapted from tools/scenario_factorial.sh (Cardinal) and smoke_build_fb_20261001.sh. Departures:
#   inputs from states_fb_20260930/<ST>/inputs, never the older Cardinal states/<ST> trees;
#   writes only under states_fb_20260930/<ST>/runs/factorial_dryrun_20261003/;
#   270 m rasters and CellLength reused from the gated 1 Oct smoke build (smoke_20261001_d10);
#   ecoregions.tif missing is an error here (the original copies it with "|| true");
#   a missing climate file is an error here (the original skips it silently);
#   biomass succession block in the smoke format, which ran on all four states;
#   IC table NOT staged: raw, unit corrected and FIADB anchored are decisions (1) and (2).
# Usage: bash factorial_fb_dryrun_20261003.sh <ST> [DURATION=100]
set -uo pipefail
ST=${1:?state}; DUR=${2:-100}
L=/fs/scratch/PUOM0008/crsfaaron/landis2
D=$L/states_fb_20260930
IN=$D/$ST/inputs
SMOKE=$D/$ST/runs/smoke_20261001_d10
F=$D/$ST/runs/factorial_dryrun_20261003
OLD=$L/states/$ST          # read only: Tier 2 calibrated table, if any
GCM=HadGEM3-GC31-LL
[ -d "$SMOKE" ] || { echo "ERROR no smoke build at $SMOKE"; exit 2; }
mkdir -p "$F"
MAN=$F/manifest.tsv
printf 'cell\tcomponent\tsource\tstatus\tnote\n' > "$MAN"
rec() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$MAN"; }
need() { [ -f "$1" ] && [ ! -L "$1" ]; }

pick() { if need "$IN/$1"; then echo "$IN/$1"; else echo "$IN/$2"; fi; }
SPTXT=$(pick species_20260929.txt species.txt)
SPDAT=$(pick SpeciesData_20260929.csv SpeciesData.csv)
for f in "$SPTXT" "$SPDAT"; do need "$f" || { echo "ERROR missing or symlink $f"; exit 3; }; done
need "$IN/ecoregions_20260929.txt" || { echo "ERROR no ecoregions_20260929.txt"; exit 3; }
for f in ecoregions.tif initial-communities.tif build_summary.csv; do
  need "$SMOKE/$f" || { echo "ERROR smoke artefact missing: $SMOKE/$f"; exit 3; }
done
CELL=$(awk -F, 'NR==2{printf "%d", $2+0.5}' "$SMOKE/build_summary.csv")
case "$CELL" in ''|0|*[!0-9]*) echo "ERROR CellLength '$CELL'"; exit 4 ;; esac
ECOS=$(awk '$1=="yes"{print $2}' "$IN/ecoregions_20260929.txt" | tr '\n' ' ')

# Baseline BiomassMax / ANPPmax table: FIA 20260929 restricted to active ecoregions (as smoke).
# A Tier 2 calibrated table, where one exists in the old tree, is recorded as a CANDIDATE only;
# whether it covers this tree's species and ecoregions is measured by the R block below.
awk -F, -v E="$ECOS" 'BEGIN{n=split(E,a," "); for(i=1;i<=n;i++) k[a[i]]=1} NR==1 || ($2 in k)' \
  "$IN/SppEcoregionData_fia_20260929.csv" > "$F/SppEcoregionData_baseline.csv"
CAL=$(ls "$OLD"/perseus/statewide/*_calibrated/SppEcoregionData_*_calibrated.csv 2>/dev/null | head -1 || true)

# One R pass: geometry of harvest rasters, calibrated table coverage and ANPPmax contrast.
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
Rscript - "$IN" "$SMOKE" "$F" "$ST" "$SPTXT" "${CAL:-NONE}" "$ECOS" > "$F/preflight_r.log" 2>&1 <<'RS'
suppressMessages({library(terra); library(data.table)})
a <- commandArgs(TRUE); IN<-a[1]; SM<-a[2]; F<-a[3]; ST<-a[4]; SPTXT<-a[5]; CAL<-a[6]
ecos <- as.integer(strsplit(trimws(a[7]), " +")[[1]])
out <- list()
e30  <- rast(file.path(IN, "ecoregions_20260929.tif"))
e270 <- rast(file.path(SM, "ecoregions.tif"))
for (nm in c("stands.tif", "management-area_PLACEHOLDER.tif")) {
  p <- file.path(IN, nm)
  if (!file.exists(p)) { out[[nm]] <- data.table(item=nm, check="exists", value="FALSE"); next }
  r <- rast(p)
  out[[nm]] <- data.table(item=nm,
    check=c("res_m","same_grid_as_eco30","same_grid_as_run270","n_distinct_values"),
    value=c(paste(round(res(r),1),collapse="x"),
            isTRUE(compareGeom(r, e30, stopOnError=FALSE)),
            isTRUE(compareGeom(r, e270, stopOnError=FALSE)),
            nrow(unique(r))))
}
spp <- readLines(SPTXT); spp <- spp[grepl("^[A-Za-z]", spp) & !grepl("^LandisData", spp)]
spp <- unique(sub("[[:space:]].*$", "", spp))
base <- fread(file.path(F, "SppEcoregionData_baseline.csv"))
need <- CJ(EcoregionName=ecos, SpeciesCode=spp)
cov_base <- nrow(merge(need, unique(base[, .(EcoregionName, SpeciesCode)])))/nrow(need)
out$base <- data.table(item="baseline_table", check=c("species_x_eco_coverage","rows"),
                       value=c(round(cov_base,4), nrow(base)))
if (CAL != "NONE") {
  cal <- fread(CAL)
  cov_cal <- nrow(merge(need, unique(cal[, .(EcoregionName, SpeciesCode)])))/nrow(need)
  m <- merge(base[Year==0, .(EcoregionName, SpeciesCode, ANPP_b=ANPPmax, BMX_b=BiomassMax)],
             cal[Year==0,  .(EcoregionName, SpeciesCode, ANPP_c=ANPPmax, BMX_c=BiomassMax)],
             by=c("EcoregionName","SpeciesCode"))
  m[, `:=`(anpp_ratio_cal_over_base=round(ANPP_c/ANPP_b,3), bmx_ratio_cal_over_base=round(BMX_c/BMX_b,3))]
  fwrite(m, file.path(F, "calibrated_vs_baseline_by_species_eco.csv"))
  out$cal <- data.table(item="tier2_calibrated", check=c("path","species_x_eco_coverage","matched_rows",
                        "median_anpp_ratio","median_bmx_ratio","species_in_cal_not_in_run"),
                        value=c(CAL, round(cov_cal,4), nrow(m),
                                round(median(m$anpp_ratio_cal_over_base),3),
                                round(median(m$bmx_ratio_cal_over_base),3),
                                paste(setdiff(unique(cal$SpeciesCode), spp), collapse=" ")))
}
res <- rbindlist(out, fill=TRUE); res[, state:=ST]
fwrite(res, file.path(F, "preflight_checks.csv")); print(res)
RS
[ -f "$F/preflight_checks.csv" ] || { echo "ERROR R preflight failed, see $F/preflight_r.log"; exit 6; }

for CLIM in baseline ssp245 ssp585; do
 for HARV in none baseline increased perseus; do
  C=${ST}_clim_${CLIM}_harv_${HARV}; R=$F/$C; mkdir -p "$R/output/biomass"
  cp "$SPTXT" "$R/species.txt";      rec "$C" species.txt "$SPTXT" READY ""
  cp "$SPDAT" "$R/SpeciesData.csv";  rec "$C" SpeciesData.csv "$SPDAT" READY ""
  cp "$IN/ecoregions_20260929.txt" "$R/ecoregions.txt"; rec "$C" ecoregions.txt "$IN/ecoregions_20260929.txt" READY ""
  ln -sf "$SMOKE/ecoregions.tif" "$R/ecoregions.tif"; rec "$C" ecoregions.tif "$SMOKE/ecoregions.tif" READY "270 m, gated 1 Oct"
  ln -sf "$SMOKE/initial-communities.tif" "$R/initial-communities.tif"
  rec "$C" initial-communities.tif "$SMOKE/initial-communities.tif" READY "MapCode set identical under raw, unit fix and anchoring (anchor keeps every row, pmax 1)"
  echo "IC table not staged: decision (1) unit patch and (2) FIADB anchoring are Aaron's." > "$R/IC_PENDING.txt"
  rec "$C" initial-communities.csv "cohort_biomass_by_mapcode[_fiadb].csv" PENDING "decisions 1 and 2"

  cp "$F/SppEcoregionData_baseline.csv" "$R/SppEcoregionData.csv"
  rec "$C" SppEcoregionData.csv "$IN/SppEcoregionData_fia_20260929.csv (active ecoregions)" READY \
      "${CAL:+Tier 2 candidate exists: $CAL; see calibrated_vs_baseline_by_species_eco.csv}"
  if [ "$CLIM" = baseline ]; then
    CF="$IN/Daymet_${ST}_l3.csv"
    need "$CF" || { echo "ERROR no $CF"; exit 7; }
    sed 's/\r$//' "$CF" > "$R/climate.csv"; rec "$C" climate.csv "$CF" READY "Daymet 1991 to 2020 means"
  else
    CF="$IN/HadGEM3_${CLIM}_${ST}_l3.csv"
    need "$CF" || { echo "ERROR no $CF"; exit 7; }
    sed 's/\r$//' "$CF" > "$R/climate.csv"; rec "$C" climate.csv "$CF" READY "synthetic delta table (stage five)"
    P=$L/states/$ST/pnet2/${GCM}_${CLIM}/SppEcoregionData_${ST}_${GCM}_${CLIM}.csv
    if need "$P"; then rec "$C" SppEcoregionData.csv "$P" READY "PnET-II refined"
    else rec "$C" SppEcoregionData_climate "$P" BLOCKED \
      "no PnET-II tables; with Monthly_AverageAllYears and static parameters this cell equals its baseline twin"
    fi
  fi
  cat > "$R/climate-generator.txt" <<CG
LandisData "Climate Config"
ClimateTimeSeries          Monthly_AverageAllYears
ClimateFile                climate.csv
SpinUpClimateTimeSeries    Monthly_AverageAllYears
SpinUpClimateFile          climate.csv
GenerateClimateOutputFiles no
UsingFireClimate           no
CG
  {
  echo 'LandisData "Biomass Succession"'; echo 'Timestep 5'; echo 'SeedingAlgorithm WardSeedDispersal'
  echo 'InitialCommunities       initial-communities.csv'; echo 'InitialCommunitiesMap    initial-communities.tif'
  echo 'ClimateConfigFile        climate-generator.txt'; echo 'MinRelativeBiomass'
  printf '        '; for e in $ECOS; do printf '%s ' "$e"; done; echo
  for pct in 20 40 60 80 100; do sh=$((pct/20)); printf '    %d  ' "$sh"; for e in $ECOS; do printf '%s%% ' "$pct"; done; echo; done
  cat <<'SL'
SufficientLight
    1   1.0  0.5  0.0  0.0  0.0  0.0
    2   1.0  1.0  0.5  0.0  0.0  0.0
    3   1.0  1.0  1.0  0.5  0.0  0.0
    4   1.0  1.0  1.0  1.0  0.5  0.0
    5   1.0  1.0  1.0  1.0  1.0  0.5
SL
  echo 'SpeciesDataFile        SpeciesData.csv'; echo 'EcoregionParameters'; echo '>>  AET (mm)'
  for e in $ECOS; do echo "$e   600"; done
  echo 'SpeciesEcoregionDataFile  SppEcoregionData.csv'
  cat <<'FH'
FireReductionParameters
    1        0.0        0.5
    2        0.0        0.75
    3        0.5        1.0
HarvestReductionParameters
    PerseusBA50     0.5 0.15 0.5 0.0
    PartialHarvest  0.5 0.15 0.5 0.0
FH
  } > "$R/biomass_succession.txt"
  rec "$C" AET "placeholder 600 mm, all ecoregions" READY "inherited from scenario_factorial.sh and the smoke; not ecoregion specific"

  HL=""
  if [ "$HARV" != none ]; then
    case $HARV in baseline) RATE=0.022; PR=PartialHarvest ;; increased) RATE=0.035; PR=PartialHarvest ;;
                  perseus) RATE=0.022; PR=PerseusBA50 ;; esac
    rec "$C" management-area.tif "$IN/management-area_PLACEHOLDER.tif" BLOCKED \
        "PLACEHOLDER pending Solarik MA definitions; 30 m, needs the 270 m run grid"
    rec "$C" stands.tif "$IN/stands.tif" BLOCKED "30 m, needs the 270 m run grid"
    { echo 'LandisData  "Biomass Harvest"'; echo; echo 'Timestep    5'; echo
      echo 'ManagementAreas  ./management-area.tif'; echo 'Stands           ./stands.tif'; echo
      echo "Prescription ${PR}"; echo '    StandRanking     Random'; echo '    MinimumAge       5'
      echo '    SiteSelection    Complete'; echo '    CohortsRemoved   SpeciesList'
      awk 'NF>=9 && $1 !~ /^>>/ && $1!="LandisData"{printf "        %s    1-400(50%%)\n", $1}' "$R/species.txt"
      echo; echo 'HarvestImplementations'; echo '>>  MgmtArea  Prescription      HarvestAreas'
      echo "    1         ${PR}         ${RATE}"; echo
      echo 'PrescriptionMaps    output/harvest/biomass-harvest-{timestep}.tif'
      echo 'BiomassMaps         output/harvest/biomass-harvest-biomass-{timestep}.tif'
      echo 'EventLog            output/harvest/harvest-event-log.csv'
      echo 'SummaryLog          output/harvest/harvest-summary-log.csv'; } > "$R/biomass-harvest.txt"
    HL='"Biomass Harvest"      biomass-harvest.txt'
    rec "$C" harvest_rate "$RATE $PR" READY "S-L 2025 study mean 0.022; increased +60 pct"
  fi
  cat > "$R/base-wind.txt" <<WIND
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
  rec "$C" base-wind.txt "Lorimer and White 2003 regime, as scenario_factorial.sh" READY "Original Wind never run on these trees; untested"
  SPP=$(awk 'NF>=9 && $1 !~ /^>>/ && $1!="LandisData"{print $1}' "$R/species.txt")
  { echo 'LandisData  "Output Biomass"'; echo 'Timestep   5'; echo 'MakeTable  yes'
    first=1; for s in $SPP; do if [ $first = 1 ]; then echo "Species  $s"; first=0; else echo "         $s"; fi; done
    echo 'MapNames   output/biomass/biomass-{species}-{timestep}.tif'
    echo 'DeadPools  both'; echo 'MapNames   output/biomass/biomass-{pool}-{timestep}.tif'; } > "$R/output_biomass.txt"
  cat > "$R/scenario.txt" <<SC
LandisData  Scenario
Duration  $DUR
Species   ./species.txt
Ecoregions      ./ecoregions.txt
EcoregionsMap   ./ecoregions.tif
CellLength  $CELL
"Biomass Succession"  biomass_succession.txt
${HL}
"Original Wind"       base-wind.txt
"Output Biomass"      output_biomass.txt
RandomNumberSeed   42
SC
  cat > "$R/job.slurm.DRYRUN" <<SLX
#!/bin/bash
# DRY RUN ARTEFACT. Do not submit until IC_PENDING.txt and every BLOCKED row in ../manifest.tsv is closed.
#SBATCH --account=PUOM0008 --job-name=${ST}_${CLIM:0:3}_${HARV:0:3} --time=08:00:00
#SBATCH --nodes=1 --cpus-per-task=8 --mem=96G
#SBATCH --output=$R/slurm-%j.out --error=$R/slurm-%j.err
cd $R
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  --bind $L/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \\
  --bind $L/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \\
  --bind $R:$R --pwd $R \\
  $L/images/landis-ii_v8_allext_v1.0.sif dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt
echo "LANDIS_EXIT=\$?"
SLX
 done
done

# Gate: every file a scenario or extension file names exists in the cell, or is PENDING/BLOCKED in the manifest.
GFAIL=0
for R in "$F"/${ST}_clim_*; do
  C=$(basename "$R")
  for ref in $(grep -h -o -E '[A-Za-z0-9_.-]+\.(txt|csv|tif)' "$R"/scenario.txt "$R"/biomass_succession.txt \
                 "$R"/climate-generator.txt $( [ -f "$R/biomass-harvest.txt" ] && echo "$R/biomass-harvest.txt") \
               | grep -v -e '{' -e '^output' -e 'harvest-event-log' -e 'harvest-summary-log' | sort -u); do
    b=$(basename "$ref")
    if [ -e "$R/$b" ]; then continue; fi
    if awk -F'\t' -v c="$C" -v b="$b" '$1==c && ($4=="PENDING"||$4=="BLOCKED") && index($2,b)>0' "$MAN" | grep -q .; then continue; fi
    echo "GATE FAIL $C: $b referenced, absent, not declared"; GFAIL=1
  done
done
NCELL=$(ls -d "$F"/${ST}_clim_* | wc -l)
awk -F'\t' 'NR>1{n[$4]++} END{for(k in n) printf "%s=%d ", k, n[k]; print ""}' "$MAN" > "$F/manifest_counts.txt"
echo "$ST cells=$NCELL CellLength=$CELL gate=$([ $GFAIL = 0 ] && echo PASS || echo FAIL) $(cat "$F/manifest_counts.txt")" | tee "$F/dryrun_summary.txt"
exit $GFAIL
