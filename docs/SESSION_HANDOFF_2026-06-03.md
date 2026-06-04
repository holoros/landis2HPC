# PERSEUS session handoff — 2026-06-03

**Repo:** github.com/holoros/landis2HPC, branch main, in sync with origin
**Latest tag:** v1.8 (2026-06-02)
**Latest commit:** 035b059 (runner v18b hardening)
**Zenodo DOI:** 10.5281/zenodo.20526411 (concept DOI; v1.8 deposit live)
**Supersedes:** SESSION_HANDOFF_2026-06-02b

## 1. Headline state

**v1.8 is published and citable.** The 8-state Tier 2 production framework, 5-state statewide carbon, methods Section 3, and the IN LL outlier memo are all on Zenodo with the concept DOI **10.5281/zenodo.20526411**. The methods paper can now cite the framework formally.

PERSEUS spans 8 states at Tier 2 production: ME, WA, GA, MN, WI, MI, IN, OH. Production calibrations unchanged from v1.7/v1.8 handoffs. WA v2.0 statewide carbon is the v1.8 headline (year-100 ratio 0.55, was 0.33 under v1.0).

## 2. What's running now on Cardinal

| Job | What | Wall | State | Notes |
|---|---|---|---|---|
| 11262262 | `in_stwide_t1` — IN v3 calibrated statewide carbon | 3-day | RUNNING (1m elapsed) | resubmit after QOSMaxSubmit fail |
| 11262263 | `oh_stwide_t0` — OH literature statewide carbon | 3-day | RUNNING | resubmit |
| 11262264 | `oh_stwide_t1` — OH v2 calibrated statewide carbon | 3-day | RUNNING | resubmit |

OSC queue at 868 (massive — the resubmitted orchestrators may hit QOSMaxSubmit again, but the new v18b runner has 10-retry exponential backoff up to 50 minutes per retry, so they should land within the 3-day wall time).

The v1.10 launch script (`/users/PUOM0008/crsfaaron/launch_v110_in_v2.sh`) is staged and ready to fire once v1.9 lands.

## 3. v1.9 partial fail and what we did about it

The original 4 v1.9 jobs (11207175-78) all completed CLEANLY (ExitCode 0:0) but only **IN_t0 produced any data**.

**Root cause:** OSC `QOSMaxSubmitJobPerUserLimit`. The 4 orchestrators each waited at the queue gate. IN_t0 got through first, fired its chunk (a 853-element SLURM array). The other 3 tried to submit when IN_t0's chunk completed, but their sbatch calls were rejected by the QOS limit. The runner had no retry — it logged the failure and proceeded to the aggregation step, which produced empty state_trajectory.csv files.

**IN_t0 partial result.** Even where the chunk submitted successfully, only 212 of 853 plots produced biomass_trajectory.csv files before the orchestrator's settling loop (20 attempts x 30s = 10 minutes) gave up. The chunk's SLURM array elements were still running but the orchestrator didn't wait. IN_t0's published trajectory is built from those 212 plots.

| | year 0 | 25 | 50 | 75 | 100 |
|---|---|---|---|---|---|
| IN literature year-100 median biomass (n=198) | 95 | 370 | 484 | 581 | 657 Mg/ha |

At C_frac 0.47, year-100 = 309 Mg C/ha for IN literature. This is the upper-bound under literature multipliers; the calibrated trajectory (in_stwide_t1) is needed for the v1.9 carbon ratio.

**The fix (commit 035b059):** `run_statewide_buildfresh.sh` v18b hardening adds:
1. QOSMaxSubmit retry loop with exponential backoff: 10 retries, 5/10/15/...min between attempts (50 min max).
2. Settling loop extended from 20 attempts (10 min) to 60 attempts (30 min).

Both fixes deployed to Cardinal and committed to repo. The 3 resubmits are now running on the patched runner.

## 4. v1.10 prep status (ready to fire)

Single-shot launch script at `perseus/tools/launch_v110_in_v2.sh` (commit a6381f6):
1. Creates `states/IN_v2/` pseudo-state with symlinked inputs (states/IN/inputs_v2/ -> v2 species pool with COTT + SIM added)
2. Rebuilds ICs with build_plot_ics_N3_v2.py (SPCD 742 -> COTT, 317 -> SIM)
3. Sed-generates build_plot_scenario_IN_v2.sh + run_param_set_IN_v2_t2.sh from v1 templates
4. Pads in_t2_v3 production theta (46 -> 50 entries) with 1.0 for COTT + SIM
5. Smoke-tests one plot scenario
6. Submits CMA-ES driver via `--state IN_v2`

Production paths (states/IN/inputs, run_param_set_IN_t2.sh) untouched. To fire:

```bash
bash /users/PUOM0008/crsfaaron/launch_v110_in_v2.sh
```

