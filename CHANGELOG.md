# PERSEUS / landis2HPC changelog

## v1.7 — 2026-06-02 — Ohio promoted (9 states); WA carbon rerun relaunched

The full N3 (Eastern Hardwood Central) cluster is now calibrated. PERSEUS spans nine states.

### Ohio promoted to Tier 2 production
`oh_t2_v2` (densified runner, warmstarted from the IN-calibrated N3 reference) landed all 8
iterations; the harvester promoted `oh_t2_v2_iter6_cand9` at **n=713** (floor 606), per-plot
LL **−0.8625** — a healthy fit, and notably better than IN's −1.3146 on the same cluster.
That OH fits well while IN does not points to an IN-specific issue (data or warmstart), not a
systemic N3 problem.

### Nine-state production table

| State | Region | Production vector | Per-plot LL | n |
|---|---|---|---|---|
| ME | Northeast | Tier 2 v1.0 | +0.056 | 612 |
| WA | West | Tier 2 v2.0 | −0.6254 | 1415 |
| GA | Southeast | Tier 2 v2.0 | −0.8802 | 1249 |
| MN | Great Lakes | Tier 2 v1.2 | −0.9325 | 2741 |
| WI | Great Lakes | Tier 2 v1.2 | −0.6470 | 916 |
| MI | Great Lakes | Tier 2 v1.2 | −0.1292 | 562 |
| IN | Eastern Hardwood (N3) | Tier 2 v3 | −1.3146 | 733 |
| **OH** | **Eastern Hardwood (N3)** | **Tier 2 v2 (oh_t2_v2_iter6_cand9)** | **−0.8625** | **713** |

### WA v1.4.1 statewide-carbon rerun relaunched
The prior `wa_stwide_v2` was cancelled at its 1d12h time limit before producing any
trajectories. Resubmitted as `wa_stwide_v3` (job 11204375) with a **3-day** wall-time, same
WA v2.0 theta and `wa_t2v2_calibrated` output tag. When it lands, refresh
`perseus/figures/statewide_carbon_5state.png` with WA's v2.0 year-100 carbon number.

## v1.6 — 2026-06-01 — Indiana promoted (8 states); OH chain launched

First state added through the hybrid warmstart path. PERSEUS is now eight states.

### Indiana promoted to Tier 2 production
The densified-pairing chain `in_t2_v3` (warmstarted from `in_t2_v2`'s own optimum) landed
all 8 iterations and the harvester promoted it: best `in_t2_v3_iter2_cand11`, **n=733**
paired observations (floor 634, max_n 747), per-plot LL **−1.3146**. The densified LL
pairing did its job — n rose from 201 (5-year-only) to 733, clearing the harvester's
near-full-n floor that blocked `in_t2_v2`. `theta_best_production.csv` written; monitor
reads PROMOTED.

| State | Region | Production vector | Per-plot LL | n |
|---|---|---|---|---|
| ME | Northeast | Tier 2 v1.0 | +0.056 | 612 |
| WA | West | Tier 2 v2.0 | −0.6254 | 1415 |
| GA | Southeast | Tier 2 v2.0 | −0.8802 | 1249 |
| MN | Great Lakes | Tier 2 v1.2 | −0.9325 | 2741 |
| WI | Great Lakes | Tier 2 v1.2 | −0.6470 | 916 |
| MI | Great Lakes | Tier 2 v1.2 | −0.1292 | 562 |
| **IN** | **Eastern Hardwood (N3)** | **Tier 2 v3 (in_t2_v3_iter2_cand11)** | **−1.3146** | **733** |

IN's per-plot LL is the weakest of the eight — Indiana mixed-hardwood dynamics are harder to
fit, and this is a defensible v1 calibration, not a final answer. Flagged for a domain look.

### N3 cluster reference re-frozen from calibrated IN
`state_templates/cluster_N3_reference_theta.csv` now holds IN's production theta (real
values: POST 0.60→0.34, SHO→0.44, etc.) instead of the MN bootstrap, so OH and future
Eastern-Hardwood states warmstart from a calibrated neighbor.

