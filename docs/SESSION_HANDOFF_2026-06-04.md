# PERSEUS session handoff — 2026-06-04

**Repo:** github.com/holoros/landis2HPC, branch main, in sync with origin
**Latest tag:** v1.9 (2026-06-04)
**Latest commit:** a01b924 (v1.9: IN+OH statewide carbon)
**Zenodo DOI:** 10.5281/zenodo.20526411 (concept DOI; v1.8 deposit live)
**Supersedes:** SESSION_HANDOFF_2026-06-03

## 1. Headline state

PERSEUS now has **7 states with completed statewide carbon trajectories** (WA, MN, WI, MI, ME, IN, OH). v1.9 added the Eastern Hardwood Central cluster (IN + OH). The 7-state carbon figure shows three regimes intact: Northeast +32 percent, Great Lakes and Eastern Hardwood 1.5 to 1.7-fold cut, West about-in-half cut.

**v1.10 IN COTT+SIM re-calibration chain just submitted** (setup job 11295753) — running on autopilot to address IN's per-plot LL outlier (-1.31 vs cluster sibling OH's -0.86) and to lift IN/OH statewide n from ~190 (currently failing many bottomland plots) by adding eastern cottonwood and silver maple as their own LANDIS species.

## 2. Seven-state year-100 carbon (v1.9 published)

| State | Region (cluster) | Lit (Mg C/ha) | Cal | Ratio | n |
|---|---|---|---|---|---|
| WA | West (P3) | 264 | 144 | 0.55 | 1195 |
| MN | Great Lakes (N2) | 131 | 78 | 0.60 | 1035 |
| WI | Great Lakes (N2) | 177 | 118 | 0.67 | 635 |
| MI | Great Lakes (N2) | 179 | 105 | 0.59 | 400 |
| ME | Northeast (N1) | 103 | 136 | 1.32 | 1220 |
| **IN** | **Eastern Hardwood (N3)** | **309** | **190** | **0.61** | **193** |
| **OH** | **Eastern Hardwood (N3)** | **290** | **172** | **0.59** | **173** |

IN and OH (0.61, 0.59) sit between WA's strong cut and Great Lakes' moderate cuts. The Eastern Hardwood Central cluster fits the regional gradient.

**Caveat on IN+OH n:** only ~22 percent of stratified plots produced valid trajectories (vs 50-90 percent for other states). The shortfall is plot-level LANDIS-II failure during scenario runtime, likely from the N3 cluster's bottomland species lumping (cottonwood -> QA, silver maple -> RM). v1.10 addresses this directly.

## 3. What's running now on Cardinal

| Job | What | Wall | State | Notes |
|---|---|---|---|---|
| 11295753 | `v110_setup` — runs `launch_v110_in_v2.sh` end-to-end | 1h | PENDING | Creates IN_v2 state, rebuilds ICs, smoke-tests, submits CMA-ES driver |

The launcher (`/users/PUOM0008/crsfaaron/launch_v110_in_v2.sh`) wrapped in a 1h SLURM job to survive login-node disconnects. Inside the wrapper it will:
1. Create `states/IN_v2/` pseudo-state with symlinked inputs (states/IN/inputs_v2/ = 25 species pool)
2. Rebuild ICs using build_plot_ics_N3_v2.py (SPCD 742 -> COTT, 317 -> SIM)
3. Generate v2 runner + scenario builder via sed
4. Pad in_t2_v3 production theta (46 -> 50 entries with literature 1.0 for COTT + SIM)
5. Smoke-test one plot
6. Submit CMA-ES driver via `cma_es_optimize_cluster.py --state IN_v2 --tag in_v2_t2_v1 --warmstart <padded>`

The CMA-ES chain runs separately for ~1.5 days. When v110_setup completes (~30 min) check `/users/PUOM0008/crsfaaron/v110_setup.out` for the chain job ID and a smoke-test success line.

## 4. Runner v18b hardening (v1.9 dependency, commit 035b059)

The original 4 v1.9 jobs (11207175-78) failed: 3 of 4 hit OSC `QOSMaxSubmitJobPerUserLimit` during chunk submit; the 4th (IN_t0) gave up at 20-attempt settling (10 min) before its chunk array finished. Two fixes deployed:

1. **QOSMaxSubmit retry loop**: 10 retries with exponential backoff (5, 10, 15, ... 50 minutes). Detects the OSC quota error specifically and only retries that. Non-retryable errors still fail fast.
2. **Settling loop extended**: 20 attempts -> 60 attempts (10 min -> 30 min).

