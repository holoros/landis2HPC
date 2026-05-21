#!/bin/bash
#SBATCH --job-name=GA_t0
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=12:00:00
#SBATCH --output=/users/PUOM0008/crsfaaron/GA_t0_%j.out
#SBATCH --error=/users/PUOM0008/crsfaaron/GA_t0_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=aaron.weiskittel@maine.edu

set -uo pipefail
TOOLS=/users/PUOM0008/crsfaaron/landis2/scratch/tools
module purge
module load gcc/12.3.0 gdal/3.7.3 python/3.12

echo "=== GA Tier 0 sweep started $(date) on $(hostname) ==="
bash $TOOLS/run_param_set_GA_t0.sh GA_t0
echo "=== GA Tier 0 sweep finished $(date) ==="
