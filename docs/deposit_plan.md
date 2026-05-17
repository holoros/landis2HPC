# PERSEUS GitHub + Zenodo deposit plan

**Repository:** `github.com/CRSF-UMaine/perseus-multistate-calibration`
**License:** MIT
**Zenodo DOI:** to be obtained at submission time

## Repository structure

```
perseus-multistate-calibration/
├── README.md                          # Project overview, citation, quick-start
├── LICENSE                            # MIT
├── CITATION.cff                       # Standard citation format
├── docs/
│   ├── methods_paper.md               # Full integrated methods paper
│   ├── calibration_degeneracy.md      # Critical finding memo
│   ├── stress_validation.md           # Framework + results
│   ├── disturbance_extensions.md      # v8 Apptainer probe documentation
│   └── handoffs/                      # Session processing logs (historical record)
│
├── tools/                             # All Cardinal-deployed code
│   ├── build_plot_scenario_WA.sh
│   ├── build_plot_scenario_factorial.sh
│   ├── apply_theta_WA_perspecies.py
│   ├── apply_theta_GA_perspecies.py
│   ├── apply_theta_uniform_WA.py
│   ├── apply_theta_uniform_GA.py
│   ├── cma_es_optimize_WA.py
│   ├── cma_es_optimize_GA.py
│   ├── run_param_set_WA_t2.sh        # The patched version
│   ├── run_param_set_GA_t2.sh
│   ├── aggregate_WA_csv.py
│   ├── likelihood_WA.py
│   ├── tier15_per_ecoregion_refit.py
│   ├── cross_validate_tier2.py
│   ├── time_out_of_sample_validation.py
│   ├── leave_one_ecoregion_out_cv.py
│   ├── bootstrap_tier1_uncertainty.py
│   └── cross_state_diagnostic.py
│
├── disturbance_agents/
│   ├── Climate-BDA_Agent_SBW.txt     # Spruce budworm (Maine)
│   ├── Climate-BDA_Agent_SPB.txt     # Southern pine beetle (Georgia)
│   ├── Climate-BDA_Agent_MPB.txt     # Mountain pine beetle (Washington)
│   ├── Climate-BDA_SetUp_*.txt       # Setup files
│   ├── Hurricane_GA.txt              # Atlantic hurricane (Georgia)
│   └── EvennessWindReductions_GA.csv
│
├── theta_best/                        # Per-state best-fit calibration vectors
│   ├── ME_tier2_theta_best.csv       # Maine 26-param Tier 2 (per-species)
│   ├── GA_tier1_theta_best.csv       # Georgia Tier 1 θ=0.30
│   ├── WA_tier1_theta_best.csv       # Washington Tier 1 θ=0.30
│   ├── WA_tier15_per_eco_theta.csv   # Washington Tier 1.5 per-ecoregion
│   └── (placeholder) WA_GA_tier2_theta_best.csv  # When CMA-ES converges
│
├── figures/                          # All Methods paper figures
│   ├── methods_figure1_three_state_map.png
│   ├── methods_figure2_pipeline_schematic.png
│   ├── methods_figure3_three_state_scatter.png
│   ├── multistate_calibration_v7_FINAL.png
│   ├── me_tier2_species_heatmap.png
│   ├── methods_figure7_residual_diagnostic.png
│   ├── methods_figure8_100yr_trajectory.png
│   ├── wa_calibration_degeneracy_2026-05-16.png
│   └── state_aggregate_mmt_trajectory_2026-05-16.png
│
├── data/                             # Calibrated results datasets
│   ├── untreated_plots_*.csv         # Per-state FIA plot lists
│   ├── plot_to_ecoregion_*.csv       # Per-state ecoregion lookup
│   ├── wa_t1_*.csv                   # WA per-θ trajectory data
│   ├── wa_t0_residuals_full.csv      # WA Tier 0 residuals
│   ├── wa_t1_30_resid.csv            # WA Tier 1 best residuals
│   ├── ga_t1_x03_per_plot.csv        # GA Tier 1 best per-plot data
│   └── state_calibration_ladders.csv # Cross-state ladder summary
│
├── dashboard/
│   ├── perseus_scenario_explorer.html  # GUI prototype (this session)
│   └── README.md                       # How to run / extend
│
└── tests/                            # Reproducibility tests
    ├── reproduce_WA_T1_ladder.sh
    ├── reproduce_ME_T2.sh
    └── reproduce_validation_tests.sh
```

## README content (skeleton)

````markdown
# PERSEUS: Multi-state LANDIS-II Calibration Framework

