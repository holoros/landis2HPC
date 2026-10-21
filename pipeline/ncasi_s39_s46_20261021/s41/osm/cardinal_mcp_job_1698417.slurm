#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=osmexpd
#SBATCH --ntasks=1 --cpus-per-task=2 --mem=8G --time=00:10:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm/osmexpd_%j.log
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm
echo "72c7e135686a3bc69fcf76342f7155b2  osm_explore_d.py" | md5sum -c - || exit 3
python3 osm_explore_d.py