Both fixes are in production. The 3 resubmits (jobs 11262262-64) used them and completed cleanly with 173-193 plots each. The patched runner is reusable for v1.10's statewide carbon refresh.

## 5. v1.8 Zenodo deposit (still live)

DOI: **10.5281/zenodo.20526411** (concept DOI)
Record: https://zenodo.org/record/20526411
Files: 29 (8 production thetas + 10 statewide trajectories + figure + 5 docs)

**Pending v1.9 deposit as new version.** Use the `new_version.py` workflow from the zenodo-deposit skill against the parent DOI. Needs a fresh Zenodo token from Aaron (the perseus-v1.8-deposit token was revoked after publish). The deposit package can reuse most of v1.8's files; replace `figures/statewide_carbon_5state.png` with `figures/statewide_carbon_7state.png`, add `statewide_carbon/{IN,OH}_{t0,t1}.csv`, refresh `zenodo_metadata.json` version string to 1.9.0.

## 6. v1.10 prep (in flight)

If the COTT+SIM hypothesis holds, expect:
- IN per-plot LL: -1.31 -> -0.5 to -0.9 range (toward OH's -0.86)
- IN statewide n: ~190 -> ~400+ (bottomland plots no longer fail)
- IN/OH carbon ratios may shift slightly (likely toward 0.55 or so given new bottomland productivity captured)

If hypothesis fails (LL unchanged), v1.10 still proves the species pool extension works mechanically. Either way, the v2 infrastructure (apply_theta_IN_v2, build_plot_ics_N3_v2, inputs_v2/) is reusable for future Eastern Hardwood states (KY, TN, MO, IL, IA under the CONUS plan).

## 7. Suggested next steps (priority order)

1. **Monitor v1.10 setup job 11295753** (~30 min): verify `launch_v110_in_v2.sh` completes without error and the CMA-ES driver job ID appears in v110_setup.out. If it errors, debug from the .err file.
2. **Wait for v1.10 IN chain** (~1.5 days): `bash check_t2v2_chains.sh in_v2_t2_v1`. When it lands, harvest and assess vs v1.9 IN.
3. **If IN v1.10 improves**: re-freeze cluster N3 reference theta from new IN production, apply same fix to OH (clone launcher for OH_v2).
4. **v1.9 Zenodo new version**: needs fresh token + Aaron's go-ahead. Package staging is mechanical (reuse v1.8 with file swaps).
5. **GA + ME standard pipeline backfill** (Tasks #5, #11). Lower priority; unblocks GA statewide carbon and tidies backend/config.py's stale ME builder reference.
6. **Continue CONUS expansion** per `docs/CONUS_expansion_plan.md`. `add_state.sh` template ready. N1/N2/S1/N3/P3 cluster references exist; blend clusters need literature work.

## 8. What changed since 2026-06-03

- v1.9 SHIPPED (commit a01b924, tag v1.9): IN+OH statewide carbon, 7-state figure, atlas updated, CHANGELOG entry
- 3 v1.9 resubmits (jobs 11262262-64) all completed cleanly on the v18b runner
- v1.10 setup job submitted (11295753); will launch the IN_v2 calibration chain
- All 4 v1.9 trajectory files now in production at `states/{IN,OH}/perseus/statewide/{tag}/state_trajectory.csv`

## 9. Open task list

| ID | Subject | Status |
|---|---|---|
| 5 | Build missing build_plot_scenario_{GA,ME}.sh adapters | pending |
| 11 | Backfill ME standard pipeline | pending |
| 13 | v1.9 ship | **completed** |
| 15 | v1.10 prep + launch | in_progress (launcher fired, chain queueing) |
| 16 | Zenodo v1.8 deposit | completed |

## 10. Operational notes

- **SSH:** session key at `outputs/.session_ssh/id_osc`; copy + chmod in same bash call (login-node hopping clears /tmp).
- **Queue dynamics:** Cardinal queue varies wildly (100 to 868+ during this session). v18b runner now handles QOSMaxSubmit gracefully.
- **Zenodo workflow:** for v1.9, use `new_version.py` from zenodo-deposit skill with parent DOI 10.5281/zenodo.20526411.
- **Monitor v1.10 chain:** `bash /fs/scratch/PUOM0008/crsfaaron/landis2/tools/check_t2v2_chains.sh in_v2_t2_v1` once the CMA-ES driver is submitted.
- **GitHub:** in sync with origin at a01b924 + tag v1.9. Tags: v1.0 through v1.9.
