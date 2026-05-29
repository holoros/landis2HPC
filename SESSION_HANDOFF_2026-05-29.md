# PERSEUS session handoff

**Date:** 2026-05-29
**Repo:** github.com/holoros/landis2HPC, branch main, in sync with origin
**Latest commit:** 479ed21 (handoff 2026-05-29: WA + GA T2 v2 chain progress)
**Latest tag:** v1.3 (five-state real statewide carbon + per-species-to-carbon validation)

## One paragraph summary

PERSEUS is at v1.3 with five non-Georgia states carrying real LANDIS 100-year statewide carbon trajectories and a clean internal-consistency result: each state's year-100 calibrated-over-literature carbon ratio matches its median ANPP multiplier within 0.05. Three regimes confirmed in carbon: Washington cuts threefold, the Great Lakes cut 1.5 to 1.7-fold, Maine lifts 32 percent. The phase 3 backend is wired into the GUI with SQLite job store and API-key auth. Two Tier 2 v2 calibration chains are in flight on Cardinal (`wa_t2_v2` and `ga_t2_v2`), both at iter8, both still RUNNING. WA appears near convergence with iter6 cand11 as the best-so-far; GA was monotonic-descending through iter7 with iter8 just starting. No code work is pending — the next gate is chain landings.

## Production calibration state (six states)

| State | Tier | Production vector | Per-plot LL | n |
|---|---|---|---|---|
| ME | Tier 2 per-species | v1.0 final | +0.056 | 612 |
| WA | Tier 2 per-species | v1.0 iter1_cand11 (**v2 chain at iter8**) | -0.217 | 805 |
| GA | Tier 2 per-species | v1.1 iter5_cand8 (**v2 chain at iter8**) | -0.887 | 1255 |
| MN | Tier 2 per-species | v1.2 iter7_cand0 | -0.933 | 2741 |
| WI | Tier 2 per-species | v1.2 iter2_cand11 | -0.647 | 916 |
| MI | Tier 2 per-species | v1.2 iter7_cand5 | -0.129 | 562 |

## Chain progress (2026-05-29 afternoon)

`wa_t2_v2` reached iter8 with 13 of 14 cands landed.

| Iter | Best cand | LL | n | per-plot |
|---|---|---|---|---|
| 5 | cand3 | -938.71 | 1413 | -0.664 |
| 6 | **cand11** | **-899.33** | 1415 | -0.636 |
| 7 | cand8 | -943.57 | 1493 | -0.632 |
| 8 | cand4 | -936.56 | (partial) | (partial) |

iter6 cand11 is the global best. iter7 and iter8 both regressed in aggregate LL — classic CMA-ES near-convergence signature. Chain may auto-terminate within 1 to 2 more iters.

`ga_t2_v2` reached iter8 with 2 of 14 cands landed.

| Iter | Best cand | LL | n | per-plot |
|---|---|---|---|---|
| 4 | cand12 | -1168.27 | 1234 | -0.947 |
| 5 | cand4 | -1179.54 | 1224 | -0.964 |
| 6 | cand10 | -1159.63 | 1232 | -0.941 |
| 7 | **cand0** | **-1138.67** | 1239 | -0.920 |
| 8 | cand0 | -1252.32 | (partial) | (partial) |

iter7 cand0 is the global best; iter0 through iter7 was monotonic descent (-1187 to -1138). iter8 first cand regressed but only 2 of 14 landed. Chain likely needs more iters before harvest decision.

## Statewide carbon (v1.3)

Real 100-year LANDIS trajectories for both literature and calibrated parameters, five states. Year-100 calibrated/literature ratios match each state's median ANPP multiplier within 0.05.

| State | Lit Mg C/ha | Cal Mg C/ha | Ratio | Median θ |
|---|---|---|---|---|
| WA | 264 | 87 | 0.33 | 0.30 |
| MN | 131 | 78 | 0.60 | 0.60 |
| WI | 177 | 118 | 0.67 | 0.65 |
| MI | 179 | 105 | 0.59 | 0.63 |
| ME | 103 | 136 | 1.32 | 1.31 |

