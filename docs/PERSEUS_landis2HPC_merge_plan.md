# Merging PERSEUS into existing landis2HPC repo

**Existing repo:** `github.com/holoros/landis2HPC` (on Cardinal at `/users/PUOM0008/crsfaaron/repos/landis2HPC`)
**Existing state:** 2 commits, main branch, console-patch + ME factorial pipeline
**Goal:** Integrate PERSEUS multi-state calibration without disrupting existing structure

## Recommended merge strategy: extend, don't replace

The existing `landis2HPC` is the foundation that PERSEUS depends on (the .NET 8 DLL patches make extension loading work). PERSEUS is the scientific framework that *uses* those patches to do multi-state calibration. Merging keeps the foundation visible while adding the calibration layer on top.

## Proposed new repo structure

```
landis2HPC/                                  (existing GitHub repo)
├── README.md                                (UPDATE: now describes both layers)
├── LICENSE                                  (existing)
├── .gitignore                               (existing)
├── build.sh                                 (existing)
│
├── console-patch/                           (existing — UNCHANGED, foundation layer)
│   ├── dist/
│   ├── patches/
│   └── src/
│
├── pipeline/                                (existing — UNCHANGED, original ME factorial)
│   ├── scenario_factorial_subtile.sh
│   └── aggregate_subtile_factorial.R
│
├── docs/                                    (existing — EXPAND)
│   ├── email_landis_foundation.md           (existing)
│   ├── methods_paper_FINAL_ASSEMBLY.md      (NEW from PERSEUS)
│   ├── methods_paper_section_*.md           (NEW from PERSEUS)
│   ├── scenario_paper_*.md                  (NEW from PERSEUS)
│   ├── calibration_degeneracy_finding.md    (NEW from PERSEUS)
│   ├── stress_validation_framework.md       (NEW from PERSEUS)
│   ├── stress_validation_results.md         (NEW from PERSEUS)
│   ├── T2_pairing_fix_resolution.md         (NEW from PERSEUS)
│   ├── disturbance_extensions.md            (NEW from PERSEUS)
│   ├── GUI_scope_memo.md                    (NEW from PERSEUS)
│   ├── deposit_plan.md                      (NEW from PERSEUS)
│   ├── references.bib                       (NEW from PERSEUS)
│   └── handoffs/                            (optional historical processing logs)
│
├── perseus/                                 (NEW top-level dir for PERSEUS layer)
│   ├── README.md                            (PERSEUS-specific intro)
│   ├── tools/                               (22 calibration scripts)
│   │   ├── build_plot_scenario_WA.sh
│   │   ├── build_plot_scenario_factorial.sh
│   │   ├── apply_theta_*.py
│   │   ├── cma_es_optimize_*.py
│   │   ├── run_param_set_*_t2.sh
│   │   ├── aggregate_WA_csv.py
│   │   ├── likelihood_WA.py
│   │   ├── tier15_per_ecoregion_refit.py
│   │   ├── cross_validate_tier2.py
│   │   ├── time_out_of_sample_validation.py
│   │   ├── leave_one_ecoregion_out_cv.py
│   │   ├── bootstrap_tier1_uncertainty.py
│   │   ├── cross_state_diagnostic.py
│   │   ├── submit_WA_t0.sh, submit_WA_t1_ladder.sh
│   │   └── harvest_WA.sh
│   ├── disturbance_agents/                  (6 validated agent files)
│   │   ├── Climate-BDA_Agent_{SBW,SPB,MPB}.txt
│   │   ├── Climate-BDA_SetUp_{SBW,SPB,MPB}.txt
│   │   ├── Hurricane_GA.txt
│   │   └── EvennessWindReductions_GA.csv
│   ├── theta_best/                          (calibrated parameter vectors)
│   │   ├── ME_tier2_theta_best.csv
│   │   ├── WA_tier1_theta_best.csv
│   │   ├── GA_tier1_theta_best.csv
│   │   └── WA_tier15_per_eco.csv
│   ├── figures/                             (16 PNGs — Methods Fig 1-8 + diagnostics)
│   ├── data/                                (untreated_plots_*.csv + lookups)
│   ├── dashboard/                           (Carbon Atlas v0, v1, scenario explorer)
│   │   └── atlas/                           (v1 with real data bundles)
│   └── tests/                               (reproducibility scripts)
│
└── CHANGELOG.md                             (NEW, top-level)
```

## Merge sequence (operational, ~30 min)

