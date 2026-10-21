#!/bin/bash
#SBATCH --account=PUOM0008 --time=01:30:00 --nodes=1 --cpus-per-task=4 --mem=200G --job-name=s43G_aspen
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn_fit/logs/aspen_%x_%j.out
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
echo md5 $(md5sum < /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn_fit/scripts/aspen_diag_G.R | cut -c1-8)
Rscript /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/landis_memn_fit/scripts/aspen_diag_G.R $ST
