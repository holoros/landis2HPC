# PERSEUS: Multi-state LANDIS-II Calibration Framework

This directory contains the PERSEUS framework — a four-tier calibration ladder
for LANDIS-II Biomass Succession anchored against the USDA Forest Inventory and
Analysis (FIA) multi-cycle hindcast. PERSEUS extends the foundation
`console-patch/` layer (.NET 8 DLL fixes that enable LANDIS extension loading) with
scientific calibration infrastructure for state-scale forest carbon projection.

## Quick start

```bash
# Open the interactive PERSEUS Carbon Atlas
xdg-open dashboard/atlas/index.html  # or any browser; no server required

# Read the integrated methods paper
less ../docs/methods_paper_FINAL_ASSEMBLY.md

# Inspect best-fit calibration vectors
cat theta_best/ME_tier2_theta_best.csv
cat theta_best/WA_tier1_theta_best.csv
cat theta_best/GA_tier1_theta_best.csv
```

## Headline findings (2026-05-17)

| State | Best calibration | Optimum | LL/cell improvement | 100-yr asymptote change |
|---|---|---:|---:|---:|
| Maine | Tier 2 per-species CMA-ES (26 params) | — | +0.59 vs T0 | −7.5% |
| Georgia | Tier 1 uniform θ | 0.30 | +5.26 vs T0 | −35% |
| Washington | Tier 1 uniform θ (active-growth optimum) | 0.30 | +0.31 vs T0 | −67% |

Mean log-residuals approach zero under calibration (ME −0.043, GA +0.15, WA +0.011).
Variance compression (e.g., WA SD 0.555 → 0.417, 25% reduction).

## Repository layout

```
perseus/
├── README.md                    # this file
├── tools/                       # 22 calibration scripts (Cardinal-deployable)
│   ├── build_plot_scenario_*.sh         # Per-plot single-cell scenario builders
│   ├── apply_theta_*.py                 # θ multiplier appliers (uniform + per-species)
│   ├── cma_es_optimize_*.py             # Tier 2 CMA-ES drivers
│   ├── run_param_set_*_t2.sh            # Inner CMA-ES loop
│   ├── aggregate_WA_csv.py              # Long → wide aggregator
│   ├── likelihood_WA.py                 # Multi-cycle FIA hindcast log-likelihood
│   ├── cross_validate_tier2.py          # k-fold CV
│   ├── time_out_of_sample_validation.py # Train ≤2015, test >2015
│   ├── leave_one_ecoregion_out_cv.py    # Spatial-fold CV
│   ├── bootstrap_tier1_uncertainty.py   # 1000-iteration bootstrap CI
│   ├── tier15_per_ecoregion_refit.py    # Per-ecoregion θ from existing ladder
│   ├── cross_state_diagnostic.py        # Cross-state generalization
│   ├── submit_WA_*.sh                   # SLURM submission wrappers
│   └── harvest_WA.sh                    # Inode cleanup utility
│
├── disturbance_agents/          # 6 validated v8 Apptainer agent files
│   ├── Climate-BDA_Agent_SBW.txt        # Maine spruce budworm
│   ├── Climate-BDA_Agent_SPB.txt        # Georgia southern pine beetle
│   ├── Climate-BDA_Agent_MPB.txt        # Washington mountain pine beetle
│   ├── Climate-BDA_SetUp_*.txt          # Setup files for each
│   ├── Hurricane_GA.txt                 # Atlantic hurricane climatology for GA
│   └── EvennessWindReductions_GA.csv    # Hurricane wind reduction table
│
├── theta_best/                  # Per-state best-fit calibration vectors
│   ├── ME_tier2_theta_best.csv          # 26-parameter Maine Tier 2 (per-species)
│   ├── WA_tier1_theta_best.csv          # Washington Tier 1 (active-growth)
│   ├── GA_tier1_theta_best.csv          # Georgia Tier 1
│   └── WA_tier15_per_eco.csv            # Washington Tier 1.5 per-ecoregion
│
├── figures/                     # 16 publication-quality PNGs
│   ├── methods_figure1_three_state_map.png
│   ├── methods_figure2_pipeline_schematic.png
│   ├── methods_figure3_*.png            # Paired pred/obs scatter
│   ├── multistate_calibration_v7_FINAL.png  # Headline 4-panel figure
│   ├── me_tier2_species_heatmap.png     # Maine Tier 2 multipliers
│   ├── methods_figure8_100yr_trajectory.png  # 100-yr asymptote comparison
│   ├── wa_calibration_degeneracy.png    # The novel finding
│   └── (8 more historical iterations)
│
├── data/                        # Calibrated input + lookup data
│   ├── untreated_plots_*.csv            # Per-state FIA observed biomass + cycles
│   ├── plot_to_ecoregion_*.csv          # Plot → L3 ecoregion lookup
│
├── dashboard/                   # Interactive web tools
│   ├── atlas/                           # PERSEUS Carbon Atlas v1 (real data, 1.6 MB)
│   │   ├── index.html                   # Leaflet map + trajectory charts + CSV download
│   │   ├── WA.json (963 KB)
│   │   ├── GA.json (391 KB)
│   │   ├── ME.json (218 KB)
│   │   └── summary.json
│   ├── perseus_scenario_explorer.html   # v0 prototype (state/tier selectors)
│   └── perseus_carbon_atlas_v0.html     # v1 with map (synthesized data preview)
│
└── tests/                       # Reproducibility scripts
    └── reproduce_WA_T1_ladder.sh
```

