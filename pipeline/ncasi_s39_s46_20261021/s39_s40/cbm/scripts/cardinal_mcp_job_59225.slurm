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
echo "29492a0c9fd9a2b4e8d79d9a9411d4ff  scripts/cbm_gate_score_20261015.py" | md5sum -c - || exit 1
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
python -u scripts/cbm_gate_score_20261015.py $D
for st in ME MN; do for v in orig; do grep -A9 "active in years" logs/run_${st}_${v}.log | head -10; done; done

