#!/bin/bash
#SBATCH --account=PUOM0008 --time=02:00:00 --nodes=1 --cpus-per-task=4 --mem=200G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn/logs/preanchor_%x_%j.out
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
Rscript /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn/scripts/preanchor_gates_anchor_s43.R $ST $ETAG