## Documentation (in `../docs/`)

| File | Description |
|---|---|
| `methods_paper_FINAL_ASSEMBLY.md` | Integrated methods paper (~10,000 words) — recommended starting point |
| `methods_paper_section_*.md` | Individual section drafts |
| `methods_paper_section_3_REFRESH.md` | Latest Section 3 with full WA T1 ladder |
| `scenario_paper_*.md` | Companion scenario paper (3 sections) |
| `stress_validation_framework.md` | The 6-test framework design |
| `stress_validation_results.md` | Executed results (5 of 6 tests passing) |
| `calibration_degeneracy_finding.md` | Paper-novel methodological contribution |
| `T2_pairing_fix_resolution.md` | Full debug audit for Tier 2 CMA-ES |
| `disturbance_extensions.md` | v8 Apptainer extension validation memo |
| `GUI_scope_memo.md` | Decision framework for next-step LANDIS GUI |
| `deposit_plan.md` | GitHub + Zenodo deposit strategy |
| `references.bib` | 40-entry BibTeX bibliography |

## Stress + validation framework

PERSEUS includes a comprehensive validation framework addressing standard reviewer
overfitting concerns. Five of six tests are executed and passing:

| Test | Status | Headline result |
|---|---|---|
| K-fold CV (5-fold, stratified by ecoregion) | ✓ | LL/cell −0.624 ± 0.079 vs full-data −0.630 (no overfit) |
| Time-out-of-sample (2001–2015 train, 2016–2022 test) | ✓ | Calibration generalizes within window; identifies 2020–23 PNW drought signal |
| Leave-one-ecoregion-out CV | ✓ | Wet-side ecoregions inherit cleanly; dry-side benefits from Tier 1.5 |
| Cross-state generalization | ✓ | 5–9 LL/cell penalty when applying one state's θ to another → regional calibration essential |
| Bootstrap parameter CI (1,000 resamples) | ✓ | 100% of bootstraps identify same optimum (extremely stable) |
| IC perturbation (±25% biomass) | designed, deferred | Belongs in companion scenario paper |

## Paper-novel methodological contributions

1. **Multi-cycle FIA hindcast as calibration anchor** — uses the most spatially
   extensive empirical forest measurement dataset in North America.

2. **Four-tier calibration ladder** (T0/T1/T1.5/T2) with explicit stopping
   criteria based on parameter-count-to-data ratio.

3. **Calibration degeneracy diagnostic** — novel finding documented in
   `docs/calibration_degeneracy_finding.md`. At very low θ, LANDIS produces
   near-zero growth and the LL minimum is trivially achieved by model collapse.
   The active-growth fraction (>5% biomass change over 100 yr) is the recommended
   diagnostic for production calibration selection.

4. **Single-cell per-plot architecture** — enables tractable per-plot calibration
   without confounding from dispersal effects.

5. **Cross-state framework** — same calibration approach across structurally
   different forest biomes (spruce-fir, southern pine, Pacific NW conifers).

6. **Validated v8 Apptainer disturbance pipeline** — 6 extensions tested
   end-to-end with patched DLL bind mounts.

## Citation

```
Weiskittel, A.R., Lucash, M.S., Scheller, R.M., et al. (2026).
Multi-state inverse parameterization of LANDIS-II Biomass Succession
against the FIA inventory cycle: a calibration ladder for Maine, Georgia,
and Washington forests. Environmental Modelling & Software, submitted.
```

## Hardware requirements

- LANDIS-II v8 Apptainer image (foundation `console-patch/` layer required)
- SLURM-managed HPC cluster (validated on OSC Cardinal)
- ~150 core-hours for full state-wide calibration ladder
- ~12 hr for state Tier 2 CMA-ES convergence

## License

MIT. See [../LICENSE](../LICENSE).
