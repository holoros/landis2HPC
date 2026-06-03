#!/bin/bash
# launch_v110_in_v2.sh — single-shot v1.10 launch script for IN COTT+SIM extension.
#
# Creates the IN_v2 pseudo-state, builds ICs with the new SPCD map (742->COTT, 317->SIM),
# generates run_param_set_IN_v2_t2.sh + build_plot_scenario_IN_v2.sh from v1 templates,
# pads in_t2_v3 production theta to 50 entries with 1.0 for COTT+SIM, then submits the
# CMA-ES driver. Use after v1.9 statewide carbon jobs (11207175-78) have completed.
#
# Approach: cma_es_optimize_cluster.py reads SpeciesData from states/<ST>/inputs/ and looks
# up runner via f"run_param_set_<state>_t2.sh". By using --state IN_v2 we get:
#   - SpeciesData from states/IN_v2/inputs/SpeciesData.csv  (25 species, symlinked)
#   - Runner from tools/run_param_set_IN_v2_t2.sh  (v2 paths)
#   - Output to states/IN_v2/perseus/bayesian/<tag>/
# Production paths (states/IN/inputs, run_param_set_IN_t2.sh) remain untouched.
#
# Usage:  bash launch_v110_in_v2.sh
set -euo pipefail

LANDIS=/fs/scratch/PUOM0008/crsfaaron/landis2
TOOLS=$LANDIS/tools
IN=$LANDIS/states/IN
IN_V2=$LANDIS/states/IN_v2
TAG=in_v2_t2_v1
WS_DIR=$IN_V2/perseus/bayesian/$TAG
WS_PADDED=/users/PUOM0008/crsfaaron/theta_IN_v3_padded_for_v2.csv

echo "=== Step 1: create IN_v2 state dir with symlinked inputs ==="
mkdir -p $IN_V2/inputs $IN_V2/perseus
# Symlink inputs from inputs_v2/ (the staged 25-species data)
ln -sf $IN/inputs_v2/SpeciesData.csv $IN_V2/inputs/SpeciesData.csv
ln -sf $IN/inputs_v2/SppEcoregionData.csv $IN_V2/inputs/SppEcoregionData.csv
# Symlink climate data, IC template etc from production IN/inputs/
for f in PRISM_IN_l3.csv initial_communities.txt; do
  if [ -f "$IN/inputs/$f" ]; then ln -sf $IN/inputs/$f $IN_V2/inputs/$f; fi
done
echo "  IN_v2 inputs symlinked"
ls -la $IN_V2/inputs/

echo ""
echo "=== Step 2: rebuild ICs with v2 SPCD map (742->COTT, 317->SIM) ==="
python3 $TOOLS/build_plot_ics_N3_v2.py \
  --tree $LANDIS/FIA/IN_TREE.csv \
  --plot-list $TOOLS/untreated_plots_IN.csv \
  --out $IN_V2/perseus/plot_ics_full 2>&1 | tail -3
NIC=$(ls $IN_V2/perseus/plot_ics_full | grep -c plot_ || echo 0)
echo "  built $NIC plot IC dirs"
# Spot-check: how many ICs now have COTT or SIM cohorts?
N_COTT=$(grep -l "^1,COTT," $IN_V2/perseus/plot_ics_full/plot_*/initial_communities.csv 2>/dev/null | wc -l)
N_SIM=$(grep -l "^1,SIM," $IN_V2/perseus/plot_ics_full/plot_*/initial_communities.csv 2>/dev/null | wc -l)
echo "  plots with COTT cohort: $N_COTT; plots with SIM cohort: $N_SIM"
if [ "$N_COTT" -eq 0 ] && [ "$N_SIM" -eq 0 ]; then
  echo "WARN: no plots got COTT or SIM cohorts — SPCD rerouting may not be working"
fi

echo ""
echo "=== Step 3: generate v2 runner + scenario builder ==="
# build_plot_scenario_IN_v2.sh = clone of v1 with paths pointing at IN_v2
sed 's|states/IN/inputs|states/IN_v2/inputs|g;
     s|states/IN/perseus|states/IN_v2/perseus|g;
     s|build_plot_scenario_IN|build_plot_scenario_IN_v2|g' \
  $TOOLS/build_plot_scenario_IN.sh > $TOOLS/build_plot_scenario_IN_v2.sh
