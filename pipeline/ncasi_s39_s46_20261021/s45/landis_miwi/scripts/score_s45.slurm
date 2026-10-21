#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s45_miwi_sc --time=01:00:00 --nodes=1 --cpus-per-task=4 --mem=48G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/landis_miwi/logs/score_%x_%j.out
# Usage: sbatch --export=ALL,TAG=<tag>,GRID=<grid csv> [--dependency=afterok:<job>] score_s45.slurm
S=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/landis_miwi/scripts/score_miwi_s45.R
[ "$(md5sum $S | cut -c1-32)" = "82d04cb072e79a99f6f704899dfbb0cd" ] || { echo MD5_MISMATCH; exit 3; }
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
echo "TAG=$TAG GRID=$GRID"; Rscript $S; echo EXIT=$?
