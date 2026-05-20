# PERSEUS / landis2HPC changelog

All notable changes to the multi-state LANDIS-II calibration framework are documented in this file. The framework follows a tag-based release model on `github.com/holoros/landis2HPC`.

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

### v1.x — pending GA T2 v2 chain completion (~12-15h ETA, started 2026-05-17 23:35 EDT)
- GA Tier 2 per-species vector (if chain produces n ≥ 300 paired plots for the best candidate) — replaces GA Tier 1 in the production calibration table.
- Methods Section 3.3 refresh with GA Tier 2 numbers if landed.
- v1.x species heatmap with all three states at Tier 2.

### v2.0 — methods paper acceptance + Zenodo DOI
- Mint Zenodo DOI via GitHub-to-Zenodo webhook.
- Update README + bioRxiv abstract with DOI.
- Final accepted-paper figure refresh.

### v3.0 — companion scenario factorial paper
- Apply v1.0 production calibrations to a 27-cell climate × harvest × disturbance factorial.
- New companion paper: state-scale carbon trajectories under realistic management.
