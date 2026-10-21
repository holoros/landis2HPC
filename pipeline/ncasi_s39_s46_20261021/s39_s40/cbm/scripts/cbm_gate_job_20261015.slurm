#!/bin/bash
#SBATCH --job-name=cbm_gate_1015
#SBATCH --account=PUOM0008
#SBATCH --time=01:30:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=48G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/logs/cbm_gate_%j.out
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm
cd $D
echo "### md5 check of uploaded scripts"
md5sum -c scripts/MD5SUMS.txt || { echo ABORT md5; exit 1; }
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
python -c "import libcbm; print('libcbm', libcbm.__version__)"
run_state() {
  ST=$1
  for V in orig noharv nodist; do
    t0=$SECONDS; python -u scripts/cbm_gate_run_20261015.py $ST $V $D --years 10 > logs/run_${ST}_${V}.log 2>&1
    rc=$?; echo "$ST $V rc=$rc elapsed $((SECONDS-t0)) s"
  done
}
export -f run_state; export D
printf "%s\n" ME NH VT MI WI MN | xargs -P 6 -I{} bash -c 'run_state {}'
echo "### reproduction"
python -u scripts/cbm_gate_repro_20261015.py $D
echo "### done"
