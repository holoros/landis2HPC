#!/bin/bash
#SBATCH --job-name=s41_b
#SBATCH --account=PUOM0008
#SBATCH --time=01:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=18
#SBATCH --mem=96G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm/logs/s41_b_%j.out
set -uo pipefail
D=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm
SC=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/scripts/cbm_gate_score_v4_20261015.py
S40=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/rerun_v2_20261015
cd $D
printf "8d81b3cae70cd624c9419f646dd690d1  s41_fia_condtable_v1.R\nc4f01e2b460efdf44e63f9ebf62ba19f  s41_conv_test_v1.py\ne75216a635e2c11fad1ef5fd04f2329a  s41_cbm_fix_v2.py\nc535c57410a51bfbf82f3079e90e7274  s41_merch_mort_diag_v1.py\n312853b8cc9a560cd4e312e6006e141b  $SC\n" | md5sum -c - || exit 1
for V in F2 F3 F23; do [ -e $D/fix_$V ] && { echo "ABORT: fix_$V exists"; exit 1; }; done
( module purge; module load gcc/12.3.0 R/4.5.2; Rscript s41_fia_condtable_v1.R > logs/condtable_v1.log 2>&1; echo "condtable rc=$?" )
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
python -u s41_conv_test_v1.py > logs/conv_test_v1.log 2>&1; echo "conv rc=$?"
for V in F2 F3 F23; do mkdir -p $D/fix_$V/logs; done
export D
for V in F2 F3 F23; do for ST in ME NH VT MI WI MN; do echo "$V $ST"; done; done | xargs -P 18 -L 1 bash -c 'python -u s41_cbm_fix_v2.py $1 $D/fix_$0 --variant $0 --years 10 > $D/fix_$0/logs/run_$1.log 2>&1; echo "$0 $1 rc=$?"'
for V in F2 F3 F23; do echo "### score $V"; python -u $SC $D/fix_$V 2>&1 | grep -v -E "Pandas4Warning|RuntimeWarning|warnings.warn" | head -12; done
python -u s41_merch_mort_diag_v1.py s41_merch_mort_diag_20261015.csv $S40:baseline $D/fix_F2:F2 $D/fix_F3:F3 $D/fix_F23:F23 2>&1 | grep -v -E "RuntimeWarning|warnings.warn"
echo "### asserts"; grep -h "^ASSERT" $D/fix_F23/logs/run_*.log
echo "### F2 factors"; cat $D/fix_F2/runs/fix_factors_F2_*.csv | cut -c1-200
echo "### F3 multipliers"; cat $D/fix_F3/runs/fix_curve_mult_F3_*.csv
echo "### conv test"; cat logs/conv_test_v1.log | grep -v -E "RuntimeWarning|warnings.warn"
echo "### condtable"; cat logs/condtable_v1.log
md5sum $D/*.csv $D/fix_*/cbm_gate_results_v4_20261015.csv