## Access notes

SSH key at the session path `outputs/.session_ssh/id_osc`. Each Cowork sandbox bash call is independent, so copy and chmod the key inside the same call. Repo on Cardinal at `/users/PUOM0008/crsfaaron/repos/landis2HPC`. Live scripts at `/fs/scratch/PUOM0008/crsfaaron/landis2/tools`. Statewide-carbon runs at `states/{ST}/perseus/statewide/{tag}/`. Calibration chains at `states/{ST}/perseus/bayesian/{chain}/`. Monitor with `bash perseus/tools/check_t2v2_chains.sh` for a one-shot per-iter best-LL snapshot.

## What is gating

Both v2 calibration chains. Mid-chain harvester run (2026-05-29 08:01) snapshotted in `perseus/docs/harvester_snapshot_2026-05-29.md`:

* WA: harvester picked `wa_t2_v2_iter7_cand8` (per-plot LL -0.6320, n=1493). NEW vector compared to v1.0 iter1_cand11. v2 vs v1 ANPP comparison: median ratio 0.985, range [0.524, 1.579], median |delta| 0.111. Same regime, reshuffled per-species. theta_best_production.csv written to chain dir.
* GA: harvester picked `ga_t2_v2_pre_warmstart_iter5_cand8` — the warmstart seed = current v1.1 production. v2 chain has not yet improved over v1.1. No promotion needed unless later iters improve.

**Do not promote v2.0 until chains terminate** (currently iter8 partial; future iters could shift the harvester pick). When `check_t2v2_chains.sh` flips to LANDED, re-harvest and compare to the snapshot. If stable, ship v1.4 per the steps in the harvester snapshot doc.

Also noted: `perseus/backend/config.py` STATES dict is out of date for GA (says Tier 1) and MN (says "calibrating"). Worth correcting in the v1.4 ship.

## Cleared since the 2026-05-27 handoff

CHANGELOG v1.3 written and pushed; v1.3 release tag pushed; SESSION_HANDOFF_2026-05-27 refreshed; build-fresh runner hardened with flock to prevent concurrent-driver collisions on the OSC submit limit; `check_t2v2_chains.sh` chain monitor authored and committed; task tracking refactored to cover both chains and the deferred GA-statewide adapter.

## Suggested next steps

1. **Wait for WA T2 v2 to converge** (likely within 24 hours given the iter7 and iter8 regressions). When it lands, `python3 /fs/scratch/PUOM0008/crsfaaron/landis2/tools/harvest_t2_chains.py --state WA` will pick the matched-n best vector and write `production_theta_wa_t2_v2.csv`. If iter6 cand11 wins, ship as WA T2 v2.0 production and refresh the readiness matrix, the GUI STATES dict, CHANGELOG v1.4, and the WA statewide carbon trajectory.

2. **Wait for GA T2 v2 to converge** (likely 24 to 48 more hours; chain still descending). Same harvest flow; if it wins matched-n, ship as GA T2 v2.0 and update the Methods Section 3 table.

3. **Refresh the 5-state carbon figure** if WA T2 v2 ships a new vector (the carbon ratio may shift slightly — currently 0.33 vs theta 0.30; new vector could move either direction).

4. **Optional and deferred:** Build `build_plot_scenario_GA.sh` adapter (Task #5) to unlock GA statewide carbon for a 6-state methods figure. The handoff explicitly flags this as marginal — WA already covers the strong-down regime. Only act if reviewers ask.

5. **Optional:** Fold the new statewide-carbon paragraph into the scenario paper and refresh the synthesis memo with the five-state numbers.

## Open tasks

| ID | Subject | Status |
|---|---|---|
| 3 | Monitor WA T2 v2 chain + harvest when landed | pending |
| 4 | Monitor GA T2 v2 chain + harvest when landed | pending |
| 5 | Build build_plot_scenario_GA.sh adapter for GA statewide carbon | pending |

Nothing else is blocked. Repo at v1.3 in sync with origin. The GUI plus backend are feature-complete for v1, and the methods paper Section 3 contains the headline regional-gradient result with the statewide-carbon consequence.
