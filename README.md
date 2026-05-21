# LANDIS-II HPC + PERSEUS Multi-State Calibration

This repository provides two layers of LANDIS-II infrastructure for OSC Cardinal
and similar HPC environments:

| Layer | Directory | Purpose |
|---|---|---|
| **1. Console patch** (foundation) | `console-patch/` | .NET 8 fixes that enable LANDIS extension loading |
| **2. PERSEUS framework** (calibration + projections) | `perseus/` | Multi-state inverse parameterization against FIA observations |
| **3. Original ME pipeline** (legacy) | `pipeline/` | Initial Maine-only factorial scaffolding (pre-PERSEUS) |

---

## Layer 1: LANDIS-II Console patch

### What problem does this solve

In the Foundation v1.1 Apptainer image the LANDIS Console fails to load `Biomass Harvest` and
`Original Wind` extensions, throwing

```
Error while loading the plug-in: <Name>
  Cannot get the data type that implements the plug-in:
    Data type:  Landis.Extension.BiomassHarvest.PlugIn,Landis.Extension.BiomassHarvest-v6
    Error:      No data type with that name is installed.
```

Root cause is two .NET 8 changes:

1. .NET 8 ignores `<probing privatePath="8.0;extensions"/>` in `Landis.Console.dll.config`,
   so extension assemblies are never on the runtime probe path.
