#!/bin/bash
#SBATCH --job-name=fvs_refit_constrained
#SBATCH --time=04:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=4
#SBATCH --account=PUOM0008
#SBATCH --output=/users/PUOM0008/crsfaaron/fvs-modern/calibration/refit_constrained/slurm_%j.out
#SBATCH --error=/users/PUOM0008/crsfaaron/fvs-modern/calibration/refit_constrained/slurm_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=aaron.weiskittel@maine.edu

set -e
mkdir -p /users/PUOM0008/crsfaaron/fvs-modern/calibration/refit_constrained
cd       /users/PUOM0008/crsfaaron/fvs-modern/calibration/refit_constrained

module load gcc/12.3.0
module load gdal/3.7.3
module load geos/3.12.0
module load proj/9.2.1
module load R/4.4.0

# Confirm minpack.lm and terra are installed; install if missing.
Rscript -e '
need <- c("minpack.lm", "terra", "data.table")
miss <- setdiff(need, rownames(installed.packages()))
if (length(miss)) {
  install.packages(miss, repos = "https://cloud.r-project.org",
                   Ncpus = as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", 1)))
}
'

Rscript --vanilla /users/PUOM0008/crsfaaron/fvs-modern/calibration/refit_constrained/refit_cardinal.R
