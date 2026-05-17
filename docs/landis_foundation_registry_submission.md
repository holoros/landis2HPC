# LANDIS-II Foundation tool registry submission — draft

**Target:** https://landis-ii.org/extensions or equivalent community tool listing
**Submission contact:** info@landis-ii.org (or registry maintainer)

## Submission email draft

**To:** info@landis-ii.org
**Subject:** New community tool submission — PERSEUS multi-state calibration framework
**From:** Aaron Weiskittel <aaron.weiskittel@maine.edu>

---

Dear LANDIS-II Foundation team,

I'd like to submit a new community tool for inclusion in the LANDIS-II
extensions registry: PERSEUS, a multi-state calibration framework that
extends the v8 Apptainer pipeline with validated parameter sets for Maine,
Georgia, and Washington forests.

### Tool overview

**Name:** PERSEUS
**Repository:** https://github.com/holoros/landis2HPC
**License:** MIT
**Reproducibility:** Apptainer-based; runs on any SLURM HPC cluster
**Status:** v1.0 released 2026-05-17. Manuscript submission to *Environmental Modelling & Software* pending co-author review.

### What PERSEUS provides

1. **Validated v8 Apptainer disturbance extension parameter files** for:
   - Original Wind v4
   - Original Fire v5 (with the new `Species_CSV_File` directive required in v8)
   - Climate BDA v5 with three host-specific agent configurations: spruce budworm (Maine), southern pine beetle (Georgia), mountain pine beetle (Washington)
   - Hurricane v3 with NOAA HURDAT2-derived Atlantic storm climatology for Georgia

2. **State-specific best-fit calibration vectors** for LANDIS-II Biomass Succession
   anchored against the USDA Forest Inventory and Analysis (FIA) multi-cycle
   hindcast. Per-state θ vectors at four tiers:
   - Maine: Tier 2 per-species CMA-ES (26 parameters)
   - Georgia: Tier 1 uniform θ=0.30
   - Washington: Tier 1 uniform θ=0.30 (active-growth optimum)
   - Plus Washington Tier 1.5 per-ecoregion vector

3. **Six-test validation framework** for any state-scale LANDIS-II calibration:
   k-fold CV, time-out-of-sample, leave-one-ecoregion-out, cross-state, bootstrap
   CI, IC perturbation. Five of six tests pass in production for the three
   states.

4. **Calibration degeneracy diagnostic** (paper-novel methodological contribution).
   At very low θ, LANDIS-II produces near-zero growth and the likelihood minimum
   becomes a trivial fit. The active-growth fraction is the recommended diagnostic
   for production calibration selection. Should generalize to any LANDIS-II
   calibration; we encourage adoption.

5. **PERSEUS Carbon Atlas v1** — interactive web dashboard reading the
   calibrated results (browser-based, no server). Static HTML with embedded
   data bundles (~1.6 MB total). [Live preview](https://github.com/holoros/landis2HPC/tree/main/perseus/dashboard/atlas).

### Why this matters for the community

State-scale LANDIS-II projections are increasingly used for carbon policy and
climate adaptation decisions. Our cross-state results demonstrate that literature
parameters are systematically biased (over-prediction in GA + WA, slight
under-prediction in ME), and that calibration changes 100-year biomass asymptotes
by 7–67% depending on the state. Calibration is therefore not optional for
defensible state-scale carbon analyses; it's a prerequisite. PERSEUS provides
both the calibrated parameters and the framework for other states to do their
own calibration.

### Dependencies / prerequisites

PERSEUS depends on the LANDIS-II Foundation v1.1 Apptainer image with one
critical bind-mount: the patched `Landis.Console.dll` and `Landis.Utilities.dll`
that work around the .NET 8 `Type.GetType` regression. We've also released the
underlying .NET 8 patches as part of the same repository (foundation
`console-patch/` layer); a working patch is required for any extension loading
in v8 Apptainer.

### Citation guidance

```
Weiskittel, A.R., Lucash, M.S., Scheller, R.M., et al. (2026).
Multi-state inverse parameterization of LANDIS-II Biomass Succession
against the FIA inventory cycle: a calibration ladder for Maine, Georgia,
and Washington forests. Environmental Modelling & Software, submitted.
github.com/holoros/landis2HPC.
```

### Registry listing details (proposed for landis-ii.org/extensions)

| Field | Value |
|---|---|
| Tool name | PERSEUS |
| Full name | Multi-state LANDIS-II Calibration Framework |
| Category | Calibration / parameter estimation |
| Subcategory | Biomass Succession calibration |
| License | MIT |
| Documentation | https://github.com/holoros/landis2HPC/blob/main/perseus/README.md |
| Source code | https://github.com/holoros/landis2HPC |
| Citation | Weiskittel et al. (2026) Environmental Modelling & Software, submitted |
| Status | Stable v1.0 (manuscript in review) |
| Compatibility | LANDIS-II v8.0 with Apptainer + bind-mounted patched DLLs |
| Last updated | 2026-05-17 |
| Maintainer | Aaron Weiskittel (aaron.weiskittel@maine.edu) |

Happy to provide additional information or adjust any framing for the registry.

Best regards,
Aaron Weiskittel
Director, Center for Research on Sustainable Forests
University of Maine

---

## Notes on this submission

- **Timing:** Send after methods paper is in preprint / submission. The registry
  listing should point to a stable v1.0 release with a permanent DOI, not a
  work-in-progress.

- **Coordinate with Rob Scheller** before sending. Rob is the Foundation
  technical lead; a heads-up + endorsement makes the registry submission much
  smoother.

- **Foundation review timeline** is typically 2-4 weeks based on community
  norms. Plan for that lag.

- **Cross-promote** at the Foundation's annual community meeting (if scheduled);
  PERSEUS would be the first cross-state calibration framework in the registry
  based on a quick scan of existing listings (which are mostly extensions and
  some teaching materials).

## Alternate venues if Foundation registry isn't the right channel

1. **CRAN-equivalent for LANDIS extensions** — none exists; this submission
   might be the seed of one.

2. **Zenodo "LANDIS-II" community** — community on Zenodo. Submit the v1.0
   archive with appropriate community tags. Free, automatic DOI, indexed by
   Google Scholar.

3. **GitHub topics** — tag the repo with `landis-ii`, `forest-ecology`,
   `calibration`, `forest-carbon`, `usda-fia`. Improves discoverability via
   GitHub topic search.

4. **Forest ecology professional society newsletters** (SAF, ESA, IUFRO).
   Brief abstract + link to repository. Aaron likely knows the right contacts
   at each.

5. **State agency contacts** — Maine BPS, Georgia DNR, Washington DNR.
   Stakeholder networks are larger and more directly relevant for the
   scenario application use case.