Expected: 1.5-day chain, then 12-24h v1.10 statewide carbon = ~3 days end-to-end. Same workflow then applies to OH.

## 5. Zenodo deposit (the v1.8 headline)

DOI: **10.5281/zenodo.20526411**
Record: https://zenodo.org/record/20526411
Files: 29 (8 production thetas + 10 statewide trajectories + figure + 5 docs + README/CITATION/dictionary/metadata)
Size: 228 KB
Community: forestry
License: CC-BY-4.0
Token: created via Chrome (perseus-v1.8-deposit), used, **revoked** after publish. Local token file zeroed.

The deposit token process was scripted: Chrome navigation -> token form fill -> capture from results page -> ssh-stdin pipe to Cardinal -> upload script -> token revocation via Chrome. Repeatable for v1.9/v1.10 (use `new_version.py` from the zenodo-deposit skill).

The repo has a permanent reference at `docs/zenodo_v1.8_deposit.md` (commit 5c5be7e) with the DOI and citation.

## 6. Open items (priority order)

1. **Wait for v1.9 resubmits** (jobs 11262262-64). When they land, build the 7-state carbon figure, refresh atlas + methods, ship v1.9. New `new_version.py` Zenodo upload as v1.9. Likely 1-3 days depending on OSC queue dynamics.

2. **Fire v1.10 launcher** once v1.9 ships. Expected per-plot LL improvement for IN from -1.31 toward -0.5 to -0.9 range. If COTT+SIM works for IN, re-freeze the N3 cluster reference theta from the new IN production, then apply the same fix to OH.

3. **Investigate IN_t0 plot failure pattern.** The 212/853 success rate suggests something is failing for many IN plots even on literature parameters. Could be: (a) build_plot_scenario_IN.sh errors on specific ICs; (b) LANDIS-II errors on bottomland plots where the IC has species the SppEcoregionData doesn't fit; (c) IC builder included plots without modeled-species coverage. Worth a forensic look at one of the c0_*.err files in the in_statewide_t0/ dir.

4. **GA + ME standard pipeline backfill** (Tasks #5, #11). Lower priority but unblocks GA statewide carbon and tidies backend/config.py's stale ME builder reference. ~1-2 days each.

5. **Continue CONUS expansion** per `docs/CONUS_expansion_plan.md`. The `add_state.sh` wrapper template (commit 3a6cd4f) is in place. Pilot a new state from N1 (NH or VT against ME) or N2 (KY against MN cluster) when ready. Note: ME pipeline backfill is on the critical path for N1 since ME doesn't have a standard build_plot_scenario_ME.sh.

## 7. What changed since 2026-06-02b

- v1.8 deposited to Zenodo (DOI 10.5281/zenodo.20526411); package staged + uploaded + published + token revoked
- v1.9 4 jobs ran to completion, 3 failed at submit due to QOSMaxSubmit, IN_t0 produced partial data (212/853 plots)
- Runner v18b: QOSMaxSubmit retry + 60-attempt settling (commit 035b059)
- 3 v1.9 jobs resubmitted on patched runner
- v1.10 launcher staged as single command
- IN LL outlier memo added to repo; documents COTT+SIM fix rationale

## 8. Operational notes

- **SSH:** session key at `outputs/.session_ssh/id_osc`; works directly as Cardinal identity. Copy + chmod in same bash call (login node hopping clears /tmp).
- **Queue dynamics:** OSC c30m_pred bursts can sustain queue at 500-800 for 24+ hours. Statewide jobs throttle behind those bursts. Newer runner (v18b) retries QOSMaxSubmit with backoff so this is no longer a hard fail.
- **Zenodo workflow:** for v1.9, use `new_version.py` from zenodo-deposit skill with parent DOI 10.5281/zenodo.20526411. Need a fresh token (the perseus-v1.8-deposit one was revoked). Token + token file mode 600, then run from Cardinal under tmux.
- **Monitor v1.10 prep:** `cat /fs/scratch/PUOM0008/crsfaaron/landis2/states/IN_v2/perseus/bayesian/in_v2_t2_v1/driver.out` after launch.
- **GitHub:** in sync with origin at 035b059. Tags through v1.8.

## 9. Tasks (current)

| ID | Subject | Status |
|---|---|---|
| 5 | Build missing build_plot_scenario_{GA,ME}.sh adapters | pending |
| 11 | Backfill ME standard pipeline | pending |
| 13 | v1.9 ship: IN + OH statewide carbon | in_progress (3 jobs resubmitted; IN_t0 partial result already in hand) |
| 15 | v1.10 prep: IN COTT+SIM | in_progress (launcher staged, fires on one command) |
| 16 | Zenodo deposit v1.8 | **completed** (DOI live) |

Nothing else immediately actionable. Repo is at a clean v1.8 milestone with a citable DOI; the framework can ship more cleanly than at any prior point in the session.
