#!/bin/bash
#SBATCH --account=PUOM0008 --time=00:30:00 --nodes=1 --cpus-per-task=1 --mem=4G
#SBATCH --job-name=s44find
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s44/landis_me_promote/logs/find_%j.out
cd /fs/scratch/PUOM0008/crsfaaron
find . ~ -maxdepth 7 \( -name 'PARAMS_ACTIVE*' -o -name 'SppEcoregionData_fia_2026*' -o -name 'RUN_promote*' -o -name 'states_fb_20260930' -o -name 'landis-stage8-20261003' \) 2>/dev/null
echo DONE
