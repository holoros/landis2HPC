#!/bin/bash
#SBATCH --job-name=s41cf_ls2
#SBATCH --account=PUOM0008
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=32
#SBATCH --mem=120G
#SBATCH --time=02:00:00
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_fvsrecal/logs/s41cf_ls2_%j.out
# Step 2 LS: September FVS-LS frame projections (same runner logic, stands, seed, horizon, cycles, fm_frame pin).
# (a) the September binary (src-converted FVSls, July 10 build), calibrated arm only: reproduction.
# (b) the v1 FVSls binary that the session 41 recalibration was fitted and holdout tested on: calibrated and recal arms.
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_fvsrecal
for x in fvs_ls_july_b fvs_ls_v1_b; do [ -e "$D/$x" ] && { echo "ABORT: $D/$x exists"; exit 1; }; done
cd $D; md5sum -c MD5SUMS_s41cf_c.txt || exit 1
SH=/users/PUOM0008/crsfaaron/ncasi_fvsls/fm_frame
echo "ls.json md5 $(md5sum $SH/config/calibrated/ls.json | cut -c1-32) keyfile $(md5sum $SH/calibration/python/inventory_keyfile.py | cut -c1-32)"
COMMON="--fia-dir /users/PUOM0008/crsfaaron/fia_data --fvs-modern $SH --scenarios /users/PUOM0008/crsfaaron/ncasi_fvsls/ma_06_scenarios.yml \
  --states MI,WI,MN --n-per-state 300 --horizon 50 --workers 32 --seed 20260904 --scratch ${SLURM_TMPDIR:-/tmp} --frame-gate resolved \
  --scenario-ids no_harvest --s41-out-date 2026-10-16 --recal-pl 55 --recal-pu 95"
for spec in "fvs_ls_july_b:/users/PUOM0008/crsfaaron/fvs-modern/src-converted/bin/FVSls:calibrated" \
            "fvs_ls_v1_b:/users/PUOM0008/crsfaaron/fvs-modern/bin-v1_20260906/FVSls:calibrated,recal"; do
  IFS=: read x BIN ARMS <<< "$spec"
  mkdir -p $D/$x
  echo "### $x binary $BIN md5 $(md5sum $BIN | cut -c1-32) arms $ARMS"
  python3 s41cf_fvsls_runner_v2.py $COMMON --fvs-bin $BIN --outdir $D/$x --arms $ARMS \
    --recal MI:1.3:0.0075,WI:1.3:0.0100,MN:1.3:0.0125 > $D/$x/runner.log 2>&1
  echo "runner rc=$?"; grep -E "^S41|failed runs|total FVS runs" $D/$x/runner.log
  S=/users/PUOM0008/crsfaaron/ncasi_fvsls/out_20260907_frame
  python3 s41cf_fvscmp_v1.py $S/fvs-ls-stand-trajectories_DATA_2026-09-07.csv $S/fvs-ls-stand-inventory_DATA_2026-09-07.csv \
    $D/$x/fvs-ls-stand-trajectories_DATA_2026-10-16.csv $D/$x/fvs-ls-stand-inventory_DATA_2026-10-16.csv $D/s41cf_fvs_means_${x}_20261016.csv $x
done
md5sum $D/fvs_ls_*/*.csv $D/s41cf_fvs_means_fvs_ls_*.csv
