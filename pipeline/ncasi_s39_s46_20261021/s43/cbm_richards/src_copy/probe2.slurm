#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s43b_probe2
#SBATCH -t 00:20:00
#SBATCH -n 1
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver/logs/probe2_%j.out
find ~ /fs/scratch/PUOM0008/crsfaaron -maxdepth 6 \( -iname "*us_state*" -o -iname "*states*.shp" -o -iname "*states*.gpkg" -o -iname "tl_*state*" -o -iname "*state_bound*" \) 2>/dev/null | grep -v "/cbm_states/states/" | head -30
module load gcc/12.3.0 R/4.5.2
Rscript -e 'for(p in c("terra","sf","tigris","lme4","nlme","foreign")) cat(p, requireNamespace(p, quietly=TRUE), "\n")'
