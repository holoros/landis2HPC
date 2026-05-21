#!/bin/bash
#SBATCH --job-name=cma_es_t2
#SBATCH --account=PUOM0008
#SBATCH --partition=batch
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=13:00:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/landis2/states/ME/perseus/bayesian/_driver_t2/slurm_%j.out
#SBATCH --error=/fs/scratch/PUOM0008/crsfaaron/landis2/states/ME/perseus/bayesian/_driver_t2/slurm_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=aaron.weiskittel@maine.edu
#
# Tier 2 CMA-ES driver as a long-running single-CPU SLURM job. The driver
# itself submits and waits on 1,219-plot LANDIS arrays per candidate
# evaluation, so it must persist for the full sweep (estimated 24-48 hours
# wall clock at full population). The 72-hour wall is conservative padding.

set -euo pipefail

TOOLS=/users/PUOM0008/crsfaaron/landis2/scratch/tools
BAY=/fs/scratch/PUOM0008/crsfaaron/landis2/states/ME/perseus/bayesian
DRV=$BAY/_driver_t2

mkdir -p "$DRV"

# Module stack: python/3.12 has compatible numpy+pandas+scipy for cma;
# gcc + gdal needed for gdalinfo CLI used by the runner's aggregation block.
module purge
module load gcc/12.3.0
module load gdal/3.7.3
module load python/3.12

# Pick up pip --user installs (python/3.12 user site is separate from 3.9)
export PATH=$HOME/.local/bin:$PATH
export PYTHONUSERBASE=$HOME/.local

echo "=== SLURM job started $(date) on $(hostname) ==="
echo "JobID: $SLURM_JOB_ID  Node: $SLURM_NODELIST"
echo "python: $(which python3) $(python3 --version)"
echo "gdalinfo: $(which gdalinfo)"
module list 2>&1

python3 -c "import cma; print('cma', cma.__version__)" || {
    echo "ERROR: cma not importable under python/3.12. Install with:"
    echo "  module load python/3.12 && pip install --user cma"
    exit 2
}

cd "$DRV"

# Seed at log(1.30) = 0.2624 — best uniform Tier 1 point per session 12.
# Phase 1: 5 iterations to fit before May 12 maintenance window.
# Checkpoint at $DRV/es.pickle lets a second submit resume for more iters.
python3 $TOOLS/cma_es_optimize_cardinal.py \
    --max-iter 5 \
    --population 12 \
    --sigma0 0.15 \
    --x0-uniform 0.2624 \
    --tag-prefix t2 \
    --tools-dir "$TOOLS" \
    --bayesian-dir "$BAY"

echo "=== SLURM job finished $(date) ==="
