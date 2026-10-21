#!/bin/bash
# usage: null_state.sh ST ; runs shifts 0, 1, 2 for one state
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/scripts
for SH in 0 1 2; do
  python -u L2_null_replay.py $1 /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn/out/L2/$1 /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/null_shift$SH $SH > /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/logs/null_$1_s$SH.log 2>&1
  echo $1 shift $SH rc=$?
done
