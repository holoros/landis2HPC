#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s43G_ic --time=05:00:00 --nodes=1 --cpus-per-task=4 --mem=240G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn_fit/logs/build_ic_%x_%j.out
# s43 Track A step 4: patched builder (build_ic_v3_drybio_s43_fsta.R) for one state. Usage: sbatch --export=ST=ME build_ic_s43.slurm
# Tree input: TreeMap 2022 CONUS tree table fallback (--tree points to a nonexistent path on purpose, both states alike).
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn_fit; L=/fs/scratch/PUOM0008/crsfaaron/landis2/states
mkdir -p $T/build/$ST
echo "builder md5 $(md5sum < $T/scripts/build_ic_v3_drybio_s43_fsta.R | cut -c1-8) lookup md5 $(md5sum < $T/out/species_lookup_${ST}_s43.R | cut -c1-8) TM md5 $(md5sum < $L/$ST/inputs/${ST}_TM_22.tif | cut -c1-8)"
Rscript $T/scripts/build_ic_v3_drybio_s43_fsta.R --state $ST --treemap $L/$ST/inputs/${ST}_TM_22.tif \
  --tree $T/build/NO_STATE_TREE_CSV_use_fallback.csv --cond /users/PUOM0008/crsfaaron/fia_data/${ST}_COND.csv \
  --lookup $T/out/species_lookup_${ST}_s43.R --out $T/build/$ST
echo "BUILDER_EXIT=$?"