### Ohio builder CRLF fix + chain launched
`build_plot_scenario_OH.sh` failed its smoke test: PRISM_OH_l3.csv is CRLF, so the last
ecoregion column ("71") carried a trailing `\r` and failed the `grep -qx` header check (the
smoke plot was eco 71). Both IN and OH builders now strip `\r` when reading the PRISM header
and when extracting the climate column. OH smoke then passed (rc=0, full biomass output).
`oh_t2_v2` launched (job 11169120) with the densified runner, warmstarted from the
IN-calibrated N3 reference.

### Known incomplete: WA v1.4.1 statewide-carbon rerun
`wa_stwide_v2` (launched 2026-05-30) produced no trajectories — it built its 1354-plot list
then died (wall-time at 1d12h or queue-gate stall). The five-state carbon figure still uses
WA v1.0 values. Needs a re-run with a longer wall-time budget; not auto-relaunched.

## v1.5 — 2026-05-31 — Hybrid warmstart committed + optimizer/monitor hardening

Committed to the architecture-C hybrid warmstart path from `docs/CONUS_expansion_plan.md`
and fixed the two defects behind the 2026-05-29 IN/OH chain death.

### Optimizer timeout hardening (the IN/OH chain killer)
The IN and OH Tier 2 chains died after one iteration because a hung `run_param_set_*.sh`
hit the optimizer's 4 h `subprocess` timeout and the resulting `TimeoutExpired` was
uncaught, crashing the whole CMA-ES driver. The runner subprocess call in every
`cma_es_optimize_*.py` (GA, MN, MI, WI, WA in the repo; plus IN, OH live on scratch) is
now wrapped (`PERSEUS_TIMEOUT_GUARD`): a timeout or any runner exception scores that
candidate as the degeneracy penalty (1e6) and the chain continues. Applied via the
idempotent `patch_optimizer_timeout.py`; all variants recompile.

### Chain monitor fixes (`check_t2v2_chains.sh`)
Rewritten and generalized. Two correctness fixes: (1) promotion is now detected at the
path the harvester actually writes, `<chain>/theta_best_production.csv`, instead of the
never-written `states/<ST>/perseus/production_theta_<chain>.csv` — so harvested WA/GA v2
chains read **PROMOTED** instead of the old false **STALLED**; (2) **STALLED** is reserved
for genuine early death (no jobs, no promotion, <=1 scored iter). It now scans every
`states/*/perseus/bayesian/*` chain (no per-chain edits for the CONUS expansion) and no
longer chokes on empty/legacy chain dirs. Verified live: WA/GA v2 -> PROMOTED, IN/OH ->
STALLED.

### Hybrid warmstart infrastructure
- `perseus/tools/cma_es_optimize_cluster.py`: one generalized, warmstart-capable Tier 2
  driver replacing the per-state copies. Reads the species list from the state's
  `SpeciesData.csv`, seeds x0 from a cluster reference theta (missing species fall back to
  0.60 cold), has the timeout guard built in. Per-cluster symlinks
  `cma_es_optimize_{N1..P4}.py` -> it, so `add_state.sh` resolves.
- `perseus/tools/state_templates/`: cluster reference thetas frozen from calibrated states
  — N1=ME, N2=MN, S1=GA, P3=WA (verbatim production theta) — plus a provisional N3 (IN/OH
  eastern hardwood) reference bootstrapped from MN via a 12-of-23-species crosswalk, with
  the 11 unmapped species recorded in `cluster_N3_extension_species.csv`. Also state-agnostic
  `apply_theta_template.py` and `build_plot_scenario_template.sh` (species block from
  SpeciesData.csv, eco names from ecoregions.txt) that `add_state.sh` sed-renders.
- `add_state.sh`: creates the SLURM `--output` bayesian dir before sbatch (latent crash fix).

### Remaining IN/OH gate (deliberately not auto-run)
`plot_ics_full/` is still empty for IN/OH. `build_plot_ics_MN.py` cannot fill it — its FIA
SPCD->species map only covers MN's pool and would silently drop IN/OH oaks and hickories.
The N3 cluster needs a curated `build_plot_ics_N3.py` SPCD->LANDIS map (domain-sensitive),
which is the one step left for review rather than fabricated-and-launched. See
`perseus/tools/state_templates/README.md`. No calibration compute was launched this session.

