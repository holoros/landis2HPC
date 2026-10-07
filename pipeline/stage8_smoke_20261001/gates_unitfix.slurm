#!/bin/bash
#SBATCH --job-name=smk8_gates --account=PUOM0008 --time=00:30:00
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=2 --mem=32G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/scripts_20261001/smk8_gatesUF_%j.out
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 >/dev/null 2>&1
Rscript /fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/scripts_20261001/smoke_gates_fb_20261001.R smoke_20261001_d10_unitfix

