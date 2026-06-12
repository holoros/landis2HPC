#!/bin/bash
#SBATCH --job-name=recal_rebuild
#SBATCH --account=PUOM0008
#SBATCH --time=00:40:00
#SBATCH --nodes=1 --ntasks=1 --cpus-per-task=4 --mem=24G
#SBATCH --output=/fs/scratch/PUOM0008/crsfaaron/FIA/recal/recal_rebuild_%j.out
#SBATCH --error=/fs/scratch/PUOM0008/crsfaaron/FIA/recal/recal_rebuild_%j.err
set -euo pipefail
module load gcc/12.3.0
module load gdal/3.7.3 geos/3.12.0 proj/9.2.1
module load R/4.4.0
export R_LIBS=$HOME/R/cardinal_libs/4.4.0:$HOME/R/cardinal_libs:$HOME/R/x86_64-pc-linux-gnu-library/4.4

S=/fs/scratch/PUOM0008/crsfaaron/FIA
R=$S/recal
HCS_ORIG=/users/PUOM0008/crsfaaron/cbm_states/cross_state/libcbm/tools_conus/14_outputs/uncertainty/hcs_harvest_rate_by_state.csv
HCS_CAL=$S/hcs_harvest_rate_by_state_calibrated.csv
mkdir -p $R
cd $S

# srcND model name : reserve basename (nodisturb)
declare -A NOD=( [FVScalibrated]=fvs_reserve_calibrated_anchored [FVSdefault]=fvs_reserve_default_anchored [YC]=yc_reserve_anchored [CBM]=cbm_reserve_anchored [CEM]=cem_reserve_anchored [9state]=harmonized_landis_reserve_9state )
declare -A DIS=( [FVScalibrated]=fvs_reserve_calibrated_disturbed [FVSdefault]=fvs_reserve_default_disturbed [YC]=yc_reserve_disturbed [CBM]=cbm_reserve_disturbed [CEM]=cem_reserve_disturbed [9state]=harmonized_landis_reserve_9state_disturbed )

# --- Verification gate: reproduce canonical CBM (orig hcs) and assert match ---
Rscript apply_harvest_scenarios.R --reserve $S/cbm_reserve_anchored.csv --hcs $HCS_ORIG --out $R/_v_traj.csv --summary $R/_v_npv.csv >/dev/null 2>&1
if ! diff <(grep -E "^(MN|MI|WI),BAU" $S/harmonized_carbon_npv_CBM.csv) <(grep -E "^(MN|MI|WI),BAU" $R/_v_npv.csv) >/dev/null; then
  echo "VERIFY FAILED: reproduction does not match canonical CBM. Aborting."; exit 1
fi
echo "VERIFY OK: pipeline reproduces canonical CBM with original HCS."

# --- Run all 12 with the CALIBRATED hcs into recal/ ---
for m in FVScalibrated FVSdefault YC CBM CEM 9state; do
  Rscript apply_harvest_scenarios.R --reserve $S/${NOD[$m]}.csv --hcs $HCS_CAL \
    --out $R/traj_${m}.csv --summary $R/harmonized_carbon_npv_${m}.csv >/dev/null 2>&1
  Rscript apply_harvest_scenarios.R --reserve $S/${DIS[$m]}.csv --hcs $HCS_CAL \
    --out $R/traj_${m}_dist.csv --summary $R/harmonized_carbon_npv_${m}_dist.csv >/dev/null 2>&1
  echo "ran $m (nodisturb + disturbed) with calibrated HCS"
done

# --- Rebuild master/ensemble/conus reading from recal/ (FIA dir repointed) ---
sed "s#^FIA <- .*#FIA <- \"$R\"#" $S/build_master_scenarios.R > $R/build_master_recal.R
Rscript $R/build_master_recal.R 2>&1 | tail -20

# --- Headline diff: CONUS by scenario, original vs calibrated ---
echo "===== CONUS 2100 by scenario: ORIGINAL ====="
cat $S/harmonized_conus_by_scenario.csv
echo "===== CONUS 2100 by scenario: CALIBRATED ====="
cat $R/harmonized_conus_by_scenario.csv
echo "DONE recal rebuild $(date)"