## v1.4 — 2026-05-29 — WA and GA promoted to Tier 2 v2.0

Both `wa_t2_v2` and `ga_t2_v2` Tier 2 calibration chains landed on 2026-05-29 (1d 10h elapsed each, wall-time termination, ExitCode 0:0). The n-aware harvester (`harvest_t2_chains.py`) selected the best per-plot LL candidate among near-full-n evaluations and promoted both states.

### Production calibration table (v1.4)

| State | Region | Production vector | Per-plot LL | n | Note |
|---|---|---|---|---|---|
| ME | Northeast | Tier 2 v1.0 final | +0.056 | 612 | unchanged |
| WA | West | Tier 2 v2.0 (iter9_cand4) | -0.6254 | 1415 | promoted from v1.0 iter1_cand11 |
| GA | Southeast | Tier 2 v2.0 (iter8_cand5) | -0.8802 | 1249 | promoted from v1.1 iter5_cand8 (beats by 0.007 per-plot) |
| MN | Great Lakes | Tier 2 v1.2 (iter7_cand0) | -0.9325 | 2741 | unchanged |
| WI | Great Lakes | Tier 2 v1.2 (iter2_cand11) | -0.6470 | 916 | unchanged |
| MI | Great Lakes | Tier 2 v1.2 (iter7_cand5) | -0.1292 | 562 | unchanged |

### WA v1.0 vs v2.0 (25 ANPP per-species)

The new WA vector reshuffles within the same overall regime: median ratio v2/v1 = 0.985, range [0.524, 1.579], median absolute delta 0.111. Median ANPP shifts down very slightly (0.517 to 0.482). The headline "Washington cuts threefold" carbon result is expected to stay in the same neighborhood but the precise year-100 number will move; statewide carbon rerun is the v1.4.1 follow-up.

### Updated

- `perseus/backend/config.py` STATES dict: WA tier label "Tier 2 per-species v2.0"; GA tier label "Tier 2 per-species v2.0"; comment header reflects v1.4 production state.
- `perseus/dashboard/atlas/summary.json`: WA and GA entries updated with v2.0 best_tier, ll_per_plot, previous_production note, and chain status. Atlas version bumped to v1.4 metadata (2026-05-29).
- `perseus/docs/harvester_snapshot_2026-05-29.md`: captured the multi-poll harvester progression that led to the v2.0 picks.

### Discovered (not yet acted on)

Indiana (`in_t2_v1`) and Ohio (`oh_t2_v1`) Tier 2 v1 calibration chains observed in the queue, both at iter0 partial. PERSEUS 8-state expansion appears to be in flight. Expect 5 to 7 days per chain at the standard 8-iter cadence. Will track and harvest in a future release.

### Deferred to v1.4.1

WA statewide carbon rerun under the new v2.0 vector (the 5-state figure still uses v1.0 values for WA). Build-fresh runner is in place (`perseus/tools/run_statewide_buildfresh.sh` with flock hardening from v1.3); needs WA-specific apply_theta_WA_perspecies.py call. Estimated 12 to 24 hours of compute.

### In progress

`in_t2_v1` and `oh_t2_v1` chains continuing. No code work pending.

All notable changes to the multi-state LANDIS-II calibration framework are documented in this file. The framework follows a tag-based release model on `github.com/holoros/landis2HPC`.

## v1.3 — 2026-05-27

Five-state real statewide carbon trajectories and a clean internal-consistency validation between the per-species multipliers and the state-aggregate carbon change. Phase 3 backend hardened and wired into the GUI. Methods Section 3 fully updated to the six-state result with the statewide-carbon paragraph extended.

### Statewide carbon
All five non-Georgia states now have real 100-year LANDIS trajectories for both literature (Tier 0) and calibrated (Tier 2) parameter sets, generated by the new `perseus/tools/run_statewide_buildfresh.sh` for the Minnesota family and the existing `run_t2_best_100yr.sh` for Maine, on top of the Washington atlas trajectories from v1.0.

