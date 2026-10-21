#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=osmexpc
#SBATCH --ntasks=1 --cpus-per-task=2 --mem=8G --time=00:20:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm/osmexpc_%j.log
bash /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm/osm_explore_c.sh