2. `System.Type.GetType(qualifiedName)` does not see types in assemblies loaded by custom
   `AssemblyLoadContext` (dotnet/runtime [#103222](https://github.com/dotnet/runtime/issues/103222)).

The patch replaces `Type.GetType(qualifiedName)` with explicit assembly resolution.
Two complementary fixes ship together; either alone resolves the bug, both ship for
defence in depth.

| File | What it does |
|---|---|
| `console-patch/src/Tool-Console/App.cs` | Installs `AssemblyLoadContext.Default.Resolving` handler probing `./extensions`, `../extensions`, `./8.0`, `../8.0` |
| `console-patch/src/Library-Utilities/Loader.cs` | `Loader.Load<T>(IInfo info)` walks loaded assemblies, then probes directories with `Assembly.LoadFrom` |

Built against dotnet SDK 8.0.420.

### Console patch layout

```
console-patch/
  dist/                    Pre-built DLLs with SHA256 + MD5 checksums
  patches/                 Unified diffs against upstream Foundation source
  src/                     Patched source files (Tool-Console/App.cs, Library-Utilities/Loader.cs)
```

---

## Layer 2: PERSEUS Multi-state calibration framework

Multi-state inverse parameterization of LANDIS-II Biomass Succession against the
USDA Forest Inventory and Analysis (FIA) multi-cycle hindcast. Production calibrations
for Maine, Georgia, Washington, and Minnesota, with Wisconsin and Michigan finishing,
plus a full validation framework, a browser-based Forest Intelligence GUI, and a
scenario-submission backend.

### Headline findings

- **A regional sign-flip in literature bias** — calibration scales productivity up in
  Maine (85% of species above 1.0, median x1.31) but down hard in Washington and Georgia
  (theta optimum 0.20 to 0.30). The literature parameters are not uniformly off; they are
  regionally biased. See `docs/crossstate_literature_bias_memo.md`.
- **Four-tier calibration ladder** (Tier 0 literature, Tier 1 uniform, Tier 1.5 per
  ecoregion, Tier 2 per species) closes the gap with state-specific optima.
- **Calibration changes 100-year biomass asymptotes by 7 to 67%** — for Washington the
  median year-100 biomass falls from 562 to 185 Mg/ha, a level correction rather than a
  growth shutdown (53% of plots still accrue biomass). See `docs/WA_calibration_effect_memo.md`.
- **Tier 2 recovers ecologically coherent per-species structure** — Maine balsam fir gets
  ANPP x2.26 with a biomass ceiling x0.54, the fast-growing short-lived signature, from
  data alone. See `docs/me_tier2_multiplier_structure_memo.md`.
- **Calibration degeneracy diagnostics** — a three-mode pathology (active-growth,
  empty-aggregator, sample-size) plus an n-aware production-vector selector that defends
  against settling-check timeouts (`perseus/tools/harvest_t2_chains.py`).

### Quick start

```bash
# Browse the integrated methods paper
less docs/methods_paper_FINAL_ASSEMBLY.md

# Open the Forest Intelligence GUI (scenario builder, growth curves, calibration)
xdg-open perseus/dashboard/perseus_forest_intelligence_v1.html

# Inspect calibrated parameter vectors
cat perseus/theta_best/ME_tier2_theta_best.csv
```

See [`perseus/README.md`](perseus/README.md) for full PERSEUS layer documentation.

### Companion paper

Weiskittel, A.R., Lucash, M.S., Scheller, R.M., et al. (2026). Multi-state inverse
parameterization of LANDIS-II Biomass Succession against the FIA inventory cycle:
a calibration ladder for Maine, Georgia, and Washington forests.
*Environmental Modelling & Software*, submitted.

---

## Repo layout

```
landis2HPC/
├── README.md                            # this file
├── LICENSE                              # MIT
├── CHANGELOG.md                         # version history
├── build.sh                             # console patch build helper
├── .gitignore
│
├── console-patch/                       # Layer 1: .NET 8 DLL fixes
│   ├── dist/                            # Pre-built patched DLLs
│   ├── patches/                         # Unified diffs vs upstream Foundation
│   └── src/                             # Patched source files
│
├── pipeline/                            # Legacy ME-only factorial scaffolding
│   ├── scenario_factorial_subtile.sh
│   └── aggregate_subtile_factorial.R
│
├── perseus/                             # Layer 2: PERSEUS framework
│   ├── README.md                        # PERSEUS layer details
│   ├── tools/                           # calibration + harvest + atlas scripts
│   ├── disturbance_agents/              # 6 validated agent files
│   ├── theta_best/                      # Per-state best calibrations
│   ├── figures/                         # publication-quality PNGs
│   ├── data/                            # FIA plot lists + ecoregion lookups
│   ├── dashboard/                       # Forest Intelligence GUI + Carbon Atlas (static HTML)
│   ├── backend/                         # FastAPI scenario-to-Cardinal service (phase 3)
│   └── tests/                           # Reproducibility scripts
│
└── docs/                                # All documentation
    ├── email_landis_foundation.md       # Original .NET 8 patch context (Layer 1)
    ├── methods_paper_FINAL_ASSEMBLY.md  # Integrated methods paper
    ├── methods_paper_section_*.md       # Individual section drafts
    ├── scenario_paper_*.md              # Companion paper (3 sections)
    ├── calibration_degeneracy_finding.md  # Novel methodological contribution
    ├── stress_validation_framework.md   # 6-test framework design
    ├── stress_validation_results.md     # Executed results (5 of 6 passing)
    ├── T2_pairing_fix_resolution.md     # T2 CMA-ES debug audit
    ├── disturbance_extensions.md        # v8 Apptainer extension validation
    ├── GUI_scope_memo.md                # Next-step product decisions
    ├── GUI_v1_architecture.md           # Forest Intelligence GUI architecture + roadmap
    ├── multistate_readiness_matrix.md   # Per-state calibration readiness
    ├── WA_calibration_effect_memo.md    # WA year-100 calibration effect (real trajectories)
    ├── crossstate_literature_bias_memo.md  # Regional sign-flip synthesis
    ├── me_tier2_multiplier_structure_memo.md  # ME per-species correction structure
    ├── SESSION_HANDOFF_2026-05-21.md    # Latest session handoff
    ├── deposit_plan.md                  # GitHub + Zenodo strategy
    └── references.bib                   # 40-entry bibliography
```

## License

MIT. See [LICENSE](LICENSE).