| State | Region | Lit year-100 (Mg C/ha) | Calibrated year-100 | Ratio | n |
|---|---|---|---|---|---|
| Washington | West | 264 | 87 | 0.33 | 4429 |
| Minnesota | Great Lakes | 131 | 78 | 0.60 | 1035 |
| Wisconsin | Great Lakes | 177 | 118 | 0.67 | 635 |
| Michigan | Great Lakes | 179 | 105 | 0.59 | 400 |
| Maine | Northeast | 103 | 136 | 1.32 | 1220 |

Headline finding: across all five states the year-100 calibrated-over-literature carbon ratio matches each state's median ANPP multiplier within 0.05 (WA 0.33 versus theta 0.30, MN 0.60 versus 0.60, WI 0.67 versus 0.65, MI 0.59 versus 0.63, ME 1.32 versus 1.31). The per-species multiplier and the state-aggregate carbon trajectory carry the same information. Three regimes clearly visible in carbon: West cuts threefold, Great Lakes cut 1.5 to 1.7-fold, Northeast lifts 32 percent. Figure: `perseus/figures/statewide_carbon_5state.png`.

The Great Lakes literature passes initially failed because OSC's `QOSMaxSubmitJobPerUserLimit` rejected the concurrent chunk submissions; reruns serialized via `sbatch --dependency=afterany` succeeded. The build-fresh runner could be hardened to auto-serialize for future state additions.

### Added (GUI)
- `perseus/dashboard/perseus_forest_intelligence_v1.html`: map-click sets the live-run plot id (canonical IC keys for WA, MN, WI, MI via plt_cn join with about 99 percent coverage; GA/ME manual).

### Added (backend, v0.2)
- `perseus/backend/db.py`: SQLite job store so submitted jobs survive a service restart.
- `perseus/backend/app.py`: optional API-key auth on the action endpoint (`PERSEUS_API_KEY` enforces `X-API-Key`; open if unset); CORS for the static GUI; `/health` reports auth mode; `/jobs` returns recent jobs. Validated end to end via TestClient.

### Added (documentation)
- `docs/methods_section3_sixstate_update.md`: paper-ready Section 3 with the six-state production table, regional gradient, per-species structure, and the extended statewide-carbon paragraph covering all five states and the multiplier-to-carbon consistency check.

### Added (figures)
- `statewide_carbon_5state.png` (5-panel, real LANDIS).
- `statewide_carbon_3regimes.png` (3-state intermediate, real LANDIS).
- `statewide_carbon_WA_ME.png` (the original WA versus ME contrast).

### Added (tooling)
- `perseus/tools/run_statewide_buildfresh.sh`: state-parameterized 100-year build-fresh runner for MN-family states, stratified plot set (<=200 per ecoregion), production theta on shared MN inputs, aggregates to a state-median biomass trajectory.

### In progress (next release)
- WA Tier 2 v2 chain running on Cardinal (`wa_t2_v2`, iter0, ~4 hours elapsed); expected to land in roughly a day. May supersede the v1.0 WA T2 production vector.
- Georgia statewide carbon (optional; needs a template-copy runner variant; WA already covers the same strong-down regime).

## v1.2 — 2026-05-21

Minnesota Tier 2 landed (fourth production state); Forest Intelligence GUI and a phase 3 scenario backend shipped; three real-data analyses added. Wisconsin and Michigan chains still finishing.

### Production calibrations
The MN Tier 2 chain (job 10124727) completed 8 CMA-ES iterations (112 candidates).

| State | Tier | Total LL | n_pairs | Per-plot LL |
|---|---|---|---|---|
| Minnesota | T2 per-species v1 (iter7_cand0) | −2556.1 | 2741 | −0.9325 |
| Wisconsin | T2 per-species v1 (iter2_cand11) | −592.6 | 916 | −0.6470 |
| Michigan | T2 per-species v1 (iter7_cand5) | −72.6 | 562 | −0.1292 |

PERSEUS now has **six production states** (ME, GA, WA, MN, WI, MI). The six-state synthesis is in `docs/sixstate_calibration_synthesis_memo.md`: literature productivity bias is a regional gradient, not a global offset. Maine scales up (median ANPP multiplier 1.31); the Great Lakes scale down moderately (MN 0.60, WI 0.65, MI 0.63); Washington and Georgia scale down hard (0.20, 0.31). Figures: `sixstate_literature_bias_gradient.png`, `greatlakes_per_species_structure.png`, and `wa_statewide_carbon_trajectory.png` (literature overstates the Washington year-100 carbon stock by 3x, 264 vs 87 Mg C/ha).

