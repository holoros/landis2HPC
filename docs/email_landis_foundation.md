# Email to LANDIS-II Foundation

**To**: [Foundation contact: typically Robert Scheller, Melissa Lucash, or the landis-ii.org maintainers]
**From**: Aaron Weiskittel, University of Maine
**Subject**: LANDIS-II v8 Apptainer image: Biomass Harvest and Original Wind plugins fail to load

---

Hi [name],

I'm running LANDIS-II 8.0 on OSC Cardinal HPC inside an Apptainer container (image: `landis-ii_v8_allext_v1.0.sif`), and I've hit a reproducible plugin loading issue with both **Biomass Harvest 6.0** and **Original Wind 4.0**. Biomass Succession 7.0 and Output Biomass 4.0 work fine in the same image.

## The error

When a scenario.txt references either extension, LANDIS Console exits with:

```
Loading Biomass Harvest extension ...
Error while loading the plug-in:
  Cannot get the data type that implements the plug-in:
    Data type:  Landis.Extension.BiomassHarvest.PlugIn,Landis.Extension.BiomassHarvest-v6
    Error:      No data type with that name is installed.
```

Same error pattern for Original Wind: `Landis.Extension.OriginalWind.PlugIn,Landis.Extension.OriginalWind-v4`.

## What I've verified

- I'm running the official Foundation Apptainer image — verified identical MD5 with the v1.1 release at https://github.com/LANDIS-II-Foundation/Tool-Docker-Apptainer/releases/download/1.1/landis-ii_v8_ubuntu_allExtensions_v1.0.sif (md5: 7c255eedb76f248e4386f184e2d70dbe). So this is reproducible by anyone using your published image.
- Both extensions are listed in `/bin/LANDIS_Linux/build/extensions/extensions.xml` with correct Assembly + Class names
- The DLL files exist at `/bin/LANDIS_Linux/build/extensions/Landis.Extension.BiomassHarvest-v6.dll` and `.OriginalWind-v4.dll`
- Their `.deps.json` files reference the standard library dependencies (`Landis.Library.HarvestManagement-v4`, `Landis.Library.SiteHarvest-v2`, `Landis.Library.UniversalCohorts-v1`, etc.)
- All those dependent library DLLs exist in `/bin/LANDIS_Linux/build/Release/`
- `strings` confirms the class name `Landis.Extension.BiomassHarvest.PlugIn` is present in the DLL
- Biomass Succession 7.0 and Output Biomass 4.0 load successfully in the same image — so the plugin loader works for some extensions

## What I've tried

1. Bind-mounting the extension DLLs into `/bin/LANDIS_Linux/build/Release/` (where Biomass Succession lives) — same error
2. Replacing the entire `/build/Release/` directory with a copy that includes the harvest+wind DLLs and their `.deps.json` files — same error
3. Confirmed the dotnet runtime and CoreCLR setup work for the other extensions

The fact that Biomass Succession and Output Biomass load successfully in the same image suggests this is specific to how the harvest and wind extensions register their plugin classes, not a general assembly probing issue.

## Possibly related

This pattern matches https://github.com/dotnet/runtime/issues/103222 ("Type.GetType(string) can't find type if assembly loaded using AssemblyLoadContext"). If the LANDIS Console plugin loader uses `Type.GetType(qualifiedName)` after loading extension assemblies via `AssemblyLoadContext.LoadFromAssemblyPath()`, .NET 8 will return null even when the type exists in the loaded assembly. The standard workaround is `assembly.GetType(typeName)` against the loaded Assembly instance, or using `EnterContextualReflection`.

This would explain why some extensions (perhaps loaded via a different code path) work while others fail with the same setup.

## What I'd love to know

1. Is there a known fix or workaround for the v1.1 Apptainer image regarding Biomass Harvest and Original Wind plugin registration?
2. Is there a refreshed image in development? The myget.org NuGet feed has been returning 404 for a while which has blocked our attempts at a clean local rebuild.
3. Is there an environment variable or runtime config I should set to make the CoreCLR find these specific extensions?

If helpful, I can provide:
- The full LANDIS Console output before the error
- The extensions.xml + deps.json contents
- A minimal failing scenario directory you could `apptainer exec` in your own setup

## Context

I'm scaling LANDIS-II to a 4-state framework (Maine, Minnesota, Georgia, Washington) using TreeMAP 2022 + FIA + EPA Level III ecoregions + climate downscaling. The Maine baseline simulations are running successfully via the subtile array workaround we developed for an unrelated v1.1 image issue (UniversalCohorts assembly version skew during CohortMortality, which we documented in our March handoff). Adding harvest and wind to the climate × landowner factorial is the central remaining piece of the methods paper draft.

Happy to be a test case if you have an updated image in development.

Thanks for your time and for keeping LANDIS-II maintained — it's the workhorse of our group's climate adaptation work.

Best,
Aaron Weiskittel
Director, Center for Research on Sustainable Forests
University of Maine
aaron.weiskittel@maine.edu