chmod +x $TOOLS/build_plot_scenario_IN_v2.sh
echo "  wrote $TOOLS/build_plot_scenario_IN_v2.sh"

# run_param_set_IN_v2_t2.sh = clone with paths + apply_theta swapped to v2
sed 's|STATE=$LANDIS/states/IN$|STATE=$LANDIS/states/IN_v2|;
     s|run_param_set_IN_t2|run_param_set_IN_v2_t2|;
     s|apply_theta_IN_perspecies|apply_theta_IN_v2_perspecies|g;
     s|build_plot_scenario_IN.sh|build_plot_scenario_IN_v2.sh|g;
     s|in_t2_plotsubset|in_v2_t2_plotsubset|g' \
  $TOOLS/run_param_set_IN_t2.sh > $TOOLS/run_param_set_IN_v2_t2.sh
chmod +x $TOOLS/run_param_set_IN_v2_t2.sh
echo "  wrote $TOOLS/run_param_set_IN_v2_t2.sh"

# Sanity grep
echo "  v2 runner paths (should reference IN_v2 and _v2 tools):"
grep -E "states/IN_v2|apply_theta_IN_v2|build_plot_scenario_IN_v2|in_v2_t2" $TOOLS/run_param_set_IN_v2_t2.sh | head -5

echo ""
echo "=== Step 4: pad in_t2_v3 theta (46 -> 50 entries) for warmstart ==="
python3 - <<PY
import csv
src = "$IN/perseus/bayesian/in_t2_v3/theta_best_production.csv"
dst = "$WS_PADDED"
with open(src) as f: rows = list(csv.DictReader(f))
print(f"  loaded {len(rows)} entries from {src}")
# Pad with COTT/SIM literature defaults (1.0)
for sp in ["COTT", "SIM"]:
    rows.append({"param": f"ANPP_{sp}", "value": "1.0"})
    rows.append({"param": f"BMAX_{sp}", "value": "1.0"})
with open(dst, "w", newline="") as g:
    w = csv.DictWriter(g, fieldnames=["param", "value"])
    w.writeheader()
    for r in rows: w.writerow(r)
print(f"  wrote {dst} with {len(rows)} entries")
PY

echo ""
echo "=== Step 5: smoke-test one plot scenario before chain submission ==="
PLOT=$(head -1 $IN_V2/perseus/plot_ics_full/_summary.csv 2>/dev/null | grep -v plot_id | head -1 | cut -d, -f2)
if [ -z "$PLOT" ]; then PLOT=$(ls $IN_V2/perseus/plot_ics_full | grep ^plot_ | head -1 | sed 's/plot_//'); fi
echo "  smoke-testing plot $PLOT"
bash $TOOLS/build_plot_scenario_IN_v2.sh $PLOT baseline none > /tmp/smoke.log 2>&1 && echo "  ✓ scenario build OK" || { echo "  ✗ scenario build FAILED — check /tmp/smoke.log"; cat /tmp/smoke.log; exit 5; }

echo ""
echo "=== Step 6: submit IN_v2 T2 v1 chain ==="
mkdir -p $WS_DIR
JID=$(sbatch --parsable \
  --job-name=in_v2_t2_v1 \
  --account=PUOM0008 --partition=batch \
  --ntasks=1 --cpus-per-task=1 --mem=4G --time=2-00:00:00 \
  --output=$WS_DIR/driver.out \
  --error=$WS_DIR/driver.err \
  --wrap "cd $LANDIS && python3 $TOOLS/cma_es_optimize_cluster.py --state IN_v2 --tag $TAG --warmstart $WS_PADDED --runner-timeout-h 4.0")
echo "  submitted chain driver: job $JID"
echo "  monitor: squeue --me | grep in_v2_t2_v1"
echo "  output: $WS_DIR/driver.{out,err}"
echo "  ~1.5 days expected for 8 iters x 14 candidates"

echo ""
echo "=== v1.10 IN launch complete ==="
echo "When chain lands, run: python3 $TOOLS/harvest_t2_chains.py --bayesian-dir $IN_V2/perseus/bayesian/$TAG --state IN_v2"
