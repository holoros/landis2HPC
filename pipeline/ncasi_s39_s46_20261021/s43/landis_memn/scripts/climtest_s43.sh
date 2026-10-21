#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s43A_clim --time=01:30:00 --nodes=1 --cpus-per-task=8 --mem=48G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn/logs/climtest_%j.out
# s43 Track A step 7: does Biomass Succession v7 (smoke configuration) read the climate table?
# Copies the VT confirmation run inputs (read only source) and reruns: ctrl (identical climate) and pert
# (all temperatures +5 C, precip x0.5). Compares TotalBiomass and ANPP rasters at years 5 and 10.
set -uo pipefail
L=/fs/scratch/PUOM0008/crsfaaron/landis2; SRC=$L/states_fb_20260930/VT/runs/fit_20261015_d10_confirm_a2.30_b2.90_r2
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn/climtest
for v in ctrl pert; do R=$T/$v; rm -rf $R; mkdir -p $R/output/biomass
 for f in scenario.txt biomass_succession.txt climate.csv climate-generator.txt species.txt SpeciesData.csv ecoregions.txt ecoregions.tif initial-communities.tif initial-communities.csv output_biomass.txt build_summary.csv SppEcoregionData_fia.csv; do cp $SRC/$f $R/$f; done
done
awk -F, 'BEGIN{OFS=","} NR==1{print;next} {if($3 ~ /temp/){for(i=4;i<=NF;i++)$i=$i+5} else if($3 ~ /precip/){for(i=4;i<=NF;i++)$i=$i*0.5}; print}' $SRC/climate.csv > $T/pert/climate.csv
echo "climate md5 src $(md5sum < $SRC/climate.csv|cut -c1-8) ctrl $(md5sum < $T/ctrl/climate.csv|cut -c1-8) pert $(md5sum < $T/pert/climate.csv|cut -c1-8)"
awk -F, 'NR>1{print $3}' $SRC/climate.csv | sort | uniq -c
for v in ctrl pert; do R=$T/$v; cd $R
 apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
  --bind $L/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \
  --bind $L/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \
  --bind $R:$R --pwd $R $L/images/landis-ii_v8_allext_v1.0.sif dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > landis_stdout.txt 2>&1
 echo "$v LANDIS_EXIT=$? complete=$(grep -c 'Model run is complete' Landis-log.txt)"; done
for f in output/biomass/biomass-TotalBiomass-5.tif output/biomass/biomass-TotalBiomass-10.tif "biomass-succession\\biomass-anpp-5.tif" "biomass-succession\\biomass-anpp-10.tif" Biomass-succession-log.csv; do
 echo "$f src $(md5sum < "$SRC/$f"|cut -c1-8) ctrl $(md5sum < "$T/ctrl/$f"|cut -c1-8) pert $(md5sum < "$T/pert/$f"|cut -c1-8)"; done
grep -i "climate" $T/pert/Landis-log.txt | head -8 | cut -c1-200
