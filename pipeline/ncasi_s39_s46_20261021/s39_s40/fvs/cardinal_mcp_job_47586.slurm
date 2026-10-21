#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=fvsgate_find2
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task=2
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs/find2_%j.log
L=/fs/scratch/PUOM0008/crsfaaron/landis2
echo "== who writes fia_gg / behav_bins"
grep -rl --include=*.R --include=*.py --include=*.sh -e "behav_bins" -e "fia_gg" $L 2>/dev/null | head
ls -la ~/fvs-modern/calibration/python/ | head -60
echo "== nsvb in ne grinit"
grep -n -i "nsvb" ~/fvs-modern/src-converted/ne/grinit.f90 | head -20
grep -rn -i "nsvb" ~/fvs-modern/calibration/PROJECT_STATUS.md | head -10
cat ~/fvs-modern/calibration/analysis/acd_stand_level_2026-05-16/nsvb_runtime_ab/README.md | head -60
echo "== python env"
python3 -c "import pandas, numpy; print('pandas', pandas.__version__)" 2>&1
module purge; module load R/4.5.2 2>&1|tail -2; which Rscript; Rscript -e 'for(p in c("data.table","rFIA","RSQLite")) cat(p, requireNamespace(p, quietly=TRUE), "\n")' 2>&1
echo "== datamart ME/NH/VT/MI/WI/MN"
ls -la /fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006/ | grep -E "^.* (ME|NH|VT|MI|WI|MN)_"
head -c 3000 /fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006/NH_TREE.csv | head -2
head -2 /fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006/NH_COND.csv
head -1 /fs/scratch/PUOM0008/crsfaaron/fia_datamart_20261006/NH_PLOT.csv

