#!/bin/bash
#SBATCH --job-name=s41_a
#SBATCH --account=PUOM0008
#SBATCH --time=00:45:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=6
#SBATCH --mem=48G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm/logs/s41_a_%j.out
cd /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm
printf "346f4ef8928908a3fde00ddc1e3d0773  s41_fia_nsvb_components_v2.R\n4dba2dbcdd6a3c1072de57f9df9de665  s41_cbm_year0_decomp_v2.py\n" | md5sum -c - || exit 1
( source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate; python -u s41_cbm_year0_decomp_v2.py 2>&1 | grep -v Pandas4Warning > logs/cbm0_v2.log ) &
module purge; module load gcc/12.3.0 R/4.5.2
Rscript s41_fia_nsvb_components_v2.R > logs/fia_v2.log 2>&1
wait
echo "### CBM"; cat logs/cbm0_v2.log
echo "### FIA"; cat logs/fia_v2.log
