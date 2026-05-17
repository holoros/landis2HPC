# bioRxiv preprint announcement plan

## Strategic rationale

Posting to bioRxiv before journal submission accomplishes three things:

1. **Establishes scientific priority** for the calibration degeneracy finding and the multi-state framework. Journal review timelines run 3–6 months; preprint priority is established immediately.

2. **Allows reviewers and editors to inspect the code repository** without needing a special arrangement. Standard practice in computational ecology over the last 5 years.

3. **Discoverability + community engagement** before publication. The interactive Carbon Atlas dashboard is a natural conversation-starter for stakeholder networks.

The risk side is real but small: bioRxiv journals sometimes treat preprints with caution. *Environmental Modelling & Software* explicitly allows preprints — see https://www.elsevier.com/journals/environmental-modelling-and-software/policies-and-guidelines (search "preprint").

## Recommended submission sequence

1. **Tag v1.0 release on GitHub** ([github.com/holoros/landis2HPC](https://github.com/holoros/landis2HPC)) at the same time as the bioRxiv deposit. Creates a permanent DOI via Zenodo (automatic if linked).

2. **Submit PDF + supplementary materials to bioRxiv** at https://www.biorxiv.org. Use the integrated assembly markdown as the source; convert to PDF via Pandoc + a journal-style template.

3. **Submit to Environmental Modelling & Software within 24 hours** of bioRxiv posting (avoid arXiv/bioRxiv-to-journal lag concerns).

4. **Tweet/LinkedIn announcement** at posting time. CRSF + UMaine SFR amplification.

## bioRxiv field selection

- **Category:** Ecology
- **Subject area:** Forest Ecology
- **Article type:** Methods paper

## Submission content checklist

### Required at bioRxiv submission

- [ ] Abstract (~250 words) — distill the methods paper's executive summary
- [ ] Author list with ORCIDs + affiliations
- [ ] Corresponding author + email
- [ ] Funding statement (CRSF, USDA NIFA grant if applicable)
- [ ] Conflict of interest declaration
- [ ] PDF of complete manuscript
- [ ] Supplementary figures + tables
- [ ] Data availability statement pointing to GitHub + Zenodo
- [ ] Code availability statement (same)
- [ ] License declaration (MIT for code; CC-BY for manuscript)

### Abstract draft

> Forest landscape simulation models, including the widely used LANDIS-II Biomass
> Succession extension, are routinely applied to project state-scale forest
> carbon stocks under climate change, harvest, and disturbance scenarios. Their
> calibration parameters are typically transferred from regional studies or
> literature with limited validation against landscape-scale empirical data.
> We propose a four-tier calibration ladder anchored against the USDA Forest
> Inventory and Analysis (FIA) multi-cycle hindcast and apply it across three
> contrasting forested states: Maine, Georgia, and Washington. Literature
> parameters produce systematic biases that differ in direction by state
> (Maine slight under-prediction, mean log-residual −0.064; Georgia strong
> over-prediction, +0.65; Washington moderate over-prediction, +0.26).
> Production calibrations span the calibration ladder: Maine Tier 2 per-species
> (26 parameters, LL = +34.2 over n = 612 paired plots), Georgia Tier 1 uniform
> θ = 0.30 (LL = +5.26 over n = 218 paired plots), and Washington Tier 2
> per-species (50 parameters, total LL = −174.4 over n = 805 paired plots,
> per-plot LL = −0.217). Calibration changes 100-year per-cell biomass
> asymptotes by 7%, 35%, and 67% respectively — substantial implications for
> state-scale carbon accounting. We identify a three-mode calibration
> degeneracy pathology novel to the forest landscape modeling literature:
> (1) active-growth degeneracy, where very low θ produces near-zero growth
> and a trivial fit at the initial condition; (2) empty-aggregator degeneracy,
> where per-plot pipeline failures yield LL = 0 by default; and (3) sample-size
> degeneracy, where few successful plot pairs yield trivially small LL
> magnitudes that mislead total-LL optimizers. We propose three corresponding
> guards (active-growth fraction ≥ 0.50, non-empty per_plot.csv, minimum
> n_pairs ≥ 300) and recommend per-plot LL normalization as a complementary
> safeguard. A six-test validation framework (k-fold CV, time-out-of-sample,
> leave-one-ecoregion-out, cross-state, bootstrap CI, IC perturbation)
> addresses standard overfitting concerns. The framework, code, calibrated
> parameter vectors, three-mode pathology diagnostic, and interactive Carbon
> Atlas dashboard are released under MIT license at github.com/holoros/landis2HPC
> (v1.0 tag, 2026-05-17).

### Data availability statement

> All FIA tree-list inputs used for calibration are derived from the publicly
> available USDA Forest Service FIA Database (https://apps.fs.usda.gov/fia/datamart/).
> Per-state best-fit calibration vectors (theta_best/*.csv), per-plot calibrated
> trajectory data (data/), validated disturbance extension parameter files, and
> all reproducibility scripts are released at github.com/holoros/landis2HPC
> under MIT license. Permanent DOI archive at Zenodo: 10.5281/zenodo.XXXXXXX
> (to be assigned at submission time).

### Code availability statement

> Calibration code (tools/), per-plot scenario builders, CMA-ES drivers,
> aggregators, likelihood implementations, and validation framework scripts
> are released at github.com/holoros/landis2HPC under MIT license. PERSEUS
> framework lives in perseus/ subdirectory; foundation .NET 8 DLL patches
> required for LANDIS-II v8 extension loading live in console-patch/. Compute
> infrastructure: OSC Cardinal HPC cluster using bind-mounted patched DLLs in
> the LANDIS-II v8 Foundation Apptainer image.

### Author contributions (CRediT)

| Author | Contributions |
|---|---|
| Weiskittel, A.R. | Conceptualization, Methodology, Software, Data Curation, Visualization, Writing — Original Draft, Project Administration, Funding Acquisition |
| Lucash, M.S. | Methodology, Resources (Washington parameter set), Writing — Review & Editing |
| Scheller, R.M. | Methodology (LANDIS-II framework), Software (Foundation patches), Writing — Review & Editing |

### Funding statement (template)

> This work was supported by the Center for Research on Sustainable Forests
> at the University of Maine. Computing resources were provided by the Ohio
> Supercomputer Center under allocation PUOM0008. [Add USDA NIFA grant
> numbers or other funding source IDs if applicable.]

## Timeline (proposed)

| Week | Milestone |
|---|---|
| 1 (this week) | Co-author review of the manuscript draft + GitHub repo |
| 2 | Address co-author comments. Tier 2 results land for WA + GA. Refresh Section 3.3 |
| 3 | Final read-through. Generate PDF via Pandoc. Submit to bioRxiv |
| 3 (same day) | Tag v1.0 on GitHub. Submit to Environmental Modelling & Software |
| 4 | Social media + stakeholder outreach announcing the preprint |
| 4–6 | LANDIS-II Foundation tool registry submission |
| 6+ | Reviewer round 1 expected from Environmental Modelling & Software |

## Common pitfalls to avoid

1. **Don't submit to bioRxiv before co-authors have reviewed.** Preprints are public; correcting an embarrassment after the fact is hard.

2. **Don't claim "in press" on bioRxiv.** Status is "submitted" or "pending review" until journal acceptance.

3. **Make sure the GitHub repo is genuinely public** by the time the preprint is posted, not just promised. Reviewers will check.

4. **Don't post the manuscript PDF to multiple preprint servers.** Pick one (bioRxiv is the convention for forest ecology methods papers).

5. **Be careful with figure captions.** Make sure the bioRxiv PDF has proper figure captions even if the source markdown doesn't render them inline.

## Pandoc command for PDF generation

```bash
# From the repo root, when paper is final:
pandoc docs/methods_paper_FINAL_ASSEMBLY.md \
  --bibliography=docs/references.bib \
  --citeproc \
  --csl=https://www.zotero.org/styles/environmental-modelling-and-software \
  --template=docs/templates/emss_template.tex \
  --pdf-engine=xelatex \
  -o PERSEUS_methods_paper_v1.0.pdf
```

(Note: `emss_template.tex` would need to be downloaded/built from Elsevier's
template; or use a generic article class as fallback.)
