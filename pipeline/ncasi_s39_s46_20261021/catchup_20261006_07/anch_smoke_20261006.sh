#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s35_anch --time=02:00:00
#SBATCH --nodes=1 --cpus-per-task=8 --mem=96G
#SBATCH --output=/users/PUOM0008/crsfaaron/s34/anch_%j.out
# Session 35, 6 Oct 2026. Diagnostic for decisions 2 and 3. Decides neither, promotes nothing.
# Reruns the 1 Oct unit corrected 10 year smoke for NH VT MI WI with ONE change: CohortBiomass in the
# RUN COPY of the IC table is scaled to the 2024 FIADB live AGB total, the same uniform multiplier
# anchor_ic_to_fiadb.R applies (round, pmax 1). The scale is computed here from
# gates/fiadb_live_agb_fourstate_20261001.csv and the unit fix run's own year zero map total, not
# taken from a handoff. Parameters stay the FIA 20260929 table (baseline, as the 1 Oct smoke).
set -uo pipefail
L=/fs/scratch/PUOM0008/crsfaaron/landis2; D=$L/states_fb_20260930
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
for ST in NH VT MI WI; do
  SRC=$D/$ST/runs/smoke_20261001_d10_unitfix
  R=$D/$ST/runs/smoke_20261006_d10_unitfix_anch
  [ -e "$R" ] && { echo "ERROR $R exists, refusing to overwrite"; continue; }
  mkdir -p "$R/output/biomass"
  for f in scenario.txt biomass_succession.txt climate.csv climate-generator.txt species.txt SpeciesData.csv \
           ecoregions.txt ecoregions.tif initial-communities.tif output_biomass.txt SppEcoregionData_fia.csv \
           build_summary.csv; do cp "$SRC/$f" "$R/$f"; done
  Rscript - "$SRC" "$R" "$ST" "$D/gates/fiadb_live_agb_fourstate_20261001.csv" <<'RS'
suppressMessages({library(terra); library(data.table)})
a <- commandArgs(TRUE); SRC <- a[1]; R <- a[2]; ST <- a[3]
cell <- fread(file.path(SRC, "build_summary.csv"))$cell_m
t0 <- sum(values(rast(file.path(SRC, "output/biomass/biomass-TotalBiomass-0.tif")))[, 1], na.rm = TRUE) * cell^2 / 1e12
ref <- fread(a[4])[state == ST, fiadb_live_agb_Tg]
stopifnot(length(ref) == 1, ref > 0, t0 > 0)
sc <- ref / t0
if (sc < 1 || sc > 2) stop(sprintf("scale %.3f outside 1 to 2; expected about 1.26 to 1.49", sc))
cb <- fread(file.path(SRC, "initial-communities.csv"))
cb[, CohortBiomass := pmax(1L, as.integer(round(CohortBiomass * sc)))]
fwrite(cb, file.path(R, "initial-communities.csv"))
fwrite(data.table(state = ST, unitfix_t0_Tg = t0, fiadb_Tg = ref, scale = sc), file.path(R, "anchor_scale.csv"))
cat(ST, "unitfix t0", round(t0, 2), "FIADB", ref, "scale", round(sc, 4), "\n")
RS
  [ -f "$R/anchor_scale.csv" ] || { echo "ERROR $ST scaling failed"; continue; }
  cd "$R"
  apptainer exec --bind /fs/scratch/PUOM0008:/fs/scratch/PUOM0008 \
    --bind $L/patches/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \
    --bind $L/patches/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \
    --bind $R:$R --pwd $R \
    $L/images/landis-ii_v8_allext_v1.0.sif dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt > landis_stdout.txt 2>&1
  echo "$ST LANDIS_EXIT=$? complete=$(grep -c 'Model run is complete' Landis-log.txt)"
done
Rscript $D/scripts_20261001/anch_diag_20261006.R
echo "DIAG_EXIT=$?"
echo ALLDONE
