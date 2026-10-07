#!/bin/bash
# LANDIS stage eight smoke build for the firebreather four state trees (NH VT MI WI).
# Adapted from tools/build_state_statewide_anchored_cal.sh (the MN statewide run of
# 1 July 2026, which completed). Differences, each deliberate:
#   inputs come from states_fb_20260930/<ST>/inputs (the md5 verified firebreather copy),
#   never from the older Cardinal states/<ST> trees;
#   ecoregion raster is ecoregions_20260929.tif (30 m, on the IC grid), table is
#   ecoregions_20260929.txt copied verbatim, BiomassMax table is SppEcoregionData_fia_20260929.csv;
#   the run copy of that table is restricted to the active ecoregions in ecoregions_20260929.txt,
#   which drops the inert Dryad ecoregion 82 rows in NH and VT FROM THE RUN COPY ONLY
#   (the source file is not touched; promotion is Aaron's decision);
#   species.txt and SpeciesData.csv use the _20260929 real files where they exist, because the
#   NH and VT undated names are symlinks to firebreather absolute paths and are dead here;
#   IC is the unanchored cohort_biomass_by_mapcode.csv (no FIADB anchoring yet), so year zero
#   biomass is gated against FIADB rather than forced to it;
#   climate is Daymet_<ST>_l3.csv (1991 to 2020, Monthly_AverageAllYears), harvest none,
#   management area PLACEHOLDER (not wired: no harvest extension in a smoke run).
# Usage: bash smoke_build_fb_20261001.sh <ST> [DURATION=10] [SUBMIT=yes] [IC=raw|unitfix]
#   IC=unitfix doubles CohortBiomass in the RUN COPY of the IC table. build_initial_communities_v3.R
#   line 240 converts TreeMap DRYBIO_L with x1000x0.4536/0.4047/10 = 112.08 g m-2 per unit, i.e. 1000 lb;
#   the TreeMap 2022 data dictionary defines DRYBIO_L as sum(DRYBIO)/2000*TPA_UNADJ, short tons per acre,
#   whose factor is 224.17. The source IC files are not changed.
set -uo pipefail
ST=${1:?state}; DUR=${2:-10}; SUBMIT=${3:-yes}; ICV=${4:-raw}
L=/fs/scratch/PUOM0008/crsfaaron/landis2
D=$L/states_fb_20260930
IN=$D/$ST/inputs
R=$D/$ST/runs/smoke_20261001_d${DUR}; [ "$ICV" = raw ] || R=${R}_$ICV
SIF=$L/images/landis-ii_v8_allext_v1.0.sif
mkdir -p "$R/output/biomass"; cd "$R"
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1

pick() { if [ -f "$IN/$1" ] && [ ! -L "$IN/$1" ]; then echo "$IN/$1"; else echo "$IN/$2"; fi; }
SPTXT=$(pick species_20260929.txt species.txt)
SPDAT=$(pick SpeciesData_20260929.csv SpeciesData.csv)
for f in "$SPTXT" "$SPDAT"; do [ -L "$f" ] && { echo "ERROR symlink $f"; exit 3; }; done
echo "species.txt   <- $SPTXT"; echo "SpeciesData   <- $SPDAT"
cp "$SPTXT" species.txt; cp "$SPDAT" SpeciesData.csv
cp "$IN/ecoregions_20260929.txt" ecoregions.txt
ECOS=$(awk '$1=="yes"{print $2}' ecoregions.txt | tr '\n' ' ')
echo "active ecoregions: $ECOS"
awk -F, -v E="$ECOS" 'BEGIN{n=split(E,a," "); for(i=1;i<=n;i++) k[a[i]]=1} NR==1 || ($2 in k)' \
  "$IN/SppEcoregionData_fia_20260929.csv" > SppEcoregionData_fia.csv
echo "SppEcoregion rows: source $(($(wc -l < $IN/SppEcoregionData_fia_20260929.csv)-1)), run $(($(wc -l < SppEcoregionData_fia.csv)-1))"
case "$ICV" in
  raw)     cp "$IN/initial_communities/cohort_biomass_by_mapcode.csv" initial-communities.csv ;;
  unitfix) awk -F, 'BEGIN{OFS=","} NR==1{print; next} {$4=2*$4; print}' \
             "$IN/initial_communities/cohort_biomass_by_mapcode.csv" > initial-communities.csv ;;
  *) echo "ERROR IC variant $ICV"; exit 5 ;;
esac
echo "IC variant: $ICV"

