# PERSEUS session handoff

**Date:** 2026-05-21
**Repo:** github.com/holoros/landis2HPC, branch main, in sync with origin
**Latest commit at handoff:** b04e02f (plus a pending GUI-defaults commit described below)

## One paragraph summary

GA Tier 2 v2 finished and was harvested correctly after catching a settling-check timeout artifact; the harvester was hardened and the fix plus per-state parity files shipped as v1.1. A Forest Intelligence GUI (scenario builder, calibration view, statewide growth-curve projections, CTrees-style) was built, previewed, documented with a five-phase roadmap, and committed. MN, WI, and MI calibration chains are still running on Cardinal. The GUI now defaults to Maine with a curated set of scenario presets.

## Cardinal calibration state

| State | Job | Status | Production / provisional per-plot LL | n |
|---|---|---|---|---|
| ME | (v1.0) | production | +0.056 | 612 |
| WA | (v1.0) | production | −0.217 | 805 |
| GA | 10021254 | landed + harvested | −0.8871 (iter5_cand8) | 1255 |
| MN | 10124727 | running, iter1 | −0.96 provisional | 2867 |
| WI | 10126909 | running, iter1 | −0.66 provisional | 935 |
| MI | 10126910 | running, iter1 | −0.17 provisional | 528 |

MN, WI, and MI should land roughly 12 to 15 hours from the start of this session. When they do, the queue clears and the deferred GA matched-n evaluation can run.

## Access notes

SSH key lives at the session path `outputs/.session_ssh/id_osc`. The broken sandbox SSH config means every call needs `ssh -F /dev/null -i <key> -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no crsfaaron@cardinal.osc.edu`, and each bash call is independent so the key must be copied and chmod 600 inside the same call. The git repo on Cardinal is at `/users/PUOM0008/crsfaaron/repos/landis2HPC`; the live working scripts run from `/fs/scratch/PUOM0008/crsfaaron/landis2/tools`. GitHub push from Cardinal works (holoros authenticated).

## What shipped this session

1. Fixed `perseus/tools/harvest_t2_chains.py` to be n-aware. It parses the true paired-observation count and signed LL from each candidate's `launch.log`, requires n at least max(300, 0.85 times the chain max), then selects the best per-plot LL. This stops a timed-out settling check from re-introducing the sample-size degeneracy. GA iter5_cand10 (240 of 779 plots, n=398) was the artifact it now rejects.
2. Harvested GA correctly to `theta_best_production.csv` (iter5_cand8).
3. Committed v1.1 (972ed9e): the harvester fix, 19 PERSEUS parity scripts pulled from the live tools tree, a CHANGELOG v1.1 entry, and the readiness matrix update. Pushed.
4. Built and committed the Forest Intelligence GUI v1 (b04e02f): `perseus/dashboard/perseus_forest_intelligence_v1.html` and `docs/GUI_v1_architecture.md`. Pushed.
5. Set GUI defaults (pending commit): default state Maine, a scenario preset selector, and projected biomass as the default map layer.

## Key scientific decisions and open questions

The GA Tier 2 per-plot LL (−0.8871 over n=1255) is not directly comparable to the v1.0 GA Tier 1 figure (+0.024 over n=218) because the two were scored on different paired sets. GA's production tier stays Tier 1 until a matched-n evaluation runs. The defensible production-vector rule is now per-plot LL among near-full-n candidates, not raw minimum negLL.

## Next steps, in priority order

1. When MN, WI, and MI land, run `harvest_t2_chains.py --all`, build the six-state production calibration table and species heatmap, refresh methods Section 3, and tag v1.2.
2. Run the matched-n GA Tier 1 versus Tier 2 evaluation (task #118): build a uniform theta of 0.30 across all 54 GA parameters, run it through `run_param_set_GA_t2.sh` on `ga_t2_plotsubset.txt`, and compare its per-plot LL on n approximately 1255 to iter5_cand8's −0.8871. This sets GA's production tier. Run it after the chains clear the queue so it does not starve them.
3. GUI phase 2: replace the illustrative climate and harvest envelopes with real per-plot trajectories read from `perseus/dashboard/atlas/{ST}.json`.
4. GUI phase 3: stand up a minimal FastAPI service that submits one scenario to Cardinal and returns its trajectory, the seed for live runs.
5. IN and OH: download FIA states 18 and 39, build their initial-communities rasters, then run the MN pipeline. Their ecoregion dependency is already solved.

## GUI defaults locked

Default state is Maine, chosen as the home state with a clean Tier 2 production calibration. Featured production states are ME, WA, GA; MN, WI, MI appear flagged as calibrating. Scenario presets are: no management reference (baseline climate, no harvest), working forest (baseline, moderate harvest), moderate climate (SSP2-4.5, light harvest), and high climate plus disturbance (SSP5-8.5, light harvest, disturbance on), plus a custom mode that exposes the raw controls. The default map layer is projected biomass at year 50.

## File map

GUI app at `perseus/dashboard/perseus_forest_intelligence_v1.html`. Architecture and roadmap at `docs/GUI_v1_architecture.md`. Harvester at `perseus/tools/harvest_t2_chains.py`. Readiness matrix at `docs/multistate_readiness_matrix.md`. Changelog at `CHANGELOG.md`. Per-state plot bundles at `perseus/data/untreated_plots_{ST}.csv`. Production theta vectors at `perseus/theta_best/`.

## Open tasks

Monitoring MN (#112) and WI/MI (#114). Matched-n GA Tier 1 versus Tier 2 evaluation (#118). GUI phase 2 and phase 3 are next to be created as tasks.