Georgia upgraded from Tier 1 to Tier 2: a matched-n evaluation (uniform θ=0.30 through the GA Tier 2 runner on the same plot subset, n≈1280) gives Tier 1 per-plot LL −0.9603 versus Tier 2 −0.8871, so all six states are now Tier 2 production.

### Added (Forest Intelligence GUI)
- `perseus/dashboard/perseus_forest_intelligence_v1.html`: self-contained CTrees-style app. Default Maine, scenario presets (no management, working forest, moderate climate, high climate plus disturbance, custom), dark-basemap map with real FIA plot coordinates colored by observed / projected / net change, statewide growth curves with climate-scenario overlays, scenario pin and compare with a year-100 delta readout, indicative statewide carbon KPI, Tier 1 calibration ladder with optimum highlight, and a WA Tier 1.5 per-ecoregion theta panel (wet-to-dry gradient). Washington uses real per-plot Tier 1 trajectories; other states use a Chapman-Richards model fallback labeled measured vs modeled.
- `docs/GUI_v1_architecture.md`: vision, three surfaces, five-phase roadmap.

### Added (phase 3 backend)
- `perseus/backend/`: a FastAPI seed (config, cardinal_jobs, app, requirements, README) that submits a single-plot scenario to Cardinal as a SLURM job over SSH and returns the biomass trajectory. SSH-to-sbatch path smoke-tested with a canary job. Needs OSC auth, a job database, and a results cache before exposure.
- `perseus/tools/aggregate_atlas_trajectories.py`: merges per-plot t0/t1 LANDIS trajectories into atlas JSON (GA/ME export merge step).

### Added (analyses)
- `docs/WA_calibration_effect_memo.md` + figure: WA calibration lowers median year-100 biomass 562 to 185 Mg/ha (67%), a level correction not a growth shutdown (53% of plots still accrue).
- `docs/crossstate_literature_bias_memo.md` + figure: regional sign-flip in literature bias (ME scales up, WA/GA scale down).
- `docs/me_tier2_multiplier_structure_memo.md` + figure: ME per-species ANPP vs biomass-ceiling structure; balsam fir the fast-growing short-lived outlier.

### Changed
- README refreshed to four production states, GUI, backend, and analyses.
- Readiness matrix and GUI updated with MN production status.

## v1.1 — 2026-05-21

GA Tier 2 v2 chain landed; harvester hardened against settling-check timeouts; per-state pipeline parity files added.

### Production calibrations
The GA Tier 2 v2 chain (job 10021254) completed 8 CMA-ES iterations (112 candidates). Best production vector by near-full-n per-plot LL:

| State | Tier | Total LL | n_pairs | Per-plot LL |
|---|---|---|---|---|
| Georgia | T2 per-species v2 (iter5_cand8) | −1113.3 | 1255 | −0.8871 |

Tier-comparison caveat: the v1.0 GA production was Tier 1 uniform θ = 0.30 at LL +5.26 over n = 218 (per-plot +0.024). That value is NOT directly comparable to the T2 per-plot LL above, because the two were scored on different paired sets (n = 218 vs n = 1255). A matched-n evaluation of the T1 θ = 0.30 vector against the full n = 1255 set is required before declaring GA Tier 2 superior. GA's production tier therefore remains provisionally Tier 1; the Tier 2 vector is archived as the best per-species candidate pending that comparison.

### Fixed
- `perseus/tools/harvest_t2_chains.py`: n-aware production-vector selection. The prior cma_history fallback trusted the active settling check to guarantee a comparable plot count across candidates, then picked the lowest total negLL. But the settling check can time out under node contention: GA iter5_cand10 ran on only 240/779 plots (n = 398 paired obs), giving a spuriously low total negLL = 367 that is actually a mediocre per-plot fit (−0.9227). The harvester now parses the true paired-observation count and signed LL from each candidate's `launch.log` (`n=NNN ... LL=...`, a format shared by the GA inline-LL and MN/WI/MI runners), requires n ≥ max(MIN_N_PAIRS, 0.85 × max_n) (near-full settling), and selects the highest per-plot LL among those. This is a fourth safeguard over the three-mode degeneracy taxonomy: it defends the sample-size mode from re-entering through a settling-check timeout. Across GA's 112 candidates ~7 had settling shortfalls (n between 300 and 700) that the old fallback could have mis-selected.

