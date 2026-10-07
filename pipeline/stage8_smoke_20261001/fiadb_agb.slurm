#!/bin/bash
#SBATCH --job-name=fiadb_agb4 --account=PUOM0008 --time=00:45:00
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=2 --mem=32G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/scripts_20261001/fiadb_agb4_%j.out
module load gcc/12.3.0 R/4.4.0 >/dev/null 2>&1
Rscript /fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/scripts_20261001/fiadb_live_agb_fourstate_20261001.R

