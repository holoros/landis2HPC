#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s45kB
#SBATCH --array=0-14
#SBATCH --time=01:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=48G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor/logs/%x_%A_%a.log
# s45 Track K (post unblinding follow-on, not gate eligible): donor table build (tasks 0-13) and unit tests (task 14).
set -u
T=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor
cd $T
module purge
module load gcc/12.3.0 R/4.5.2
ST14=(ME NH VT MI WI MN NY MA CT RI IA IL OH IN)
i=$SLURM_ARRAY_TASK_ID
md5sum nd_build_donor_s45.R nd_unit_tests_s45.R engine_k/R/16_netdonor_fns.R
if [ $i -lt 14 ]; then Rscript nd_build_donor_s45.R ${ST14[$i]} 2>&1 | grep -v -E "PLT_CN|LAT|LON"; else Rscript nd_unit_tests_s45.R; fi