### Added (per-state pipeline parity)
- GA/WA initial-community builders (`build_plot_ics_GA.py`, `build_plot_ics_WA.py`), GA multi-cycle plot list (`build_ga_plot_list.py`), GA biomass aggregator (`aggregate_GA_csv.py`).
- CMA-ES objective + likelihood scripts (`likelihood.py`, `likelihood_GA.py`).
- Tier 1 / Tier 1.5 theta application (`apply_theta.py`, `apply_theta_eco.py`).
- Tier-ladder runners and submitters (`run_param_set_GA_t0/t1/t1_v2.sh`, `run_param_set_eco.sh`, `run_param_set_eco_t2.sh`, `run_param_set_t2.sh`, `submit_GA_t0.sh`, `submit_cma_es_tier2.sh`, `submit_cma_es_tier2_resume.sh`, `submit_eco_v3.sh`, `submit_refit.sh`).

### In progress
- MN, WI, MI Tier 2 chains (jobs 10124727, 10126909, 10126910) running at iter1 as of this tag. Provisional per-plot LL snapshots (MN −0.96, WI −0.66, MI −0.17) will be finalized on chain completion.

## v1.0.2 — 2026-05-17

Defense-in-depth patches to both state-specific runners. Validated in production by the GA T2 v2 relaunch.

### Changed
- `perseus/tools/run_param_set_GA_t2.sh`: CHAIN derivation from TAG so the runner serves any vN chain without modification (no more hardcoded `bayesian/ga_t2_v1` path).
- `perseus/tools/run_param_set_WA_t2.sh`: same CHAIN derivation applied as defense-in-depth. Also adds the v1.0.1 active settling check (was originally only on the GA runner).

### Validated in production
GA T2 v2 launch (job 10021254) `launch.log`:

```
chunk 0 -> job 10021255
settling: 20 / 779 landed (waiting for 701, attempt 1/20)
settling: 97 / 779 landed (waiting for 701, attempt 2/20)
settling: 169 / 779 landed (waiting for 701, attempt 3/20)
...
settling: 448 / 779 landed (waiting for 701, attempt 7/20)
```

This is direct empirical confirmation that the runner exits its `squeue -j JID` wait at a moment when only ~20 of 779 array tasks have flushed output, and the settling check correctly waits for the rest before allowing the LL aggregator to proceed. The v1.0 GA T2 deferral was driven by this race condition.

### Production calibrations
No change to v1.0 production calibrations (ME T2, GA T1 θ=0.30, WA T2 iter1_cand11).

## v1.0.1 — 2026-05-17

GA Tier 2 root cause resolution.

### Added
- `docs/GA_T2_root_cause_resolved.md` — full root-cause analysis showing the GA T2 "failure" was actually a race condition in the parent runner, not a per-plot pipeline failure. 629–646 valid biomass_trajectory.csv files existed per candidate but the LL aggregator read at an early moment and found only ~2 of them.

### Changed
- `perseus/tools/run_param_set_GA_t2.sh`: active settling check after the squeue-wait loop. Bounded loop (20 attempts × 30s = 10 min max) waits until ≥ 90% of expected per-plot trajectories are present on the shared filesystem before letting the LL aggregator run.

### Production calibrations
No change to v1.0 production calibrations.

## v1.0 — 2026-05-17

First public release. Manuscript-grade multi-state LANDIS-II Biomass Succession calibration framework.

### Production calibrations
| State | Tier | LL | n_pairs | Per-plot LL |
|---|---|---|---|---|
| Maine | T2 per-species (26 params) | +34.2 | 612 | +0.056 |
| Georgia | T1 uniform θ = 0.30 | +5.26 | 218 | +0.024 |
| Washington | T2 per-species iter1_cand11 (50 params) | −174.4 | 805 | −0.217 |

