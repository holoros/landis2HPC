#!/bin/bash
#SBATCH --job-name=cbm_gate_score
#SBATCH --account=PUOM0008
#SBATCH --time=00:15:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/logs/cbm_score_%j.out
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm
cd $D
echo "e23e3c2cd2b0ec45d0d17eb4eb1f62a0  scripts/cbm_gate_score_20261015.py" > /dev/null
md5sum scripts/cbm_gate_score_20261015.py
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
python -u scripts/cbm_gate_score_20261015.py $D
for st in ME NH VT MI WI MN; do grep -A8 "active in years" logs/run_${st}_noharv.log | head -9; done

