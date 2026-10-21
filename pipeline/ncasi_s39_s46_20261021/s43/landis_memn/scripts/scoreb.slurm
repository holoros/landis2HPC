#!/bin/bash
#SBATCH --account=PUOM0008 --time=01:30:00 --nodes=1 --cpus-per-task=4 --mem=120G --job-name=s43A_score
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn/logs/score_%j.out
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
Rscript /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn/scripts/score_memn_s43b.R $TAG
