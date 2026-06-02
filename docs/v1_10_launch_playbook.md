# v1.10 launch playbook — IN COTT+SIM species pool extension

**Status:** infrastructure staged; launch deferred until after v1.9 statewide jobs land
**Author:** drafted by autopilot 2026-06-02 evening
**Prerequisite:** v1.9 jobs (11207175-78) complete; v1.9 carbon baseline captured

## What's already staged on Cardinal (parallel _v2 paths, production untouched)

| Path | Content | Status |
|---|---|---|
| `states/IN/inputs_v2/SpeciesData.csv` | 25 species (added COTT, SIM) | ✓ shipped |
| `states/IN/inputs_v2/SppEcoregionData.csv` | 125 rows (5 eco × 25 species) | ✓ shipped |
| `states/OH/inputs_v2/SpeciesData.csv` | 25 species (added COTT, SIM) | ✓ shipped |
| `states/OH/inputs_v2/SppEcoregionData.csv` | 150 rows (6 eco × 25 species) | ✓ shipped |
| `tools/apply_theta_IN_v2_perspecies.py` | 50-entry theta vector | ✓ shipped |
| `tools/apply_theta_OH_v2_perspecies.py` | 50-entry theta vector | ✓ shipped |
| `tools/build_plot_ics_N3_v2.py` | SPCD 742 (cottonwood) → COTT; 317 (silver maple) → SIM | ✓ shipped |

Production paths (`states/{IN,OH}/inputs/`, `tools/apply_theta_{IN,OH}_perspecies.py`, `tools/build_plot_ics_N3.py`) are unchanged at 23 species. The 4 running v1.9 statewide carbon jobs are insulated.

## v1.10 launch sequence (run after v1.9 lands)

### Step 1: rebuild ICs to v2 dir (~10 min CPU)

```bash
cd /fs/scratch/PUOM0008/crsfaaron/landis2
python3 tools/build_plot_ics_N3_v2.py \
  --tree FIA/IN_TREE.csv \
  --plot-list tools/untreated_plots_IN.csv \
  --out states/IN/perseus/plot_ics_full_v2

python3 tools/build_plot_ics_N3_v2.py \
  --tree FIA/OH_TREE.csv \
  --plot-list tools/untreated_plots_OH.csv \
  --out states/OH/perseus/plot_ics_full_v2
```

Expected: ~440 IN plot dirs, ~900 OH plot dirs (matching v1 counts). Spot-check a bottomland plot (look for cottonwood-dominated plots in IN floodplains) to confirm COTT cohorts appear in the IC.

### Step 2: build_plot_scenario_{IN,OH}_v2.sh

Clone the existing build_plot_scenario_{IN,OH}.sh and substitute:
- `INPUTS=$STATE/inputs` → `INPUTS=$STATE/inputs_v2`
- `ICS=$STATE/perseus/plot_ics_full` → `ICS=$STATE/perseus/plot_ics_full_v2`

Save as tools/build_plot_scenario_IN_v2.sh and tools/build_plot_scenario_OH_v2.sh. Make executable. Smoke-test one plot before chain submission:
```bash
bash tools/build_plot_scenario_IN_v2.sh 1 baseline none
ls $LANDIS/states/IN/perseus/runs/plot_1__clim_baseline_harv_none/
```

### Step 3: warmstart vector (50-entry pad)

```bash
# Pad in_t2_v3 production theta from 46 to 50 entries (1.0 for COTT/SIM)
python3 - <<PY
import csv
src = "/fs/scratch/PUOM0008/crsfaaron/landis2/states/IN/perseus/bayesian/in_t2_v3/theta_best_production.csv"
dst = "/users/PUOM0008/crsfaaron/theta_IN_v3_padded_for_v4.csv"
with open(src) as f: rows = list(csv.DictReader(f))
# add COTT/SIM literature defaults (1.0 = no scaling)
for sp in ["COTT", "SIM"]:
    rows.append({"param": f"ANPP_{sp}", "value": "1.0"})
    rows.append({"param": f"BMAX_{sp}", "value": "1.0"})
with open(dst, "w", newline="") as g:
    w = csv.DictWriter(g, fieldnames=["param", "value"])
    w.writeheader()
    for r in rows: w.writerow(r)
print(f"wrote {dst} with {len(rows)} entries (was 46, now 50)")
PY
```

### Step 4: clone run_param_set_IN_t2 to v2 variant

