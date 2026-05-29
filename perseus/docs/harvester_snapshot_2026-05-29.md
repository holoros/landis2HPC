# T2 v2 harvester snapshot — 2026-05-29 (mid-chain, multiple polls)

Snapshot of `harvest_t2_chains.py --all` run while both `wa_t2_v2` and `ga_t2_v2` chains are still RUNNING. Latest poll: WA at iter9 partial (3 cands), GA at iter8 partial (12 cands). The harvester picks the candidate with the best per-plot LL among near-full-n candidates (`n >= max(300, 0.85*max_n)`).

## Harvester output (latest poll)

| State | Selected | LL_total | n | per-plot LL | max_n | Verdict |
|---|---|---|---|---|---|---|
| WA | `wa_t2_v2_iter7_cand8` | -943.6 | 1493 | **-0.6320** | 1552 | NEW vector (stable across 2 polls) |
| GA | `ga_t2_v2_iter8_cand5` | -1099.4 | 1249 | **-0.8802** | 1367 | NEW vector (beats v1.1 by 0.007 per-plot) |
| MN | `mn_t2_v1_iter7_cand0` | -2556.1 | 2741 | -0.9325 | 2867 | NO change (v1.2 production) |
| WI | `wi_t2_v1_iter2_cand11` | -592.6 | 916 | -0.6470 | 1012 | NO change (v1.2 production) |
| MI | `mi_t2_v1_iter7_cand5` | -72.6 | 562 | -0.1292 | 562 | NO change (v1.2 production) |

## GA breakthrough at iter8 (update from earlier snapshot)

Earlier in the day the harvester picked `ga_t2_v2_pre_warmstart_iter5_cand8` (the warmstart seed = v1.1 production candidate, per-plot -0.8871) because no v2 candidate had yet beaten v1.1 on per-plot. As of the later poll, **iter8 cand5 (LL=-1099.40, n=1249, per-plot -0.8802)** has overtaken the warmstart seed by 0.007 per-plot. v2 chain has now improved over v1.1. Once chain lands, GA T2 v2.0 ships and replaces v1.1.

## WA T2 v1.0 vs v2 candidate (iter7 cand8) comparison

| Metric | Value |
|---|---|
| ANPP params | 25 (same set) |
| Median ratio v2 / v1 | 0.985 |
| Range of ratios | [0.524, 1.579] |
| Median |v2 − v1| | 0.111 |
| Max |v2 − v1| | 0.287 |
| Median ANPP v1.0 | 0.517 |
| Median ANPP v2 candidate | 0.482 |

Same overall regime (median ~0.5), reshuffled per-species magnitudes. Some species moved by ±30 percent. The headline "Washington cuts threefold" carbon result is in the same neighborhood; the v2.0 candidate likely gives a slightly lower year-100 carbon (median ANPP shifted down 0.035).

## GA verdict detail (updated)

iter7 cand0 looked like the global aggregate-LL leader at -1138.67 but its per-plot was -0.920 — worse than v1.1. As iter8 cands landed, **iter8 cand5 (LL -1099.40, n=1249)** delivered per-plot -0.8802, finally beating v1.1's -0.8871. Modest but real improvement of 0.007 per-plot. Chain may yet improve further at iter9 or iter10.

## PERSEUS expansion discovered

Two new state chains discovered in the queue (2026-05-29): `in_t2_v1` (Indiana) and `oh_t2_v1` (Ohio), both at iter0 cand0 just launched. The readiness matrix had flagged IN/OH as the highest-leverage expansion (needed only FIA state downloads since the MN pipeline applies directly). These chains will land in roughly 5 to 7 days each. PERSEUS may soon be 8 states. Tracked as Task #7.

## Why this is mid-chain not final

Both chains still in queue: wa_t2_v2 iter8 has 5 of 14 cands landed; ga_t2_v2 iter8 has 2 of 14. Future iters (iter9, iter10) could shift the harvester selection — iter6 cand11 of WA was already the aggregate-LL leader but the harvester preferred iter7 cand8 because of the per-plot floor rule, and a future iter could improve per-plot further.

## Action gate

Do not promote v2.0 to production yet. When chain auto-terminates (verdict from `check_t2v2_chains.sh` flips to LANDED), re-run `harvest_t2_chains.py --all` and compare the new pick to this snapshot. If stable, ship v1.4:

1. Drop `theta_best_production.csv` (WA) into the production location used by the GUI scenario builder
2. Update `perseus/dashboard/atlas/summary.json` and `atlas/WA.json` with the v2.0 metadata
3. Update `perseus/backend/config.py` STATES entry for WA (tier label) and possibly GA + MN + WI + MI (currently `config.py` is out of date: lists GA at Tier 1 and MN at "calibrating")
4. Rerun `wa_statewide_carbon` under the v2.0 vector
5. CHANGELOG v1.4 entry
6. Tag v1.4

If the harvester picks the same candidate (or a per-plot-equivalent one) on chain landing, this snapshot is the trial run for the promotion sequence.
