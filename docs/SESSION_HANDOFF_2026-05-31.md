# PERSEUS session handoff

**Date:** 2026-05-31
**Repo:** github.com/holoros/landis2HPC, branch main, in sync with origin
**Latest commit at session start:** 3a6cd4f (CONUS v2.0 prep: 13-cluster ecoregion scheme + add_state.sh)
**Latest tag:** v1.4 (WA and GA promoted to Tier 2 v2.0)

## One paragraph summary

This was an operational review session, not a compute session. Cardinal access was re-established, the local mounted repo was resynced from 8dc2e22 to 3a6cd4f (it had fallen nine days behind origin), and the hpc-cardinal skill SSH keys were restored. The substantive finding is that the eight-state CONUS expansion is stalled: both Indiana and Ohio Tier 2 v1 calibration chains died on 2026-05-29 after a single failed iteration, and the cause is now fully diagnosed. The WA statewide-carbon rerun (v1.4.1) is still running and will finish on its own. No production calibration changed this session; v1.4 remains current.

## Live Cardinal state (verified 2026-05-31)

No LANDIS jobs are running. The active queue is all non-LANDIS work (CONUS/CBM/FVS calibration: `c30m_pre`, `s2_conus`, `ak60_c7c`, `wa_stwide`). One relevant LANDIS-adjacent job is in flight:

| Job | Name | State | Runtime / limit | Meaning |
|---|---|---|---|---|
| 11105683 | wa_stwide_v2 | RUNNING | 1d 02h / 1d 12h | v1.4.1 WA statewide-carbon rerun under the new Tier 2 v2.0 vector |

Output target: `states/WA/perseus/statewide/wa_t2v2_calibrated/` (dir created 2026-05-30 05:47, run in progress). When it lands, refresh the WA year-100 carbon number and the five-state carbon figure (`perseus/figures/statewide_carbon_5state.png`), which still uses WA v1.0 values. This closes v1.4.1. Nothing to do until the job completes (roughly within 10 hours of this writing).

## Production calibration (unchanged, v1.4)

| State | Region | Production vector | Per-plot LL | n |
|---|---|---|---|---|
| ME | Northeast | Tier 2 v1.0 final | +0.056 | 612 |
| WA | West | Tier 2 v2.0 (iter9_cand4) | -0.6254 | 1415 |
| GA | Southeast | Tier 2 v2.0 (iter8_cand5) | -0.8802 | 1249 |
| MN | Great Lakes | Tier 2 v1.2 (iter7_cand0) | -0.9325 | 2741 |
| WI | Great Lakes | Tier 2 v1.2 (iter2_cand11) | -0.6470 | 916 |
| MI | Great Lakes | Tier 2 v1.2 (iter7_cand5) | -0.1292 | 562 |

Note: `check_t2v2_chains.sh` reports WA and GA v2 chains as "STALLED (no jobs, no production_theta)". This is a false alarm from the monitor's heuristic, not a regression. Both chains terminated cleanly at wall-time on 2026-05-29 and were already harvested and promoted in v1.4. The global-best LLs the monitor prints (WA iter9_cand4 -884.97, GA iter8_cand5 -1099.40) are exactly the v1.4 picks. Consider teaching the monitor to recognize the harvester's output filename so it stops flagging landed-and-promoted chains.

## IN/OH expansion: STALLED, root cause confirmed

Both Tier 2 v1 chains were submitted 2026-05-29 10:42 and were dead by 15:49 with only `iter0/cand0` recorded (`negLL=1000000.00`, the failure-penalty sentinel). Driver jobs 11082679 (IN) and 11082680 (OH) show `COMPLETED 0:0` in sacct, which is misleading.

