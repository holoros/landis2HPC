#!/bin/bash
#SBATCH --job-name=eco_v3_eval
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --time=02:00:00
#SBATCH --output=/users/PUOM0008/crsfaaron/eco_v3_%j.out
#SBATCH --error=/users/PUOM0008/crsfaaron/eco_v3_%j.err
#
# Tier 1.5 eco_v3 evaluation: eco82 = 1.50 (vs eco_v2's 1.45) with eco58, eco59
# held fixed at 1.15, 1.20. Tests whether the per-ecoregion optimum for the
# Acadian Plains spruce-fir matrix is above the eco_v2 value.

set -euo pipefail

TOOLS=/users/PUOM0008/crsfaaron/landis2/scratch/tools
module purge
module load gcc/12.3.0 gdal/3.7.3 python/3.12

echo "=== eco_v3 evaluation started $(date) on $(hostname) ==="
bash $TOOLS/run_param_set_eco_t2.sh $TOOLS/theta_eco_v3.csv eco_v3
echo "=== eco_v3 evaluation finished $(date) ==="
