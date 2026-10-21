#!/bin/bash
#SBATCH --job-name=s41cf_ne
#SBATCH --account=PUOM0008
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=24
#SBATCH --mem=96G
#SBATCH --time=02:00:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_fvsrecal/logs/s41cf_ne_%j.out
# Step 2 NE: September FVS-NE frame projections (same runner logic, stands, seed 20260904, 50 yr, 5 yr cycles,
# same v1 FVSne binary and v1tag config tree), no_harvest only, arms calibrated (reproduction) and recal.
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_fvsrecal
O=$D/fvs_ne
[ -e "$O" ] && { echo "ABORT: $O exists"; exit 1; }
cd $D; md5sum -c MD5SUMS_s41cf_a.txt || exit 1
W=/fs/scratch/PUOM0008/crsfaaron/v1tag_20260811
K=/users/PUOM0008/crsfaaron/fvs-modern/calibration/python
BIN=/users/PUOM0008/crsfaaron/fvs-modern/bin-v1_20260906/FVSne
echo "binary md5 $(md5sum $BIN | cut -c1-32) tree $(git -C $W rev-parse --short HEAD) keyfile $(md5sum $K/inventory_keyfile.py | cut -c1-32)"
mkdir -p $O
python3 s41cf_fvsne_runner_v1.py --fia-dir /users/PUOM0008/crsfaaron/fia_data --fvs-modern $W --keyfile-module-dir $K --fvs-bin $BIN \
  --scenarios /users/PUOM0008/crsfaaron/ncasi_fvsne/ma_06_scenarios.yml --outdir $O \
  --prior-inventory /users/PUOM0008/crsfaaron/ncasi_fvsne/out_20260907_frame/fvs-ne-stand-inventory_DATA_2026-09-07.csv \
  --frame-gate resolved --states ME,NH,VT --n-per-state 300 --horizon 50 --workers 24 --seed 20260904 --scratch ${SLURM_TMPDIR:-/tmp} \
  --out-date 2026-10-16 --arms calibrated,recal --scenario-ids no_harvest --recal ME:1.3:0.0100,NH:1.3:0.0100,VT:1.3:0.0100 \
  --recal-pl 55 --recal-pu 95 > $O/runner.log 2>&1
echo "runner rc=$?"
grep -E "^S41|stand set identity|failed runs|total FVS runs" $O/runner.log
S=/users/PUOM0008/crsfaaron/ncasi_fvsne/out_20260907_frame
python3 s41cf_fvscmp_v1.py $S/fvs-ne-stand-trajectories_DATA_2026-09-07.csv $S/fvs-ne-stand-inventory_DATA_2026-09-07.csv \
  $O/fvs-ne-stand-trajectories_DATA_2026-10-16.csv $O/fvs-ne-stand-inventory_DATA_2026-10-16.csv $D/s41cf_fvs_means_ne_20261016.csv ne_v1
md5sum $O/*.csv $D/s41cf_fvs_means_ne_20261016.csv
