# Maine Tier 2: structure of the per-species correction

**Date:** 2026-05-21
**Data:** `tier2_species_multipliers` in `perseus/dashboard/atlas/ME.json` (13 species, each with an ANPP multiplier and a maximum-biomass multiplier).
**Figure:** `perseus/figures/me_tier2_multiplier_structure.png`

## What the per-species corrections look like

Plotting each species by its ANPP multiplier (productivity correction) against its maximum-biomass multiplier (biomass-ceiling correction) shows that the Maine calibration does something a uniform multiplier cannot. Most species sit in the upper-right quadrant, where both productivity and the biomass ceiling are scaled up, consistent with the broad finding that the literature underpredicts in the Northeast. Sugar maple, red maple, yellow birch, hemlock, white spruce, and black spruce all land there.

Two species sit in the lower-left, overpredicted on both axes: cedar and pine carry ANPP multipliers near 0.84 and biomass multipliers below 1.0, so the literature was too generous for them in this region.

The standout is balsam fir, alone in the lower-right: its ANPP is scaled up sharply, by 2.26, while its maximum biomass is cut to 0.54. That is the textbook signature of a fast-growing, short-lived, low-biomass species. The calibration recovered it from data without being told the species' life history.

## Why it matters

The corrections are not a single offset wearing 13 hats. They separate productivity from biomass ceiling and they sort species into ecologically coherent groups. That is direct evidence that Tier 2 per-species calibration is capturing real between-species structure in Maine, and it is the strongest single-state argument for going past the uniform Tier 1 multiplier where the data support it. It also gives a clean, interpretable figure for the methods paper's Maine result.
