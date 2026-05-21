# A regional sign-flip in literature productivity bias

**Date:** 2026-05-21
**Data:** production calibration parameters in `perseus/dashboard/atlas/{ME,WA,GA}.json`
**Figure:** `perseus/figures/crossstate_literature_bias.png`

## The finding

The three production-calibrated states do not just differ in how much the literature parameters need correcting; they differ in the direction. In Maine the calibration scales the literature ANPP up: 85 percent of the 13 species carry an ANPP multiplier above 1.0, with a median of 1.31 and a range from 0.84 to 2.26. In Washington and Georgia the calibration scales the literature down hard, to a Tier 1 uniform optimum of theta = 0.20 and theta = 0.30 respectively. So the literature underpredicts productivity in the Northeast example and overpredicts it in the Western and Southeastern examples.

## Why it matters

A calibration framework that only ever pulled parameters in one direction would be easy to dismiss as a global offset or a units artifact. A framework that pulls up in one region and down in others is doing something more informative: it is surfacing genuine, regionally structured bias in the off-the-shelf literature parameterization. That is a stronger argument for region-specific calibration than any single-state result, and it is a candidate headline for the methods paper and the scenario paper.

## Important caveat

This is a qualitative cross-region signal, not a precise quantitative comparison. Maine is calibrated at Tier 2 (per-species multipliers on both ANPP and maximum biomass), while Washington and Georgia are shown at Tier 1 (a single uniform multiplier on both). The Maine numbers are per-species ANPP multipliers; the Washington and Georgia numbers are uniform theta values. The robust, defensible claim is the sign of the correction, not the exact magnitudes side by side. When the Washington and Georgia Tier 2 per-plot vectors land, this synthesis should be redrawn on a like-for-like basis.

## Next

Fold this into Methods Section 3 and the scenario paper discussion once the Great Lakes states land, so the regional-bias claim spans six states rather than three. The Minnesota, Wisconsin, and Michigan provisional per-plot LLs already hint at a third regime in the upper Midwest.