Rscript -e '
suppressMessages({library(terra); library(data.table)})
IN<-"'"$IN"'"; R<-"'"$R"'"; ST<-"'"$ST"'"; ecos<-as.integer(strsplit(trimws("'"$ECOS"'")," +")[[1]])
e<-rast(file.path(IN,"ecoregions_20260929.tif")); ic<-rast(file.path(IN,"initial_communities/initial-communities.tif"))
stopifnot(compareGeom(e,ic))
e270<-aggregate(e, fact=9, fun="modal", na.rm=TRUE)
ic270<-resample(ic, e270, method="near")
eco_cells<-global(e270 %in% ecos, "sum", na.rm=TRUE)[1,1]
e270[!(values(e270) %in% ecos)] <- 0
cb<-fread(file.path(R,"initial-communities.csv")); mc<-unique(cb$MapCode)
ic270[!(values(ic270) %in% mc)] <- 0
mask<-(e270>0)&(ic270>0)
writeRaster(ifel(mask,e270,0),  file.path(R,"ecoregions.tif"),          overwrite=TRUE, datatype="INT4S", NAflag=0)
writeRaster(ifel(mask,ic270,0), file.path(R,"initial-communities.tif"), overwrite=TRUE, datatype="INT4S", NAflag=0)
act<-global(mask,"sum",na.rm=TRUE)[1,1]; cell<-res(e270)[1]
icm<-ifel(mask,ic270,NA); fr<-as.data.table(freq(icm)); setnames(fr,c("layer","MapCode","n"))
bio<-cb[,.(g=sum(CohortBiomass)),by=MapCode]; v<-merge(fr,bio,by="MapCode",all.x=TRUE); v[is.na(g),g:=0]
ic_tg<-v[,sum(n*cell^2*g)]/1e12
byeco<-as.data.table(freq(ifel(mask,e270,NA)))[,.(eco=value,cells=count)]
fwrite(byeco, file.path(R,"active_cells_by_ecoregion.csv"))
fwrite(data.table(state=ST,cell_m=round(cell,1),eco_cells_270=eco_cells,active_cells=act,
  active_share_of_eco=round(act/eco_cells,4),active_ha=act*cell^2/1e4,ic_implied_year0_Tg=round(ic_tg,2)),
  file.path(R,"build_summary.csv"))
cat("cell_m:", round(cell,1), "active cells:", act, "of eco cells", eco_cells, "IC implied Tg:", round(ic_tg,2), "\n")
' | tee build_r.log
# CellLength from the CSV, not the log: terra's progress bar leaves residue on the log line
# (first version of this script parsed the log and wrote an empty CellLength; caught before any run)
CELL=$(awk -F, 'NR==2{printf "%d", $2+0.5}' build_summary.csv)
case "$CELL" in ''|0|*[!0-9]*) echo "ERROR CellLength '$CELL' not a positive integer"; exit 4 ;; esac

sed 's/\r$//' "$IN/Daymet_${ST}_l3.csv" > climate.csv
cat > climate-generator.txt <<CG
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
echo 'SpeciesEcoregionDataFile  SppEcoregionData_fia.csv'
cat <<'FH'
FireReductionParameters
    1        0.0        0.5
    2        0.0        0.75
    3        0.5        1.0
HarvestReductionParameters
    PerseusBA50 0.5 0.15 0.5 0.0
FH
} > biomass_succession.txt

SPP=$(awk 'NF>=9 && $1 !~ /^>>/ && $1!="LandisData"{print $1}' species.txt)
{ echo 'LandisData  "Output Biomass"'; echo 'Timestep   5'; echo 'MakeTable  yes'
  first=1; for s in $SPP; do if [ $first = 1 ]; then echo "Species  $s"; first=0; else echo "         $s"; fi; done
  echo 'MapNames   output/biomass/biomass-{species}-{timestep}.tif'
  echo 'DeadPools  both'
  echo 'MapNames   output/biomass/biomass-{pool}-{timestep}.tif'; } > output_biomass.txt

cat > scenario.txt <<SCEN
LandisData  Scenario
Duration  $DUR
Species   ./species.txt
Ecoregions      ./ecoregions.txt
EcoregionsMap   ./ecoregions.tif
CellLength  $CELL
"Biomass Succession"  biomass_succession.txt
"Output Biomass"      output_biomass.txt
RandomNumberSeed   1234
SCEN

cat > submit.slurm <<SLX
#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=${ST}_smk8 --time=03:00:00
#SBATCH --nodes=1 --cpus-per-task=8 --mem=96G
#SBATCH --output=$R/slurm-%j.out --error=$R/slurm-%j.err
cd $R
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \\
  --bind $L/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \\
  --bind $L/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \\
  --bind $R:$R --pwd $R \\
  $SIF dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt
echo "LANDIS_EXIT=\$?"
SLX
echo "CellLength=$CELL built in $R"
if [ "$SUBMIT" = yes ]; then sbatch --parsable submit.slurm | tee jobid.txt; fi