[![DOI](https://zenodo.org/badge/DOI/TBD.svg)](https://doi.org/TBD)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A reproducible calibration framework for LANDIS-II Biomass Succession against
the USDA Forest Inventory and Analysis (FIA) multi-cycle hindcast, demonstrated
across Maine, Georgia, and Washington forests.

## Quick start

```bash
git clone https://github.com/CRSF-UMaine/perseus-multistate-calibration
cd perseus-multistate-calibration
# Read methods paper
cat docs/methods_paper.md
# Or open the interactive scenario explorer
xdg-open dashboard/perseus_scenario_explorer.html
```

## Headline findings

- **Literature LANDIS-II parameters are systematically biased** in direction-specific
  ways: Maine slight under-prediction (mean log-residual −0.064), Georgia strong
  over-prediction (+0.65), Washington moderate over-prediction (+0.26).
- **Four-tier calibration ladder** (uniform θ → per-ecoregion → per-species CMA-ES)
  closes the gap with state-specific optima at qualitatively different θ values.
- **Calibration changes 100-year biomass asymptotes by 7–67%** — meaningful for
  state-scale carbon accounting.
- **Calibration degeneracy diagnostic**: at very low θ, LANDIS produces zero growth
  and the LL minimum is trivially achieved by model collapse, not real fit.
  Active-growth fraction (>5% biomass change over 100 yr) is the recommended
  diagnostic for production calibration selection.

## Citation

> Weiskittel, A.R., Lucash, M.S., Scheller, R.M., et al. (2026).
> Multi-state inverse parameterization of LANDIS-II Biomass Succession against
> the FIA inventory cycle: a calibration ladder for Maine, Georgia, and Washington
> forests. *Environmental Modelling & Software*, accepted.

## Reproducibility

All calibration runs use [LANDIS-II 8.0](https://landis-ii.org) packaged in a
v8 Apptainer image with bind-mounted patched DLLs to work around the .NET 8
Type.GetType regression. Per-plot scenarios use a single-cell 1×1 30m
landscape architecture. Compute infrastructure: OSC Cardinal (single-CPU SLURM
arrays + chained chunk wrappers).

## Disturbance extensions

Five validated disturbance extensions for the v8 Apptainer image are documented
in `docs/disturbance_extensions.md`, with per-state parameter files in
`disturbance_agents/`:

- Original Wind v4
- Original Fire v5 (note: requires `Species_CSV_File` directive in v8)
- Climate BDA v5: Spruce budworm (ME), Southern pine beetle (GA),
  Mountain pine beetle (WA)
- Hurricane v3 (GA): Atlantic storm climatology + per-direction exposure maps
````

## Commit plan (post-submission)

**Phase 1 (when ready to share with co-authors):** Private repository, methods paper draft + figures + code + data. Co-authors get pull access.

**Phase 2 (at submission):** Public repository. Add CITATION.cff, license, README. Zenodo deposit creates DOI.

**Phase 3 (post-publication):** Update README with publication DOI. Tag a v1.0 release. Submit to LANDIS-II Foundation tool registry. Add to Aaron's faculty page + CRSF research outputs.

## Pre-publication checklist

- [ ] All code documented (docstrings + comments)
- [ ] README has working quick-start
- [ ] Figures regenerable from data + scripts
- [ ] Per-state θ_best vectors validated with provided test script
- [ ] License headers in code files
- [ ] CITATION.cff with author ORCIDs
- [ ] Zenodo deposit metadata
- [ ] LICENSE file (MIT) at root
- [ ] CHANGELOG.md (v1.0 = manuscript submission)
- [ ] Test that someone with a fresh OSC account + 4 hr compute can reproduce ME Tier 0 baseline

## Files to transfer from Cardinal scratch to GitHub

| Source on Cardinal | GitHub path | Notes |
|---|---|---|
| `/fs/scratch/.../landis2/tools/*.{sh,py}` | `tools/` | All calibration code |
| `/fs/scratch/.../landis2/tools/Climate-BDA_*.txt` | `disturbance_agents/` | Validated agents |
| `/fs/scratch/.../landis2/tools/untreated_plots_*.csv` | `data/` | FIA plot lists |
| `/fs/scratch/.../landis2/tools/plot_to_ecoregion_*.csv` | `data/` | Lookup tables |
| `~/wa_t1_*.csv` | `data/calibration_results/` | Per-θ trajectory data |
| ME bayesian Tier 2 results | `theta_best/ME_tier2_theta_best.csv` | Maine 26-param vector |
| Local figures from `outputs/` | `figures/` | All Methods paper figures |
| Local paper drafts from `outputs/` | `docs/` | Markdown manuscript |
| `outputs/perseus_scenario_explorer.html` | `dashboard/` | GUI prototype |

## Practical commit script (proposed for next session)

```bash
# On a fresh laptop with git installed
git clone --bare https://github.com/CRSF-UMaine/perseus-multistate-calibration.git
cd perseus-multistate-calibration
# Stage files from Cardinal (via rsync over ssh)
mkdir -p tools disturbance_agents data theta_best figures docs dashboard tests
rsync -av cardinal:/fs/scratch/PUOM0008/crsfaaron/landis2/tools/*.{sh,py} tools/
rsync -av cardinal:/fs/scratch/PUOM0008/crsfaaron/landis2/tools/Climate-BDA*.txt disturbance_agents/
rsync -av cardinal:/fs/scratch/PUOM0008/crsfaaron/landis2/tools/Hurricane_*.txt disturbance_agents/
rsync -av cardinal:/fs/scratch/PUOM0008/crsfaaron/landis2/tools/EvennessWindReductions_*.csv disturbance_agents/
# Local paper drafts
cp ~/Documents/Claude/CRSF-Cowork/outputs/*.md docs/
cp ~/Documents/Claude/CRSF-Cowork/outputs/*.png figures/
cp ~/Documents/Claude/CRSF-Cowork/outputs/perseus_scenario_explorer.html dashboard/
# Initial commit
git add .
git commit -m "Initial commit: PERSEUS multi-state calibration framework v1.0"
git push origin main
```

## Zenodo deposit metadata

```yaml
# Pre-fill at deposit creation time
title: "PERSEUS: Multi-state LANDIS-II calibration framework"
creators:
  - name: "Weiskittel, Aaron R."
    affiliation: "Center for Research on Sustainable Forests, University of Maine"
    orcid: "0000-0001-7976-9296"  # actual; verify before deposit
  - name: "Lucash, Melissa S."
    affiliation: "University of Oregon"
  - name: "Scheller, Robert M."
    affiliation: "NC State University"
keywords:
  - "LANDIS-II"
  - "forest landscape modeling"
  - "FIA"
  - "Forest Inventory Analysis"
  - "calibration"
  - "Maine"
  - "Georgia"
  - "Washington"
  - "biomass succession"
related_identifiers:
  - identifier: "10.xxxx/xxxxx"  # paper DOI when accepted
    relation: "isSupplementTo"
    resource_type: "publication-article"
upload_type: "software"
description: |
  Reproducible calibration framework for LANDIS-II Biomass Succession against
  the USDA Forest Inventory and Analysis (FIA) multi-cycle hindcast, with
  state-specific parameter files for Maine, Georgia, and Washington. Includes:
  per-plot scenario builders, four-tier calibration ladder (uniform θ →
  per-ecoregion → per-species CMA-ES), validation framework (k-fold CV,
  time-out-of-sample, leave-one-ecoregion-out, cross-state, bootstrap),
  validated disturbance extension parameter files (SBW, SPB, MPB, Hurricane v3),
  and interactive scenario explorer.
```

## Discoverability strategy

1. **LANDIS-II Foundation registry**: submit framework to https://landis-ii.org/extensions
   (would be the first cross-state calibration framework registered)

2. **Faculty + center webpages**:
   - Aaron's UMaine SFR faculty page
   - CRSF research outputs page (crsf.umaine.edu)
   - Add to grant final reports for the funding sources

3. **Social + community channels**:
   - Tweet thread with key figures (using Aaron's existing forestry network)
   - Post to ESA + SAF community forums
   - LinkedIn announcement post-submission

4. **Conference**: present at SAF national or ESA annual meeting (2027) — package
   the calibration framework + scenario explorer as a "live tools demo" talk

## Estimated effort to execute

| Phase | Effort |
|---|---|
| Repository structure + README | 2-3 hours |
| File transfer + initial commit | 1-2 hours |
| CITATION.cff + license setup | 30 min |
| Zenodo deposit (paper acceptance) | 1 hour |
| Discoverability outreach | 2-4 hours (incremental) |
| **Total** | **~8-12 hours** of human time |

Most of this is mechanical; the lone strategic decision is whether to release
**before** the paper publishes (allows reviewers to inspect code; risk of
scooping is essentially zero given the niche) or **after** (cleaner publication
timeline). Recommend: **public release at submission time**, anchored to a
pre-print on bioRxiv or arXiv. This gives reviewers access while protecting
peer-review prerogative.
