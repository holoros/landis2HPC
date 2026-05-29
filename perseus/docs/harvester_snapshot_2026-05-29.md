# T2 v2 harvester snapshot — 2026-05-29 (mid-chain)

Snapshot of `harvest_t2_chains.py --all` run while both `wa_t2_v2` and `ga_t2_v2` chains are still RUNNING (both at iter8 partial). The harvester picks the candidate with the best per-plot LL among near-full-n candidates (`n >= max(300, 0.85*max_n)`).

## Harvester output

| State | Selected | LL_total | n | per-plot LL | max_n | floor | Verdict |
|---|---|---|---|---|---|---|---|
| WA | `wa_t2_v2_iter7_cand8` | -943.6 | 1493 | **-0.6320** | 1552 | 1319 | NEW vector (different from v1.0) |
| GA | `ga_t2_v2_pre_warmstart_iter5_cand8` | -1113.3 | 1255 | -0.8871 | 1367 | 1161 | NO change (same as v1.1 production) |
| MN | `mn_t2_v1_iter7_cand0` | -2556.1 | 2741 | -0.9325 | 2867 | 2436 | NO change (v1.2 production) |
| WI | `wi_t2_v1_iter2_cand11` | -592.6 | 916 | -0.6470 | 1012 | 860 | NO change (v1.2 production) |
| MI | `mi_t2_v1_iter7_cand5` | -72.6 | 562 | -0.1292 | 562 | 477 | NO change (v1.2 production) |

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

## GA verdict detail

The chain has not yet improved over v1.1 per the matched-n eval, even though iter7 cand0 has the lowest aggregate LL (-1138.67). On a per-plot basis with n=1239, iter7 cand0 is at -0.920, worse than the warmstart seed (v1.1 production candidate) at -0.887. The harvester correctly picks the warmstart seed.

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
