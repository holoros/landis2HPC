# GitHub release notes (for `Releases` UI on `holoros/landis2HPC`)

Paste each section as the body of the corresponding tag release on GitHub. Each tag should have its own release; use the `v1.0` release as the entry point that links to the manuscript + Carbon Atlas dashboard.

---

## v1.0 — Multi-state LANDIS-II calibration framework

**Released 2026-05-17. Anchor release for the PERSEUS methods paper.**

PERSEUS is a four-tier calibration framework for LANDIS-II Biomass Succession against the USDA Forest Inventory and Analysis (FIA) multi-cycle hindcast. v1.0 includes production calibrations for Maine, Georgia, and Washington forests; six validated v8 Apptainer disturbance extensions; the Foundation .NET 8 DLL patches required for v8 extension loading; a six-test validation framework; and a paper-novel three-mode calibration degeneracy taxonomy with corresponding driver guards.

### Production calibrations (manuscript-grade)

| State | Tier | LL | n_pairs | Per-plot LL | 100-yr biomass shift vs T0 |
|---|---|---|---|---|---|
| Maine | T2 per-species (26 params) | +34.2 | 612 | +0.056 | −7.5% |
| Georgia | T1 uniform θ = 0.30 | +5.26 | 218 | +0.024 | −35% |
| Washington | T2 per-species iter1_cand11 (50 params) | −174.4 | 805 | −0.217 | −67% |

Vectors at [`perseus/theta_best/`](perseus/theta_best). GA Tier 2 deferred to v1.x pending pipeline diagnostic — see `docs/GA_T2_failure_memo.md` and v1.0.1 release notes.

### Headline empirical finding

Literature LANDIS-II Biomass Succession parameters are biased in **opposite directions** across the three regions:

- **Maine**: literature systematically *under*-estimated regional growth (multipliers cluster 0.84–2.26, median ~1.30).
- **Georgia & Washington**: literature systematically *over*-estimated regional growth (WA multipliers 0.31–0.91; GA uniform θ = 0.30).

Calibration changes 100-year per-cell biomass asymptotes by 7.5% (ME), 35% (GA), 67% (WA) — substantial for any state-scale carbon analysis using uncalibrated LANDIS-II.

### Paper-novel methodological contribution: three-mode calibration degeneracy taxonomy

Three pathology modes encountered during Tier 2 CMA-ES optimization that the naive log-likelihood objective does not protect against:

| Mode | Mechanism | Guard |
|---|---|---|
| Active-growth | Very low θ → near-zero growth → trivial IC fit | active-growth fraction ≥ 0.50 |
| Empty-aggregator | Per-plot pipeline failure → empty per_plot.csv → LL = 0 default | non-empty per_plot.csv |
| Sample-size | Few successful pairs → trivially small LL magnitude → CMA-ES misled | MIN_N_PAIRS ≥ 300 |

Per-plot LL normalization (LL/n) recommended as a complementary safeguard. Full taxonomy in Methods Section 2.6 of the manuscript and in driver source code at [`perseus/tools/cma_es_optimize_WA.py`](perseus/tools/cma_es_optimize_WA.py).

### What's in this release

- Full PERSEUS framework: `perseus/` with tools, dashboard, disturbance agents, validation suite.
- Methods paper draft: `docs/methods_paper_FINAL_ASSEMBLY.md` + assembled HTML render at `docs/manuscript_renders/PERSEUS_methods_paper_v1.0.html`.
- Six validated v8 Apptainer disturbance extensions: Original Wind, Original Fire, Climate BDA (SBW Maine, SPB Georgia, MPB Washington), Hurricane v3 (Georgia).
- Foundation .NET 8 console DLL patches required for v8 extension loading (`console-patch/`).
- Six-test validation framework: k-fold CV, time-out-of-sample, leave-one-ecoregion-out, cross-state, bootstrap CI, IC perturbation.
- PERSEUS Carbon Atlas v1.0 dashboard: `perseus/dashboard/atlas/` (single-file HTML, browser-only).
- Submission prep: `docs/biorxiv_preprint_plan.md`, `docs/zenodo_deposit_metadata.json`, `docs/landis_foundation_registry_submission.md`.

