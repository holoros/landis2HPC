#!/bin/bash
#SBATCH --account=PUOM0008 --job-name=s46_miwi_sc --time=01:00:00 --nodes=1 --cpus-per-task=4 --mem=48G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/landis_miwi_promote/logs/score_%x_%j.out
S=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/landis_miwi_promote/scripts/score_miwi_s46.R
[ "$(md5sum $S | cut -c1-32)" = "649d922954cdcd968b6fde2c1c7f8c42" ] || { echo MD5_MISMATCH; exit 3; }
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
echo "TAG=$TAG GRID=$GRID"; Rscript $S; echo EXIT=$?
