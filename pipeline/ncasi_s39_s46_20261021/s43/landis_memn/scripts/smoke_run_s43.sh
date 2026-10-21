#!/bin/bash
#SBATCH --account=PUOM0008 --time=03:00:00 --nodes=1 --cpus-per-task=8 --mem=96G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn/logs/smoke_%x_%j.out
# s43 Track A step 8: 10 yr anchored Biomass Succession smoke at 270 m for ME or MN, generalized from
# smoke_build_fb_20261001.sh (state as argument, everything written under s43/landis_memn/runs/<ST>/<RN>) and
# confirm_mi_20261015.sh (table multipliers ProbEstablish x PE, ANPPmax x A, BiomassMax x B on the source table,
# run copy filtered to the run's ecoregions). IC = anchored cohort_biomass_by_mapcode_fiadb.csv (s43 build).
# Climate: PRISM_<ST>_l3.csv normals (Biomass Succession v7 reads no climate in this configuration: s43 climtest, inert).
# Env: ST RN SRCT (source SppEcoregion table) A B PE ETAG
set -uo pipefail
L=/fs/scratch/PUOM0008/crsfaaron/landis2; T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn
IN=$L/states/$ST/inputs; BD=$T/build/$ST/initial_communities; B270=$T/runs/$ST/base270; R=$T/runs/$ST/$RN
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
mkdir -p $B270
if [ ! -s $B270/build_summary.csv ]; then
Rscript -e '
suppressMessages({library(terra); library(data.table)}); terraOptions(memfrac=0.6, progress=0)
B270<-"'"$B270"'"; ST<-"'"$ST"'"
e<-rast("'"$T/out/ecoregions_s43_${ST}_${ETAG}.tif"'"); ic<-rast("'"$BD/initial-communities.tif"'")
stopifnot(compareGeom(e,ic))
e270<-aggregate(e, fact=9, fun="modal", na.rm=TRUE); ic270<-resample(ic, e270, method="near")
ecos<-sort(unique(values(e270)[,1])); ecos<-ecos[!is.na(ecos) & ecos>0]
cb<-fread("'"$BD/cohort_biomass_by_mapcode_fiadb.csv"'"); mc<-unique(cb$MapCode)
eco_cells<-global(e270>0,"sum",na.rm=TRUE)[1,1]
e270<-classify(e270, cbind(NA,0)); ic270<-classify(ic270, cbind(NA,0)); ic270[!(values(ic270) %in% mc)]<-0
mask<-(e270>0)&(ic270>0)
writeRaster(ifel(mask,e270,0), file.path(B270,"ecoregions.tif"), overwrite=TRUE, datatype="INT4S", NAflag=0)
writeRaster(ifel(mask,ic270,0), file.path(B270,"initial-communities.tif"), overwrite=TRUE, datatype="INT4S", NAflag=0)
act<-global(mask,"sum",na.rm=TRUE)[1,1]; cell<-res(e270)[1]
fr<-as.data.table(freq(ifel(mask,ic270,NA))); setnames(fr,c("layer","MapCode","n"))
v<-merge(fr, cb[,.(g=sum(CohortBiomass)),by=MapCode], by="MapCode", all.x=TRUE); v[is.na(g),g:=0]
ic_tg<-v[,sum(n*cell^2*g)]/1e12
fwrite(as.data.table(freq(ifel(mask,e270,NA)))[,.(eco=value,cells=count)], file.path(B270,"active_cells_by_ecoregion.csv"))
fwrite(data.table(state=ST,cell_m=round(cell,1),eco_cells_270=eco_cells,active_cells=act,active_share_of_eco=round(act/eco_cells,4),
  active_ha=act*cell^2/1e4,ic_implied_year0_Tg=round(ic_tg,3)), file.path(B270,"build_summary.csv"))
cat("cell", cell, "active", act, "IC implied Tg", ic_tg, "\n")'
fi
cat $B270/build_summary.csv
[ -e "$R/Landis-log.txt" ] && { echo "SKIP $R exists"; exit 0; }
mkdir -p $R/output/biomass; cd $R
cp $IN/species.txt species.txt; cp $IN/SpeciesData.csv SpeciesData.csv
cp $B270/ecoregions.tif $B270/initial-communities.tif $B270/build_summary.csv .
cp $BD/cohort_biomass_by_mapcode_fiadb.csv initial-communities.csv
ECOS=$(awk -F, 'NR>1{print $1}' $B270/active_cells_by_ecoregion.csv | tr '\n' ' ')
awk -F, -v E="$ECOS" -v b="$B" -v a="$A" -v pe="$PE" 'BEGIN{OFS=","; n=split(E,x," "); for(i=1;i<=n;i++) k[x[i]]=1}
  NR==1{print; next} ($2 in k){$4=$4*pe; $6=int($6*a+0.5); $7=int($7*b+0.5); print}' "$SRCT" > SppEcoregionData_fia.csv
