#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=fvsgate_find
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=2
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs/find_%j.log
cd ~
echo "== nsvb files (names)"
find ~ /fs/scratch/PUOM0008/crsfaaron -maxdepth 5 -iname "*nsvb*" 2>/dev/null | grep -v apptainer | head -60
echo "== grep NSVB in fvs-modern src (f90 names)"
grep -rli "nsvb" ~/fvs-modern/src-converted --include=*.f90 2>/dev/null | head -20
grep -rli "nsvb" ~/fvs-modern/calibration ~/fvs-modern/scripts ~/fvs-modern/tools 2>/dev/null | head -20
echo "== ncasi_fvsne / ncasi_fvsls"
ls ~/ncasi_fvsne ~/ncasi_fvsls | head -80
echo "== fia_data"
ls -la ~/fia_data | head
ls -la /fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006/ | head -60
echo "== gates"
ls -la /fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/gates/
cat /fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/gates/behav_bins_20261015.csv
cat /fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/gates/grm_realism_fourstate_20261006.csv
echo "== scripts writing behav_bins"
grep -l "behav_bins" /fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/gates/* /fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/*.R /fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/*.py 2>/dev/null
module load gcc/12.3.0 gdal/3.7.3 geos/3.12.0 proj/9.2.1 R/4.4.0 2>&1 | tail -2
which Rscript python3; python3 -c "import pandas, numpy; print(pandas.__version__)"
Rscript -e 'for(p in c("data.table","rFIA","RSQLite")) cat(p, requireNamespace(p, quietly=TRUE), "\n")'