### Getting started

```bash
git clone https://github.com/holoros/landis2HPC.git
cd landis2HPC && git checkout v1.0
cat docs/v1.0_summary.md       # one-page overview
cat docs/methods_paper_FINAL_ASSEMBLY.md   # manuscript assembly
open perseus/dashboard/atlas/index.html    # Carbon Atlas v1.0
```

### Citation

Weiskittel, A.R., Lucash, M.S., Scheller, R.M. (2026). *Multi-state inverse parameterization of LANDIS-II Biomass Succession against the FIA inventory cycle: a calibration ladder for Maine, Georgia, and Washington forests.* Environmental Modelling & Software, submitted. github.com/holoros/landis2HPC (v1.0).

---

## v1.0.1 — GA T2 root cause resolution

**Released 2026-05-17 (same day as v1.0).**

Post-v1.0 root cause analysis revealed that the v1.0 Georgia Tier 2 deferral was driven by a race condition in the parent runner — not a per-plot pipeline failure as initially documented. Closer inspection of preserved candidate directories showed 629–646 valid biomass_trajectory.csv files per candidate, but the LL aggregator read at a moment when only ~2 of them had landed on the shared filesystem.

### Fix

Active settling check added to `perseus/tools/run_param_set_GA_t2.sh` after the SLURM `squeue` wait. Aggregator now waits until ≥ 90% of expected trajectories are on disk before computing LL.

### What this means

The v1.0 GA T2 calibration deferral can be revisited with the patched runner. A v1.x release will include the GA T2 re-run vector if the chain produces n ≥ 300 paired plots for the best candidate.

**No change to v1.0 production calibrations.** This is a tooling patch.

### Reading

Root cause memo: [`docs/GA_T2_root_cause_resolved.md`](docs/GA_T2_root_cause_resolved.md).

---

## v1.0.2 — Runner generalization + defense-in-depth

**Released 2026-05-17 (same day as v1.0.1).**

Two small patches applied to both state-specific T2 runners:

1. **CHAIN derivation from TAG via parameter expansion.** The runner can now serve any vN chain (`ga_t2_v1`, `ga_t2_v2`, `wa_t2_v1`, ...) without modification. v1.0 had `bayesian/ga_t2_v1` hardcoded.

2. **Active settling check applied to the WA runner too** as defense-in-depth, even though WA T2 wasn't observably affected by the race condition in v1.0.

### Validation in production

GA T2 v2 launch (job 10021254) `launch.log` shows the settling check working as designed:

```
chunk 0 -> job 10021255
settling: 20 / 779 landed (waiting for 701, attempt 1/20)
settling: 97 / 779 landed (waiting for 701, attempt 2/20)
settling: 169 / 779 landed (waiting for 701, attempt 3/20)
...
settling: 726 / 779 trajectories landed (>= 701)
n=1286 mean=-0.1175 sd=0.6444 LL=-1259.07
```

The runner exits its `squeue` wait at the moment only ~20 of 779 array tasks have flushed output. The settling check correctly held back the LL aggregator until 726 were present.

**No change to v1.0 production calibrations.** This is a tooling patch.

### What's next (v1.x roadmap)

- **GA T2 v2 chain landing.** Job 10021254 running on Cardinal as of 2026-05-17 23:35 EDT. ETA ~16 hours. If it produces a credible Tier 2 GA vector with n ≥ 300 paired plots, v1.x will update Section 3.3 + the production calibration table to swap GA T1 → GA T2.
- **Zenodo DOI mint** via GitHub-to-Zenodo webhook at the v1.0 tag.
- **bioRxiv submission** per `docs/biorxiv_preprint_plan.md`.
- **Foundation registry submission** per `docs/landis_foundation_registry_submission.md`.
