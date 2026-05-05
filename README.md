# LANDIS-II Console plug-in loader patch + Cardinal factorial pipeline

A drop-in fix for the harvest + wind plug-in loading failure in the official LANDIS-II Foundation v1.1 Apptainer image (`landis-ii_v8_allext_v1.0.sif`, md5 `7c255eedb76f248e4386f184e2d70dbe`), plus the SLURM factorial pipeline that uses it on the OSC Cardinal HPC cluster.

## What problem does this solve

In the Foundation v1.1 image the LANDIS Console fails to load `Biomass Harvest` and `Original Wind` extensions, throwing

```
Error while loading the plug-in: <Name>
  Cannot get the data type that implements the plug-in:
    Data type:  Landis.Extension.BiomassHarvest.PlugIn,Landis.Extension.BiomassHarvest-v6
    Error:      No data type with that name is installed.
```

Root cause is a combination of two .NET 8 changes:

1. .NET 8 ignores the `<probing privatePath="8.0;extensions"/>` entry in `Landis.Console.dll.config`, so extension assemblies are never on the runtime probe path.
2. `System.Type.GetType(qualifiedName)` does not see types in assemblies loaded by custom AssemblyLoadContexts (dotnet/runtime issue [#103222](https://github.com/dotnet/runtime/issues/103222)).

The patch replaces `Type.GetType(qualifiedName)` with explicit assembly resolution. Two complementary fixes ship together:

| File | What it does |
|---|---|
| `console-patch/src/Tool-Console/App.cs` | Installs an `AssemblyLoadContext.Default.Resolving` handler that probes `./extensions`, `../extensions`, `./8.0`, `../8.0` for missing assemblies and calls `LoadFromAssemblyPath`. |
| `console-patch/src/Library-Utilities/Loader.cs` | `Loader.Load<T>(IInfo info)` walks `AppDomain.CurrentDomain.GetAssemblies()`, then `Assembly.Load(AssemblyName)`, then probes the same directories with `Assembly.LoadFrom`, and finally calls `assembly.GetType(typeName)` on the resolved Assembly instance. |

Either fix alone resolves the bug; both ship for defence in depth. Built against dotnet SDK 8.0.420.

## Repo layout

```
console-patch/
  dist/                Pre-built DLLs with SHA256 + MD5 checksums
  patches/             Unified diffs against upstream Foundation source
  src/                 Patched source files (Tool-Console/App.cs, Library-Utilities/Loader.cs)
pipeline/
  scenario_factorial_subtile.sh   Tile based factorial submitter for OSC Cardinal
  aggregate_subtile_factorial.R   Year-50 biomass aggregator and heatmap generator
docs/
  email_landis_foundation.md      Diagnostic write-up sent to the LANDIS-II Foundation
build.sh                          One-shot reproducer (clones upstream, applies patches, builds, verifies md5)
```

## Quick start: bind-mount the patched DLLs

The pre-built DLLs in `console-patch/dist/` are ready to go. Drop them somewhere on shared storage, then bind-mount over the originals at run time. No rebuild of the Apptainer image needed.

```bash
SIF=/path/to/landis-ii_v8_allext_v1.0.sif
PATCH=/path/to/console-patch/dist
SCENARIO=/path/to/your/scenario_directory

apptainer exec \
  --bind $PATCH/Landis.Console.dll:/bin/LANDIS_Linux/build/Release/Landis.Console.dll \
  --bind $PATCH/Landis.Utilities.dll:/bin/LANDIS_Linux/build/Release/Landis.Utilities.dll \
  --bind $SCENARIO:/work --pwd /work \
  $SIF dotnet /bin/LANDIS_Linux/build/Release/Landis.Console.dll scenario.txt
```

Verified end-to-end on Cardinal 2026-05-05: `Biomass Harvest` and `Original Wind` both load and run, harvest event logs and severity rasters land alongside per-species biomass output.

## Verifying the binaries

Checksums of the shipped DLLs:

```
a42d209f4faf2f2562cd5f63e32b8f8a  Landis.Console.dll      (10752 bytes)
c0be4b9f064b817b6352c61feb42be24  Landis.Utilities.dll    (46592 bytes)
```

See `console-patch/dist/SHA256SUMS` for the SHA-256 versions.

## Building from source

```bash
./build.sh
```

The script clones `LANDIS-II-Foundation/Core-Model-v8-LINUX` (Tool-Console) and `LANDIS-II-Foundation/Library-Utilities`, applies the patches, builds against dotnet SDK 8.0, and validates the resulting DLLs against the shipped checksums. Requires git, dotnet 8.0+, curl.

## Cardinal factorial pipeline

`pipeline/scenario_factorial_subtile.sh` runs a per-tile factorial of (state × tile × owner × climate × harvest) on OSC Cardinal. Defaults assume the LANDIS-II workspace at `/fs/scratch/PUOM0008/crsfaaron/landis2/`. Notable flags:

| Flag | Default | Meaning |
|---|---|---|
| `--tiles N` | 0 (all) | Limit to first N tiles for smoke tests |
| `--owners ind,nipf,public` | all 3 | Subset of management area rasters |
| `--climate baseline,ssp245,ssp585` | all 3 | Climate scenarios |
| `--harvest none,baseline,increased,perseus` | all 4 | Harvest prescriptions |
| `--duration 50` | 50 | Simulation length in years |
| `--use-patch yes\|no` | yes | Bind-mount the patched DLLs into the apptainer call |
| `--patch-dir <path>` | `$SCRATCH/landis2/patches` | Where the patched DLLs live |
| `--wind yes\|no` | yes | Include Original Wind in scenario.txt |
| `--skip-existing yes\|no` | no | Skip a scenario when its year-DURATION biomass tif is already present |
| `--queue-limit N` | 900 | Sleep when squeue size reaches this many jobs |
| `--rebuild-cache yes\|no` | no | Force rebuild of the per-tile MA + stands rasters |

The script auto-handles the LANDIS-II v8 file format quirks documented in `docs/landis_v8_format_notes.md` (or in the project workspace `landis2/docs/`).

## Status: 2026-05-05

End to end validated on OSC Cardinal. 5-tile sweep PASSED 20 of 20 with year-50 biomass + harvest output. Full 9540-scenario factorial submission in flight at the time of this commit.

## Licence

Apache 2.0, matching upstream `LANDIS-II-Foundation/Core-Model-v8-LINUX` and `LANDIS-II-Foundation/Library-Utilities`. See `LICENSE`.

## Upstreaming

The patch is intended to be sent upstream. The diagnostic write-up in `docs/email_landis_foundation.md` is the parallel email to Robert Scheller at NCSU describing the bug and fix. Issue / PR pointers will be added here once filed.

## Acknowledgements

LANDIS-II Foundation for the v8 platform and source. Center for Research on Sustainable Forests at the University of Maine for the multi-state framework this work was developed in.
