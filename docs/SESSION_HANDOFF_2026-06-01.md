# PERSEUS session handoff — 2026-06-01

**Repo:** github.com/holoros/landis2HPC, branch main, in sync with origin
**Tag:** v1.6 (Indiana promoted; OH chain launched)
**Builds on:** `SESSION_HANDOFF_2026-05-31c.md`.

## One paragraph summary

Indiana is calibrated and promoted — PERSEUS is now eight states, and IN is the first added
entirely through the hybrid warmstart + densified-pairing path. The densified `in_t2_v3`
chain landed (n=733, per-plot LL −1.3146) and harvested cleanly. The N3 cluster reference
was re-frozen from IN's production theta. Ohio's scenario builder had a CRLF bug that the
smoke test caught and we fixed; OH then smoke-passed and `oh_t2_v2` is now running,
warmstarted from the IN-calibrated N3 reference. The only loose end is the WA v1.4.1
statewide-carbon rerun, which produced no output and needs a longer-wall-time re-run.

## Done this session

1. **Harvested + promoted IN.** `harvest_t2_chains.py` selected `in_t2_v3_iter2_cand11`
   (n=733 ≥ floor 634, per-plot LL −1.3146). `states/IN/perseus/bayesian/in_t2_v3/
   theta_best_production.csv` written; `check_t2v2_chains.sh in_t2_v3` → PROMOTED.
2. **Re-froze the N3 reference** (`state_templates/cluster_N3_reference_theta.csv`) from IN's
   production theta, replacing the MN bootstrap.
3. **Fixed the OH builder CRLF bug.** PRISM_OH_l3.csv is CRLF; the last eco column carried a
   trailing `\r`, failing the header check for eco-71 plots. `build_plot_scenario_{OH,IN}.sh`
   now `tr -d '\r'` the PRISM header and climate extraction. OH one-plot smoke passed (rc=0,
   biomass output for all species).
4. **Launched `oh_t2_v2`** (job 11169120, 72 h) — densified runner, warmstart from the
   IN-calibrated N3 reference. Queue was at 51 so it should start without throttle.
5. Committed the fixed builders, re-frozen reference, CHANGELOG v1.6, and this handoff.

## State of the queue / chains

- `oh_t2_v2` (job 11169120): running/pending; monitor with `bash tools/check_t2v2_chains.sh
  oh_t2_v2`. Expect iter0 candidates to report n in the hundreds (OH has 369 IC-backed subset
  plots; densified pairing applies).
- `in_t2_v3`: PROMOTED, done.

## Next steps

1. **Monitor `oh_t2_v2` to landing** (~1–2 days). When `check_t2v2_chains.sh oh_t2_v2` shows
   LANDED, harvest: `python3 tools/harvest_t2_chains.py --bayesian-dir
   states/OH/perseus/bayesian/oh_t2_v2 --state OH`. If n ≥ 300 and it promotes, PERSEUS is
   nine states.
2. **Re-run WA v1.4.1 statewide carbon.** `wa_stwide_v2` made no trajectories (built its
   1354-plot list then died at wall-time / queue gate). Re-submit `run_statewide_buildfresh.sh`
   for WA with a longer `--time` (e.g. 3 days) and confirm it isn't starved by the queue gate;
   then refresh `perseus/figures/statewide_carbon_5state.png` with WA's v2.0 number.
3. **Domain check on IN's calibration.** Per-plot LL −1.31 is the weakest of the eight; worth
   a look at whether the N3 species lumping or the warmstart should be revisited before IN is
   treated as final. The provisional oak/hickory SPCD lumps in `build_plot_ics_N3.py` are the
   first thing to sanity-check.
4. **Update Methods Section 3** to the eight-state table once OH lands.

## Files touched

- `perseus/tools/build_plot_scenario_OH.sh`, `build_plot_scenario_IN.sh` — CRLF-robust PRISM
  handling (added to repo).
- `perseus/tools/state_templates/cluster_N3_reference_theta.csv` — re-frozen from IN.
- `CHANGELOG.md` (v1.6), this handoff.
