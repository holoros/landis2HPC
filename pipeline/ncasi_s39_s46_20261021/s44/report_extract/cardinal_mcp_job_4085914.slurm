#!/bin/bash
#SBATCH --account=PUOM0008
#SBATCH --job-name=rpt_find
#SBATCH --time=00:20:00
#SBATCH --ntasks=1
#SBATCH --mem=2G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s44/report_extract/find_%j.log
O=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s44/report_extract
S=/fs/scratch/PUOM0008/crsfaaron
find $S/ncasi_gates_20261015 \( -name '*.csv' -o -name '*.md' -o -name '*.txt' -o -name '*.json' \) -size -5M -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null | grep -v '/work/' | grep -v '/runs/' | sort -k3 > $O/files_gates.txt
for d in $S/landis2 $S/landis-stage8-20261003 $HOME; do
 find $d -maxdepth 6 \( -iname '*gate*' -o -iname '*score*' -o -iname '*ratio*' -o -iname '*behav*' -o -iname '*summary*' \) \( -name '*.csv' -o -name '*.md' -o -name '*.txt' \) -size -5M -printf '%TY-%Tm-%Td %TH:%TM %s %p\n' 2>/dev/null
done | sort -k4 > $O/files_other.txt
wc -l $O/files_gates.txt $O/files_other.txt

