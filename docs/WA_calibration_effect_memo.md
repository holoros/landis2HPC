# Washington calibration effect on year-100 biomass

**Date:** 2026-05-21
**Data:** real per-plot LANDIS trajectories from `perseus/dashboard/atlas/WA.json`, n = 4429 FIA plots with both a Tier 0 (literature) and a calibrated trajectory at years 0, 25, 50, 75, 100.
**Figure:** `perseus/figures/wa_calibration_effect_year100.png`

## What the calibration does

Across 4429 Washington plots the calibration lowers the year-100 standing biomass from a literature median of 562 Mg/ha to a calibrated median of 185 Mg/ha, a 67 percent reduction. The reduction is remarkably uniform in proportional terms: the median per-plot ratio of calibrated to literature year-100 biomass is 0.296, essentially the Tier 1 optimum of theta = 0.30. Panel B of the figure shows the per-plot scatter tracking that 0.30 line, with real spread around it rather than a hard rescaling.

## Level correction, not growth shutdown

The large drop in the asymptote does not mean the calibrated forest stops growing. Classifying each plot by its net change from year 0 to year 100 under calibration, 53 percent of plots gain more than 5 percent biomass over the century, 44 percent hold within 5 percent, and only 3 percent decline by more than 5 percent. So the calibration pulls down the long-run biomass ceiling while leaving most plots on a positive, if shallower, accrual path. The earlier impression that calibrated trajectories were flat came from a single high-biomass plot; the population is more nuanced.

## Interpretation

The literature Tier 0 ANPP and maximum-biomass parameters substantially overpredict standing biomass in Washington, by roughly a factor of three at the century mark. The inverse calibration corrects that level so the simulated forest matches the multi-cycle FIA observations. That a free per-plot optimization lands so close to the uniform theta = 0.30 is independent support for the Tier 1 result and for the magnitude of the literature overprediction in this region.

## Caveat

These trajectories are the Tier 1 uniform theta = 0.30 rendering recorded in the WA atlas, not the v1.0 Tier 2 per-species production vector. The Tier 2 per-plot trajectories are pending the v1.x trajectory export. The level correction reported here is therefore the Tier 1 picture; the Tier 2 vector tunes the same correction per species and is expected to shift the distribution modestly, not change its character.
