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
USDA Forest Inventory and Analysis (FIA) multi-cycle hindcast. Calibrated parameter
sets for Maine, Georgia, and Washington with full validation framework.

### Headline findings

- **Literature parameters systematically biased** (over-prediction in GA + WA, slight
  under-prediction in ME)
- **Four-tier calibration ladder** closes the gap with state-specific optima
- **Calibration changes 100-year biomass asymptotes by 7–67%** — directly relevant
  to state-scale forest carbon accounting
- **Calibration degeneracy diagnostic** — novel methodological contribution; the
  active-growth fraction is the recommended diagnostic for production calibration

### Quick start

```bash
# Browse the integrated methods paper
less docs/methods_paper_FINAL_ASSEMBLY.md

# Open the interactive PERSEUS Carbon Atlas
xdg-open perseus/dashboard/atlas/index.html

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
│   ├── tools/                           # 22 calibration scripts
│   ├── disturbance_agents/              # 6 validated agent files
│   ├── theta_best/                      # Per-state best calibrations
│   ├── figures/                         # 16 publication-quality PNGs
│   ├── data/                            # FIA plot lists + ecoregion lookups
│   ├── dashboard/                       # PERSEUS Carbon Atlas v1 (static HTML)
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
    ├── deposit_plan.md                  # GitHub + Zenodo strategy
    └── references.bib                   # 40-entry bibliography
```

## License

MIT. See [LICENSE](LICENSE).
