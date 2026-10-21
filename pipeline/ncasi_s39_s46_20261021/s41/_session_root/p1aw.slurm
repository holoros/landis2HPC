#!/bin/bash
#SBATCH --job-name=p1aw
#SBATCH --account=PUOM0008
#SBATCH --time=00:10:00
#SBATCH --ntasks=1
#SBATCH --mem=4G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/p1aw_%j.log
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41
cd $D
md5sum p1-carbon-2x2-areaweighted_2026-10-16.R oct-figure-values_DATA_2026-10-15.csv fia-forest-area-sixstate_DATA_2026-10-15.csv
module purge; module load gcc/12.3.0 R/4.5.2
Rscript p1-carbon-2x2-areaweighted_2026-10-16.R $D $D
