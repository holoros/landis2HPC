#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=cemhind
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=240G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cem/logs/%x_%j.log
# Usage: sbatch --export=ALL,ARCH=<archive dir name>,STATES="ME NH VT" run_cem_hind_20261015.slurm
set -u
W=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cem
A=/fs/scratch/PUOM0008/crsfaaron/cem_per_plot_archive
cd $W
md5sum -c md5_expected.txt || { echo "MD5 MISMATCH, abort"; exit 1; }
module load gcc/12.3.0 R/4.4.0 proj/9.2.1 gdal/3.7.3 geos/3.12.0
export R_LIBS="${HOME}/R/cardinal_libs/4.4.0:${HOME}/R/cardinal_libs:${HOME}/R/x86_64-pc-linux-gnu-library/4.4"
unset R_LIBS_USER
export FIA_CEM_DIR=$W/run
mkdir -p $FIA_CEM_DIR
echo "### COMPOSITION $ARCH"
Rscript archive_composition_20261015.R $A/$ARCH $W/out/composition_${ARCH}.csv
for st in $STATES; do
  echo "############ RUN $st from $ARCH ############"
  Rscript hindcast_cem_gates_20261015.R --state $st --archive $ARCH \
     --fia_dir $HOME/fia_data --out_dir $A 2>&1 | grep -v -E "^\s+(Ncells|Vcells|used)"
done
echo ALL_RUNS_DONE