### Added
- Three-mode calibration degeneracy pathology taxonomy (active-growth, empty-aggregator, sample-size) — paper-novel methodological contribution.
- Three driver guards: active-growth fraction ≥ 0.50, non-empty per_plot.csv, MIN_N_PAIRS ≥ 300.
- Per-plot LL normalization recommendation as a complementary safeguard.
- WA Tier 2 iter1_cand11 production vector (selected by per-plot LL after sample-size guard rejected the raw CMA-ES "best").
- GA Tier 2 deferral memo (`docs/GA_T2_failure_memo.md`).
- v1.0 final 3-state production calibration figure.
- Updated Methods Section 2.6 (Calibration degeneracy pathologies), Section 3.3/3.5/3.7 (production calibration numbers), Section 4.5 (4th limitation paragraph documenting GA T2 deferral), bioRxiv abstract.
- Refreshed co-author review email + v1.0_summary.md one-pager.

### Changed
- `perseus/tools/cma_es_optimize_WA.py`: added MIN_N_PAIRS = 300 guard.
- `perseus/tools/cma_es_optimize_GA.py`: same guard for parity.
- `docs/methods_paper_FINAL_ASSEMBLY.md`: replaced "Final headline numbers" with v1.0 production calibration table; expanded calibration degeneracy section from single mode to three-mode taxonomy.

## v1.0-rc1 — 2026-05-17

Release candidate enabling co-author review while WA T2 v2 + GA T2 chains finished.

### Added
- T2 rc1 theta snapshots (`perseus/theta_best/{WA,GA}_tier2_rc1_theta.csv`).
- CMA-ES convergence figure (`perseus/figures/t2_cma_convergence_2026-05-17.png`).
- 3-panel T2 species multiplier heatmap (ME final + WA/GA rc1).
- v1.0-rc1 summary one-pager (later replaced by v1.0_summary.md).

## v1.0-pre (prior to tagging) — 2026-05-15 to 2026-05-17

Foundational work culminating in the v1.0-rc1 milestone.

### Added
- Full PERSEUS framework (`perseus/`): tools, dashboard, disturbance agents, validation suite.
- Methods paper draft (8 sections, ~9000 words, 16 figures).
- Multi-state plot scenario builder.
- Six validated v8 Apptainer disturbance extensions (Wind, Fire, SBW BDA, SPB BDA, MPB BDA, Hurricane v3).
- Foundation .NET 8 console DLL patches.
- Six-test validation framework (k-fold CV, time-out-of-sample, leave-one-ecoregion-out, cross-state, bootstrap CI, IC perturbation).
- PERSEUS Carbon Atlas v1 dashboard (browser-only, no server).
- Submission prep: Zenodo deposit metadata, bioRxiv preprint plan, Foundation registry submission email.

### Calibrations
- Maine Tier 2 per-species (final).
- Maine Tier 1 ladder (reference).
- Georgia Tier 1 uniform θ = 0.30 (production).
- Washington Tier 1 ladder (full 12-value).
- Washington Tier 1.5 per-ecoregion.
- Washington Tier 1 uniform θ = 0.30 (active-growth constrained).

## Next planned releases

### v1.2 — pending MN / WI / MI Tier 2 chain completion (running at iter1; ~12-15h ETA from 2026-05-21)
- Harvest MN / WI / MI Tier 2 production vectors via the n-aware `harvest_t2_chains.py --all`.
- Six-state production calibration table + species heatmap.
- Matched-n GA Tier 1 (θ = 0.30) vs Tier 2 evaluation to set GA's production tier.
- Methods Section 3.3 refresh with multi-state Tier 2 numbers.

### v2.0 — methods paper acceptance + Zenodo DOI
- Mint Zenodo DOI via GitHub-to-Zenodo webhook.
- Update README + bioRxiv abstract with DOI.
- Final accepted-paper figure refresh.

### v3.0 — companion scenario factorial paper
- Apply v1.0 production calibrations to a 27-cell climate × harvest × disturbance factorial.
- New companion paper: state-scale carbon trajectories under realistic management.
