# PERSEUS session handoff

**Date:** 2026-05-27
**Repo:** github.com/holoros/landis2HPC, branch main, in sync with origin
**Latest commit:** 354d47e (five-state statewide carbon + Methods Section 3 update)
**Next tag:** v1.3 (pending; covers everything since v1.2 — see CHANGELOG)

## One paragraph summary

All five non-Georgia states now have real LANDIS 100-year statewide carbon trajectories, with a clean internal-consistency result: each state's year-100 calibrated-over-literature carbon ratio matches its median ANPP multiplier within 0.05. Three regimes confirmed in carbon: Washington cuts threefold, the Great Lakes cut 1.5 to 1.7-fold, Maine lifts 32 percent. The phase 3 backend is wired into the GUI and hardened with a SQLite job store plus API-key auth. A new `wa_t2_v2` calibration chain is running on Cardinal (currently iter0 at four hours elapsed); when it lands it may supersede the v1.0 WA Tier 2 vector.

## Production calibration state (six states)

| State | Tier | Production vector | Per-plot LL | n |
|---|---|---|---|---|
| ME | Tier 2 per-species | v1.0 final | +0.056 | 612 |
| WA | Tier 2 per-species | v1.0 iter1_cand11 (v2 chain running) | -0.217 | 805 |
| GA | Tier 2 per-species | v1.1 iter5_cand8 (matched-n confirmed > T1) | -0.887 | 1255 |
| MN | Tier 2 per-species | v1.2 iter7_cand0 | -0.933 | 2741 |
| WI | Tier 2 per-species | v1.2 iter2_cand11 | -0.647 | 916 |
| MI | Tier 2 per-species | v1.2 iter7_cand5 | -0.129 | 562 |

## Statewide carbon (new in v1.3)

Real 100-year LANDIS trajectories for both literature and calibrated parameters, five states. The year-100 calibrated-over-literature ratio matches each state's median ANPP multiplier almost exactly, confirming the per-species correction propagates cleanly to the state-aggregate carbon.

## Access notes

SSH key at the session path `outputs/.session_ssh/id_osc`. Each Cowork sandbox bash call is independent, so copy and chmod the key inside the same call. Repo on Cardinal at `/users/PUOM0008/crsfaaron/repos/landis2HPC`; live scripts at `/fs/scratch/PUOM0008/crsfaaron/landis2/tools`. GitHub push from Cardinal works (holoros authenticated). Statewide-carbon runs live under `states/{ST}/perseus/statewide/{tag}/`.

## What is running (2026-05-29 update)

Two Tier 2 v2 chains in flight on Cardinal. Each iter has 14 cands; chain has been running roughly 48h.

`wa_t2_v2`: reached iter8 (5 cands so far). Best-so-far is `iter6 cand11 LL=-899.33` (n=1415, per-plot=-0.636). iter7 (-943) and iter8 (-975) partial regressed, so CMA-ES is likely near convergence with widened sigma. Harvest gate: matched-n eval of iter6 vector against v1.0 production (per-plot LL=-0.217, n=805).

`ga_t2_v2`: reached iter7 (7 cands so far). Best-so-far is `iter7 cand0 LL=-1138.67` (n=1239, per-plot=-0.920). Monotonic descent iter0 to iter7 (-1187 to -1138, no regression), so chain still actively improving. Harvest gate: matched-n eval against v1.1 production (per-plot LL=-0.887, n=1255). Current iter7 best slightly worse per-plot but the matched-n eval is the real test.

Both chains use per-species apply_theta against the state SppEcoregionData baselines. `harvest_t2_chains.py --state {ST}` runs the matched-n eval. Monitor: `bash perseus/tools/check_t2v2_chains.sh` (commit 16df0f6).

## Cleared since the 2026-05-21 handoff

Map click to live run; backend SQLite store and API-key auth; Methods Section 3 six-state update with the regional gradient as the headline; matched-n Georgia evaluation confirming Tier 2; v1.2 release tag; Washington plus Maine plus Minnesota plus Wisconsin plus Michigan statewide carbon trajectories from real LANDIS runs; the three-regime and five-state carbon figures; the build-fresh statewide runner; the multiplier-to-carbon internal-consistency validation; CHANGELOG v1.3.

## Suggested next steps

1. Tag v1.3 (this handoff already references it). Comprehensive release marker for the statewide-carbon milestone.
2. Monitor `wa_t2_v2`; when it lands, harvest and update the GUI plus the readiness matrix to reflect WA Tier 2 v2 (likely modest changes to the production vector and possibly the statewide-carbon ratio).
3. Harden the build-fresh runner to auto-serialize concurrent submissions (avoids the `QOSMaxSubmitJobPerUserLimit` hit). Small fix.
4. Optional: Georgia statewide carbon. Needs a template-copy variant since the build-fresh runner does not apply, and Washington already covers the strong-down regime, so the marginal value is low.
5. Optional: fold the new statewide-carbon paragraph into the scenario paper and refresh the synthesis memo with the five-state numbers.

Nothing else is blocked. The repo is in sync, the GUI plus backend are feature-complete for v1, and the methods paper Section 3 contains the headline regional-gradient result with the statewide-carbon consequence.