awk -v E="$ECOS" 'BEGIN{n=split(E,x," "); for(i=1;i<=n;i++) k[x[i]]=1} ($1!="yes") || ($2 in k)' $IN/ecoregions.txt > ecoregions.txt
echo "$ST $RN table=$SRCT md5=$(md5sum < $SRCT | cut -c1-8) anpp=$A bmx=$B pe=$PE ecos=$ECOS rows=$(($(wc -l < SppEcoregionData_fia.csv)-1))" | tee RUN_SPEC.txt
sed 's/\r$//' $IN/PRISM_${ST}_l3.csv > climate.csv
printf 'LandisData "Climate Config"\nClimateTimeSeries          Monthly_AverageAllYears\nClimateFile                climate.csv\nSpinUpClimateTimeSeries    Monthly_AverageAllYears\nSpinUpClimateFile          climate.csv\nGenerateClimateOutputFiles no\nUsingFireClimate           no\n' > climate-generator.txt
{
echo 'LandisData "Biomass Succession"'; echo 'Timestep 5'; echo 'SeedingAlgorithm WardSeedDispersal'
echo 'InitialCommunities       initial-communities.csv'; echo 'InitialCommunitiesMap    initial-communities.tif'
echo 'ClimateConfigFile        climate-generator.txt'; echo 'MinRelativeBiomass'
printf '        '; for e in $ECOS; do printf '%s ' "$e"; done; echo
for pct in 20 40 60 80 100; do sh=$((pct/20)); printf '    %d  ' "$sh"; for e in $ECOS; do printf '%s%% ' "$pct"; done; echo; done
printf 'SufficientLight\n    1   1.0  0.5  0.0  0.0  0.0  0.0\n    2   1.0  1.0  0.5  0.0  0.0  0.0\n    3   1.0  1.0  1.0  0.5  0.0  0.0\n    4   1.0  1.0  1.0  1.0  0.5  0.0\n    5   1.0  1.0  1.0  1.0  1.0  0.5\n'
echo 'SpeciesDataFile        SpeciesData.csv'; echo 'EcoregionParameters'; echo '>>  AET (mm)'
for e in $ECOS; do echo "$e   600"; done
echo 'SpeciesEcoregionDataFile  SppEcoregionData_fia.csv'
printf 'FireReductionParameters\n    1        0.0        0.5\n    2        0.0        0.75\n    3        0.5        1.0\nHarvestReductionParameters\n    PerseusBA50 0.5 0.15 0.5 0.0\n'
} > biomass_succession.txt
SPP=$(awk 'NF>=9 && $1 !~ /^>>/ && $1!="LandisData"{print $1}' species.txt)
{ echo 'LandisData  "Output Biomass"'; echo 'Timestep   5'; echo 'MakeTable  yes'
  first=1; for s in $SPP; do if [ $first = 1 ]; then echo "Species  $s"; first=0; else echo "         $s"; fi; done
  echo 'MapNames   output/biomass/biomass-{species}-{timestep}.tif'; echo 'DeadPools  both'
  echo 'MapNames   output/biomass/biomass-{pool}-{timestep}.tif'; } > output_biomass.txt
CELL=$(awk -F, 'NR==2{printf "%d", $2+0.5}' build_summary.csv)
printf 'LandisData  Scenario\nDuration  10\nSpecies   ./species.txt\nEcoregions      ./ecoregions.txt\nEcoregionsMap   ./ecoregions.tif\nCellLength  %s\n"Biomass Succession"  biomass_succession.txt\n"Output Biomass"      output_biomass.txt\nRandomNumberSeed   1234\n' $CELL > scenario.txt
apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
  --bind $L/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \
  --bind $L/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \
  --bind $R:$R --pwd $R $L/images/landis-ii_v8_allext_v1.0.sif dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > landis_stdout.txt 2>&1
echo "$ST $RN LANDIS_EXIT=$? complete=$(grep -c 'Model run is complete' Landis-log.txt) $(date +%T)"
