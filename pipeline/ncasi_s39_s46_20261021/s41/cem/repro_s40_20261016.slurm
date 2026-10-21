#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=s41cemrepro
#SBATCH --time=03:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=240G
#SBATCH --array=0-1
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem/logs/%x_%A_%a.log
# s41 reproduction of the s40 hindcast scorer (verbatim s40 script, md5 checked).
set -u
W=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem
S40=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cem
A=/fs/scratch/PUOM0008/crsfaaron/cem_per_plot_archive
cd $W
md5sum repro_s40_20261016.slurm
cp -p $S40/hindcast_cem_gates_20261015.R $W/hindcast_cem_gates_20261015_s40copy.R
( cd $S40 && md5sum -c md5_expected.txt ) || { echo "S40 MD5 MISMATCH"; exit 1; }
md5sum $S40/hindcast_cem_gates_20261015.R $W/hindcast_cem_gates_20261015_s40copy.R
module purge
module load gcc/12.3.0 R/4.5.2
export FIA_CEM_DIR=$W/repro_run_${SLURM_ARRAY_TASK_ID}
mkdir -p $FIA_CEM_DIR
if [ "$SLURM_ARRAY_TASK_ID" = "0" ]; then ARCH=ME_20260520_rcp45_hadgem2_wear_econ_l7b; STATES="ME NH"; else ARCH=MN_20260520_rcp45_wear_l7b; STATES="MN"; fi
for st in $STATES; do
  echo "############ RUN $st from $ARCH ############"
  Rscript $W/hindcast_cem_gates_20261015_s40copy.R --state $st --archive $ARCH \
     --fia_dir $HOME/fia_data --out_dir $A 2>&1 | grep -E "^(SUMMARY|ANCHOR|Subject plot count|RMSE|Error|  [0-9]+ rows|  After)"
done
echo ALL_RUNS_DONE