```bash
# On Cardinal — direct in-repo work since git is set up
cd /users/PUOM0008/crsfaaron/repos/landis2HPC

# 1. Make sure we're up to date with origin
git pull origin main

# 2. Create perseus/ subdirectory and populate from PERSEUS scratch work
mkdir -p perseus/{tools,disturbance_agents,theta_best,figures,data,dashboard/atlas,tests}

# 3. Copy PERSEUS code from Cardinal scratch into the repo
cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/build_plot_scenario_WA.sh perseus/tools/
cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/build_plot_scenario_factorial.sh perseus/tools/
cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/apply_theta_*.py perseus/tools/
cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/cma_es_optimize_*.py perseus/tools/
cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/run_param_set_*_t2.sh perseus/tools/
cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/aggregate_WA_csv.py perseus/tools/
cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/likelihood_WA.py perseus/tools/
cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/tier15_per_ecoregion_refit.py perseus/tools/
# (continue for all 22 tools)

cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/Climate-BDA_*.txt perseus/disturbance_agents/
cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/Hurricane_GA.txt perseus/disturbance_agents/
cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/EvennessWindReductions_GA.csv perseus/disturbance_agents/

cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/untreated_plots_*.csv perseus/data/
cp /fs/scratch/PUOM0008/crsfaaron/landis2/tools/plot_to_ecoregion_*.csv perseus/data/

# Plus theta_best CSVs + figures + dashboard + paper drafts + tests
# (transfer via scp from local outputs/ — see automation script below)

# 4. Author the perseus/ README and update top-level README to point to both layers

# 5. Update top-level README to reflect both layers

# 6. Commit
git add .
git commit -m "Add PERSEUS multi-state calibration framework (v1.0)

- Calibration code, validated disturbance agents, validated parameter vectors
- Methods paper + scenario paper drafts (Sections 1-5 of both)
- Stress + validation framework + results (5 of 6 tests executed)
- PERSEUS Carbon Atlas v1 with real-data interactive map
- Three paper-novel methodological contributions:
  - Multi-cycle FIA hindcast as calibration anchor
  - Four-tier calibration ladder (T0/T1/T1.5/T2)
  - Calibration degeneracy diagnostic (active-growth fraction)

Builds on console-patch/ DLL fixes that enable LANDIS-II v8 extension loading.
"
git push origin main
```

## Top-level README update (proposed)

Replace the current README's framing with this two-layer structure:

````markdown
# LANDIS-II HPC + PERSEUS Multi-State Calibration

This repository provides two layers of LANDIS-II infrastructure for OSC Cardinal
and similar HPC environments:

## Layer 1: Console patch (foundation, `console-patch/`)

.NET 8 / Foundation v1.1 patches for LANDIS Console extension loading.
Fixes the `Type.GetType` regression that prevents Biomass Harvest, Original Wind,
Climate BDA, and other extensions from loading in v8.

[Existing README content for the console patch.]

## Layer 2: PERSEUS calibration framework (`perseus/`)

Multi-state inverse parameterization of LANDIS-II Biomass Succession against the
USDA Forest Inventory and Analysis (FIA) multi-cycle hindcast. Calibrated
parameter sets for Maine, Georgia, and Washington.

Headline findings:
- Literature parameters systematically biased (over-prediction in GA + WA, slight
  under-prediction in ME)
- Four-tier calibration ladder closes the gap with state-specific optima
- Calibration changes 100-year biomass asymptotes by 7–67%
- Calibration degeneracy at very low θ — active-growth fraction diagnostic

See [perseus/README.md](perseus/README.md) for details.

## Companion paper

Weiskittel, A.R. et al. (2026). Multi-state inverse parameterization of LANDIS-II
Biomass Succession against the FIA inventory cycle. *Environmental Modelling
& Software*, submitted. [Manuscript draft](perseus/docs/methods_paper_FINAL_ASSEMBLY.md).
````

## Risk assessment

**Low risk merge:**
- All PERSEUS work goes into a NEW `perseus/` subdirectory
- Existing `console-patch/` and `pipeline/` directories are untouched
- Existing README content is preserved in Layer 1 section
- No file conflicts

**Possible concerns:**
- Repository will grow from ~50KB to ~10MB with figures + dashboard data — manageable for Git but worth noting
- The dashboard `.json` data files are large enough (1.5 MB total) that they could be moved to a separate "data release" if size becomes a concern. For now: keep in repo for self-contained reproduction.

## What goes to GitHub when

**Phase 1 (immediate, today):** Push merge to private branch first if you want a review pass before going to main. Or push directly to main if no concerns.

**Phase 2 (at manuscript submission):** Tag `v1.0` release. Optionally make Zenodo deposit at that point for DOI.

**Phase 3 (at publication):** Update README with paper DOI. Submit to LANDIS-II Foundation tool registry.

## What I can do right now on autopilot

I can execute the merge on Cardinal directly (assuming the SSH key is already set up for git push, which we saw is the case). Concretely:

1. SSH into Cardinal
2. Pull latest landis2HPC
3. Create perseus/ subtree and populate from scratch directory
4. Author perseus/README.md
5. Author updated top-level README.md
6. Commit + push

This is a ~30 min operation. Let me execute if you give the go-ahead, OR I can just stage the changes locally on Cardinal (without pushing) for your final review before push.