**Primary cause: initial-community rasters were never built.** `states/IN/perseus/plot_ics_full/` and `states/OH/perseus/plot_ics_full/` are both empty (0 `plot_*.tif`). Every per-plot LANDIS evaluation therefore fails instantly (the per-candidate worker array jobs each ran 8 to 22 seconds, far below the ~20 min a real plot sim takes), and the candidate objective returns the 1000000 penalty. With every candidate returning an identical penalty, CMA-ES has no signal. This is the exact gap the 2026-05-21 handoff flagged: "IN and OH still need FIA states 18 and 39 downloaded plus initial-community rasters." FIA, SppEcoregionData, plot_to_ecoregion, climate inputs, and the build_plot_scenario adapters are all present; only the IC rasters are missing.

**Secondary cause: brittle timeout handling.** On `cand1` the runner `run_param_set_IN_t2.sh` hung and hit the optimizer's 14400 s (4 h) `subprocess.run` timeout. The resulting `TimeoutExpired` is uncaught in `cma_es_optimize_IN.py` (line 140 -> 63), so it crashes the entire driver rather than scoring that candidate as a penalty and continuing. Even with IC rasters fixed, a single hung plot run would kill the chain again. Worth wrapping the `evaluate()` subprocess call in a try/except that returns the penalty on timeout.

## Decisions needed before IN/OH can resume (do NOT auto-run)

Resuming IN/OH means building ~500 IC rasters per state and then a multi-day calibration chain on the allocation. That spend should not start on autopilot, and there is an architecture fork to settle first:

1. **Build IN/OH IC rasters** via `build_plot_ics_MN.py` (state SPCD swap) for the existing per-state cold-start chains, then resubmit, OR
2. **Switch IN/OH to the cluster-warmstart path** proposed in `docs/CONUS_expansion_plan.md` (architecture C, hybrid). That plan recommends warmstarting from a regional cluster-mean theta, which would make the current cold `in_t2_v1`/`oh_t2_v1` chains obsolete. The plan explicitly says "Aaron's review needed before commitment" and chooses among per-state (A), per-ecoregion (B), and hybrid (C).

Blocker for option 2: `add_state.sh` (committed 2026-05-30) depends on `tools/state_templates/` (cluster reference theta + extension species CSVs). That directory **does not exist on Cardinal yet**, so the warmstart wrapper is not runnable. The per-cluster `cma_es_optimize_*.py` scripts also do not exist yet (only per-state ones: GA, IN, MI, MN, OH, WA, WI, plus `cardinal`).

## Done this session

- Re-established Cardinal SSH (uploaded `cardinal_key` verified as the registered tertiary key, SHA256 oFxOjmd...c54).
- Restored `.ssh-keys/` into the writable hpc-cardinal skill copies (`Documents/Claude/skills/` and `combined-skills/`); the live read-only mount had lost them, forcing a fallback to the 2026-05-23 backup. The live skill folder should be re-synced so future sessions do not depend on the backup.
- Resynced the mounted repo to 3a6cd4f; pulled tags v1.2, v1.3, v1.4.
- Diagnosed the IN/OH chain failure to root cause (above).

## Suggested next steps

1. **Wait for `wa_stwide_v2` (11105683) to land**, then refresh the WA year-100 carbon number and the five-state figure; ship as v1.4.1.
2. **Decide the CONUS architecture (A/B/C)** before touching IN/OH. If staying per-state for now, the minimal unblock is building IN/OH IC rasters and resubmitting; if going hybrid, build `tools/state_templates/` cluster references and the per-cluster optimizer first.
3. **Harden `cma_es_optimize_*.py`** so a per-candidate `TimeoutExpired` returns the penalty instead of crashing the driver.
4. **Teach `check_t2v2_chains.sh`** to recognize harvested/promoted chains so landed states stop reading as STALLED.

## Open tasks

| ID | Subject | Status |
|---|---|---|
| 9 (prev) | WA statewide carbon rerun under v2.0 (v1.4.1) | in flight (job 11105683) |
| 7 (prev) | IN/OH chains land -> 8 states | BLOCKED: IC rasters missing + architecture decision pending |
| new | Harden optimizer subprocess-timeout handling | pending |
| new | Build tools/state_templates/ for add_state.sh warmstart | pending (gates CONUS phase 1) |
