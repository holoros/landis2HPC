# Co-author review email — draft

**For Aaron's review before sending.** Personalize the recipient list and adjust tone as appropriate.

---

**To:** Rob Scheller <rmschell@ncsu.edu>, Melissa Lucash <mlucash@uoregon.edu>, [GA/WA collaborators TBD]
**Cc:** [CRSF colleagues, postdocs]
**Subject:** PERSEUS multi-state LANDIS-II calibration — v1.0-rc1 ready for your review

---

Rob, Melissa, all —

I'm circulating the draft methods paper for the multi-state LANDIS-II calibration work we've been building since the SBW outbreak modeling threads from last year. Tagged the v1.0-rc1 release today; the full draft, code, calibrated parameter vectors, validation framework, and an interactive Carbon Atlas are now public at:

**https://github.com/holoros/landis2HPC/releases/tag/v1.0-rc1** (PERSEUS framework lives in `perseus/`)

**Quick navigation:**
- Manuscript (start here): [`docs/methods_paper_FINAL_ASSEMBLY.md`](https://github.com/holoros/landis2HPC/blob/main/docs/methods_paper_FINAL_ASSEMBLY.md)
- One-page summary of what's final vs rc1: [`docs/v1.0-rc1_summary.md`](https://github.com/holoros/landis2HPC/blob/main/docs/v1.0-rc1_summary.md)
- 3-panel Tier 2 species heatmap: [`perseus/figures/t2_species_heatmap_3state_2026-05-17.png`](https://github.com/holoros/landis2HPC/raw/main/perseus/figures/t2_species_heatmap_3state_2026-05-17.png)
- CMA-ES convergence snapshot: [`perseus/figures/t2_cma_convergence_2026-05-17.png`](https://github.com/holoros/landis2HPC/raw/main/perseus/figures/t2_cma_convergence_2026-05-17.png)

The headline finding is that literature LANDIS-II Biomass Succession parameters are systematically biased in direction-specific ways across our three states — Maine slight under-prediction, Georgia strong over-prediction, Washington moderate over-prediction. A four-tier calibration ladder against the FIA multi-cycle hindcast closes the gap with state-specific optima. The biggest single number is that calibration changes the 100-year per-cell biomass asymptote by 7% in Maine, 35% in Georgia, and 67% in Washington — large enough to matter for any state-scale carbon analysis that uses LANDIS-II projections.

**Three things I'd particularly value your read on:**

1. **The calibration degeneracy diagnostic** (Section 4.3 of the methods paper, full memo at [`docs/calibration_degeneracy_finding.md`](https://github.com/holoros/landis2HPC/blob/main/docs/calibration_degeneracy_finding.md)). At very low θ, LANDIS produces near-zero growth — the LL minimum becomes a trivial fit where predicted ≈ FIA observed because both stay near the initial condition. We propose the active-growth fraction as a constraint. I think this is a paper-novel methodological contribution but I want a sanity check from people who've spent more time inside the LANDIS internals than I have. Is there a literature on this I'm missing?

2. **Cross-state generalization** (Section 4.2 + the cross-state penalty matrix in Figure 5C). Each state's best calibration produces a 5–9 LL/cell penalty when applied to another state. This argues strongly for state-specific calibration rather than regional parameter transfer — but I want to make sure I'm framing this in a way the field will recognize and not over-claim.

3. **The Tier 2 per-species multipliers for Maine** (Figure 6, [`perseus/figures/me_tier2_species_heatmap.png`](https://github.com/holoros/landis2HPC/raw/main/perseus/figures/me_tier2_species_heatmap.png)). Balsam fir at ANPP×2.26 with BMAX×0.54 is the strongest signal — fast growth with a lowered ceiling, consistent with budworm-driven stagnation. Does this match the field intuition you'd expect?

**Status of WA + GA Tier 2 (RC1 snapshots in this release):** Both CMA-ES chains are still running on Cardinal as of email send. GA T2 has converged at negLL=−15.75 (LL=+15.75) across iterations 0, 5, and 6 — the rc1 snapshot is the converged solution. WA T2 v2 (resumed with a patched driver that flags degenerate empty-aggregator candidates) holds iter1 best at negLL=50.01 (LL=−50) while exploring with the new constraint. Both will land in the next 12–24 hours. v1.0 final swap is only the two Tier 2 theta vectors + figure refresh. The paper structure, headline argument, and the directional asymmetry finding are stable in v1.0-rc1.

**What I'd love to know from each of you:**

- *Rob:* Is the framing of the calibration ladder as a generalization of the existing LANDIS calibration practice (PnET-II, hand-tuned, Bayesian) appropriate? Section 1 + Section 4.1.
- *Melissa:* The Washington calibration uses your 2018 parameter set as the Tier 0 baseline. Does the over-prediction story I'm telling for WA make ecological sense? The 67% asymptote reduction is substantial.
- *Anyone with GA expertise:* I'm thin on Georgia field intuition. The southern pine over-prediction at θ=0.30 is heavy — too heavy?

**Practical asks:**

- Any sense check on framing, claims, and figures (the paper has 9 figures in `perseus/figures/`)
- Confirm your authorship and ordering preference. Current default order is alphabetical after the lead author; happy to discuss
- Any state-specific collaborators I should add for GA + WA?
- Target journal: **Environmental Modelling & Software**. Open to alternatives if you have a strong preference

**Timeline:** Aiming to submit within 3 weeks pending your review. Companion scenario paper is ~50% drafted and depends on the factorial sweep that will follow this manuscript's acceptance.

The interactive Carbon Atlas at [`perseus/dashboard/atlas/index.html`](https://github.com/holoros/landis2HPC/tree/main/perseus/dashboard/atlas) gives a nice visual entry point if you'd like to share the work with anyone before the paper is in.

Thanks in advance. Happy to call to discuss any of this if useful.

— Aaron

---

## Adjustments / variants

**If sending to specific GA contacts (e.g., Asaro, Coulston):**
> "We've adapted your southern pine beetle parameterization from Asaro et al. 2017
> for the Climate BDA agent for Georgia. The agent file is at
> `perseus/disturbance_agents/Climate-BDA_Agent_SPB.txt` if you want to inspect.
> Would value your read on whether the outbreak cycle parameters match your
> field-derived estimates."

**If sending to LANDIS-II Foundation (separate email):**
> "Submitting PERSEUS to the LANDIS-II Foundation tool registry — see
> the deposit plan at [`docs/deposit_plan.md`](https://github.com/holoros/landis2HPC/blob/main/docs/deposit_plan.md).
> Code, validated disturbance agents, and reproducibility scripts all under MIT.
> Built on the .NET 8 patches we landed in our earlier landis2HPC release."

**Quick-summary one-pager for non-academic stakeholders:**
> "Forest biomass projections for Maine, Georgia, and Washington using LANDIS-II
> calibrated against FIA observations. Interactive viewer at [PERSEUS Carbon Atlas].
> Manuscript: github.com/holoros/landis2HPC. Headline: literature parameters
> over-state state-scale 21st-century biomass by 7-67% across our three states."

## Pre-send checklist

- [ ] Update Rob's and Melissa's email addresses if these are wrong
- [ ] Add any missing GA/WA partner contacts
- [ ] Verify the repo is public (currently private on GitHub? Check)
- [ ] Consider whether to attach the integrated assembly PDF as a single file, or rely on the GitHub repo (recommend: GitHub link only, lower friction)
- [ ] Add specific section page references when the paper is in final form
- [ ] CC to: aaron.weiskittel@maine.edu (self-cc for filing)
