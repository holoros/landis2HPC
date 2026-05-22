# PERSEUS / landis2HPC changelog

All notable changes to the multi-state LANDIS-II calibration framework are documented in this file. The framework follows a tag-based release model on `github.com/holoros/landis2HPC`.

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