```bash
sed 's|build_plot_scenario_IN.sh|build_plot_scenario_IN_v2.sh|g;
     s|apply_theta_IN_perspecies.py|apply_theta_IN_v2_perspecies.py|g;
     s|states/IN/inputs/SppEcoregionData|states/IN/inputs_v2/SppEcoregionData|g;
     s|in_t2_v3|in_t2_v4|g' \
  tools/run_param_set_IN_t2.sh > tools/run_param_set_IN_t2_v2.sh
chmod +x tools/run_param_set_IN_t2_v2.sh
```

Verify it points at v2 paths only; smoke-test with a single iter0 candidate before full chain.

### Step 5: submit IN T2 v4 chain (warmstart from padded v3)

```bash
sbatch --parsable \
  --job-name=in_t2_v4 \
  --account=PUOM0008 --partition=batch \
  --ntasks=1 --cpus-per-task=1 --mem=4G --time=2-00:00:00 \
  --output=/fs/scratch/PUOM0008/crsfaaron/landis2/states/IN/perseus/bayesian/in_t2_v4/driver.out \
  --error=/fs/scratch/PUOM0008/crsfaaron/landis2/states/IN/perseus/bayesian/in_t2_v4/driver.err \
  --wrap "python3 tools/cma_es_optimize_cluster.py --state IN --tag in_t2_v4 --warmstart /users/PUOM0008/crsfaaron/theta_IN_v3_padded_for_v4.csv --inputs-dir states/IN/inputs_v2 --runner tools/run_param_set_IN_t2_v2.sh"
```

Note: `cma_es_optimize_cluster.py` may not currently accept `--inputs-dir` and `--runner` flags — check its arg parser. If not, the script needs a small extension to override the default state-inputs path. Alternative: monkey-patch via env vars (LANDIS_INPUTS_OVERRIDE, RUNNER_OVERRIDE).

### Step 6: monitor with the existing chain monitor

```bash
bash tools/check_t2v2_chains.sh in_t2_v4
```

Expected: ~1.5 days for 8 iterations × 14 candidates with the densified-pairing runner. Target per-plot LL improvement from -1.31 toward the -0.5 to -0.9 range.

### Step 7: harvest and ship v1.10

```bash
python3 tools/harvest_t2_chains.py \
  --bayesian-dir states/IN/perseus/bayesian/in_t2_v4 --state IN
```

Then:
- Promote to production: copy `theta_best_production.csv` to the production path the GUI reads
- Re-freeze cluster N3 reference: `cp .../in_t2_v4/theta_best_production.csv tools/state_templates/cluster_N3_reference_theta.csv`
- Repeat steps 1-7 for OH (warmstart from v4 IN reference, padded)
- Re-run IN+OH statewide carbon under new thetas
- Update atlas summary.json, methods Section 3, CHANGELOG v1.10, tag v1.10

## Risks and contingencies

**Risk: cma_es_optimize_cluster.py doesn't support --inputs-dir.** Mitigation: read the script, add the flag, or use a wrapper that temporarily symlinks inputs_v2 → inputs (only safe if no concurrent v1.9 work on the same state). If symlink-swap, hold a flock.

**Risk: 1.0 warmstart for COTT/SIM is too neutral.** CMA-ES may converge slowly for the 4 new dimensions. If iter3 doesn't show movement on COTT/SIM, consider initializing those at the cluster's median ANPP θ (~0.5) instead of 1.0.

**Risk: per-plot LL doesn't improve.** If iter4 LL is still -1.2 or worse, the bottomland-lumping hypothesis is wrong; revert and investigate alternatives (e.g., FIA temporal sampling issues, climate data mismatches at Indiana ecoregions).

**Risk: OH degrades.** OH currently fits well (-0.86) without COTT/SIM. If the OH re-cal lands below -0.86, the v1 OH calibration is preferred for OH but we still use v4 for IN. The cluster N3 reference can then be either (a) the better of the two states or (b) per-state at the deviation cost.

## Expected outcome

If the bottomland-lumping hypothesis holds, IN T2 v4 lands with per-plot LL in the -0.5 to -0.9 range. This unblocks the cluster N3 reference quality for future Eastern Hardwood Central states (KY, TN, MO, IL, IA under the CONUS plan) and brings Indiana into the normal PERSEUS calibration range.

If the hypothesis is wrong (LL stays at -1.31), we learn that the issue is elsewhere (likely FIA temporal coverage or ecoregion-specific climate data) and v1.10 reverts to v1.9 as production for IN/OH.

Either way, the v2 infrastructure remains in place as a reusable template for future cluster reference improvements.
