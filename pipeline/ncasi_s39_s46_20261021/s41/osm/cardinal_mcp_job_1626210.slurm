#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=osmexp
#SBATCH --ntasks=1 --cpus-per-task=2 --mem=8G --time=00:15:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm/osmexp_%j.log
bash /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm/osm_explore_a.sh

