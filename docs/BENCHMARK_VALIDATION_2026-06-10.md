# External benchmark validation against American Forests state CBM reports

Date: 2026-06-10. Benchmark source: American Forests "Effects of Forest Management
and Wood Utilization on Carbon Sequestration and Storage" series
(https://www.americanforests.org/tools-research-reports-and-guides/research-reports/).
These studies run CBM-CFS3 plus an HWP model, the same family as our CBM, so they are a
direct ground truth for our CBM and a sanity bound for the other four models.

Reference values captured in `harmonized/americanforests_cbm_benchmarks.csv`. Validation
code in `harmonized/benchmark_validation.py` and `harmonized/cbm_init_diagnostic.py`.
Cross-model reserve growth in `harmonized/reserve_growth_crossmodel.csv`.

## What the published reports say (the benchmark)

Minnesota (2026): forest stays a net sink through 2100 but the sink weakens; carbon
density rises only slightly under BAU; climate-smart management adds 61% more cumulative
mitigation than BAU. Oregon (2026): climate-adjusted BAU becomes a consistent net carbon
SOURCE from 2029, driven by an 825% increase in high-severity wildfire area by 2100 and
declining productivity; carbon stocks fall. California (2025): forest carbon declining;
management could cut emissions 14% over 50 years. Maryland (2023) and Pennsylvania (2023):
forest is a sink; management could raise the sink 29% and 38% by 2030 (short horizon, flux
metric not stock).

The throughline: the published CBM studies project the western forest declining (fire and
climate) and the eastern forest as a near-saturated sink with only modest gain available.

## Finding 1 (systematic): CBM under-initializes the eastern US, so its reserve over-projects

`cbm_init_diagnostic.py` compares CBM's spin-up starting aboveground live carbon per ha
against the FIA design stocking per ha. 25 of 48 states start below 1.5x (FIA over CBM),
concentrated in eastern hardwoods: WV 2.65x, CT 2.63x, IL 2.51x, MD 2.47x, PA 2.43x,
OH 2.39x, TN 2.34x, KY 2.30x, VA 2.30x. CBM starts these mature forests at roughly 34 tC/ha
when FIA measures roughly 85. The no-disturbance reserve then "regrows" into the landscape,
producing 150 to 207% growth by 2100 in exactly those states. Because we anchor the 2025
value to FIA and keep the relative shape, the under-initialization inflates the eastern
reserve by 2 to 2.7x. The dry interior West is the opposite (CBM starts above FIA: NV 0.24,
UT 0.36, AZ 0.52) but those states hold little carbon.

Fix: re-initialize the CBM no-disturbance run from FIA-observed stocking rather than the
conus_dist spin-up age structure, then rerun `build_cbm_reserve.R`. Until then, treat CBM
eastern reserves as an over-projection and prefer FVS_cal for the eastern reserve shape.

## Finding 2 (systematic): FVS over-projects the western US

Cross-model reserve growth 2025 to 2100 (`reserve_growth_crossmodel.csv`): FVS reserves grow
300 to 600% in CA and OR (CA FVS_def +333%, OR FVS_def +304%; calibrated +272% and +223%).
That is biophysically impossible for mature, fire-prone western conifer forests. FVS growth
without disturbance and without strong density-dependent mortality saturation runs away on
long-lived conifers. Calibration tempers it (lower) but not enough. CBM is far more
restrained in the West (CA +54%, OR +22%), closer to plausible, though still optimistic
versus the reports' projected decline.

## Finding 3: every model's reserve is a no-disturbance ceiling, not a likely projection

Median reserve growth 2025 to 2100 by model: yield curves +34% (range -36 to +393), FVS_cal
+100%, CBM +127%, FVS_def +145% (up to +608). Only the yield curves produce any declining
states. None reproduce the climate and fire-driven decline the American Forests reports
project for the West, because the harmonized reserve removes harvest AND disturbance by
construction. The reserve answers "what does each growth engine do absent disturbance," which
is a legitimate comparison, but it is an upper bound, not a forecast. A disturbance overlay
(fire, drought mortality, climate productivity adjustment) is needed before any reserve
trajectory should be read as a projection, especially in the West.

## Finding 4: the common HCS harvest under-harvests the western timber states

`benchmark_validation.py` check H: CA, OR, and WA carry near-zero HCS harvest rates
(CA 0.002%/yr = 144 clearcut ha/yr, OR 0.003%/yr = 190 ha/yr, WA 0.010%/yr) on 12 to 13
million forest ha. For the top US softwood producers these are orders of magnitude too low,
and they collapse the scenario spread (reserve vs intensive 2100 carbon differs <1% in
CA/OR). MN by contrast carries 0.335%/yr and shows a healthy 24% spread. The Oregon report's
45% management effect cannot appear in our pipeline while OR harvest is set near zero.

Fix: re-derive the HCS harvest rate for the western states from actual removal data; the
current extraction appears to capture only a small subset of western harvest.

## Bottom line for the cross-model synthesis

The headline that the models diverge by roughly 4 to 5x is real, and the benchmarking now
attributes it to specific, fixable causes rather than irreducible structural uncertainty:
CBM eastern under-initialization, FVS western run-away growth, the missing disturbance
overlay, and the collapsed western harvest. The internal stress test (anchor, monotonicity,
HWP, cross-model anchor agreement) still passes with zero failures; these are accuracy and
initialization issues, not pipeline-consistency failures.

## Refinements applied (2026-06-10)

CBM eastern under-initialization (Finding 1) is now corrected with an entry-point method in
`build_cbm_reserve.R` (--align TRUE, default). For under-initialized states (FIA stocking >1.05x
the CBM spin-up t0) it estimates CBM's own carrying capacity (Asym) and rate (k) by regressing
the annual AG increment on AG size (monomolecular dAG/dt = k(Asym-AG), a plain lm), then projects
forward from the FIA-observed stocking: AG(tau)=Asym-(Asym-fia)exp(-k*tau). This keeps CBM's
growth form and carrying capacity but removes the spin-up regrowth ramp, and extrapolates to 2100
without truncation. Effect: eastern reserve growth dropped from 176-207% to 50-87% (WV 207->57,
MD 179->50, OH 200->63, PA 176->50), now bracketed by FVS_cal. Under-init flags fell from 30 states
to 5 low-carbon edge cases (FL, KS, ND, OK, TX). The raw version is kept at
`cbm_reserve_raw_anchored.csv` for audit. This is an INTERIM fix; the true fix is a CBM run
initialized from FIA stocking. Stress test still passes (anchor intact, 0 failures).

Western HCS harvest (Finding 4) diagnosed as a data-product limitation, not a bug: the TM2016
harvest-probability raster assigns harvest to ~31% of GA forest pixels but only 0.03% of OR
(probability where present ~0.78 in both). Grids align and the GA extraction works. The common
harvest is self-consistent across models (all get the same low western harvest) but cannot
reproduce western state management studies. Numeric override deferred to a better western harvest
layer (LCMS/LANDFIRE harvest, FIA TPO, ODF records).

## Disturbance/climate overlay applied (2026-06-10) - addresses Findings 2 and 3 together

`apply_disturbance_overlay.R` + `disturbance_rates_by_state.csv` subtract a stand-replacing-
equivalent annual aboveground-carbon loss from any anchored reserve: dB/dt = g_reserve(t) -
m(t)*B(t), with m(t) a state fire-mortality rate ramped 2025->2100 (order-of-magnitude from
recent MTBS-era burned fractions and the OR report's +825% high-severity fire trend; editable
parameter, treated as a disturbance-aware sensitivity, not a calibrated projection). Effect on FVS
calibrated reserve 2100 growth: CA +272% -> +64%, OR +223% -> +116%, NM +329% -> +158%, AZ +72% ->
-32% (now declines, matching the reports), while eastern states barely move (OH 104 -> 99, ME 46 ->
43). This simultaneously constrains the FVS western run-away (Finding 2) and lets western reserves
decline (Finding 3). Applied to FVS, CBM, YC, LANDIS, CEM (suffix `_disturbed.csv`).

CONUS effect (full-coverage ensemble, `uncertainty_conus_disturbed.csv`): 2100 ensemble median
24.3 -> 23.1 Pg C and inter-model CV 21.5% -> 19.3%. Figure: `fig_disturbance_compare.png`.

RATE CALIBRATION (2026-06-10): the base rates were replaced with DATA-GROUNDED values derived from
the CBM runs themselves (`derive_disturbance_rates.py`, `disturbance_rates_data.csv`): the AG-live
gap between the no-disturbance BAU run and the LCMS natural-only run (`pools_<ST>_lcms_nat_HIST.csv`,
50yr, observed fire/insect/wind, harvest excluded) gives the implied annual loss rate on the
pipeline's own basis. These came out ~10x LOWER than my first order-of-magnitude guesses (CA 0.072
vs 0.70 %/yr, OR 0.113 vs 0.35), so the climate ramp (from the OR report's fire trend) is retained
on top. KEY FINDING: with the data-grounded historical rates plus a 3x western climate ramp, the
FVS western over-projection LARGELY PERSISTS (CA reserve +272% -> +241%, OR +223% -> +183%). So the
western over-projection is substantially an FVS growth-engine issue (no density-dependent mortality
/ max-SDI saturation), NOT only missing disturbance. The remaining top structural fix is constraining
FVS western growth directly (an FVS re-run with mortality/max-SDI), which a disturbance overlay alone
cannot supply. CAVEAT: the LCMS base reflects the 1985-2020 regime, which predates the recent fire
escalation, so even the ramped rate is likely conservative for the West.

## Remaining refinement queue

1. CBM run initialized from FIA stocking (replaces the interim entry-point correction).
2. Better western harvest layer so CA/OR/WA scenario contrast is real and the OR 45% benchmark is testable.
3. Calibrate the disturbance rates against MTBS/LANDFIRE burned-area + severity per state (replace the order-of-magnitude table).
4. Intra-model bands: extend FVS posterior to all 48 states (priority subset running, job 11460953); set up a CBM parameter-draw ensemble (libcbm runs only in the SIF; needs a perturbation harness).

## Uncertainty quantification (2026-06-10)

`uncertainty_ensemble.R` separates the three uncertainty sources and expresses a band.
Outputs: `uncertainty_by_state_year.csv`, `uncertainty_conus.csv`, `fig_uncertainty_A_conus.png`,
`fig_uncertainty_B_states.png`.

- INTER-MODEL (structural): spread across FVS, LANDIS, CEM, yield curves, CBM at each state and
  year. Same inputs, anchor, and harvest, so this is pure model structure and it is the dominant
  term. CONUS reserve total (full-coverage models FVS/YC/CBM): 2025 15,279 Tg C (spread 0 by the
  shared anchor), 2050 median 19,985 (CV 12.9%), 2075 22,203 (CV 19.1%), 2100 median 24,293 Tg C
  (CV 21.5%, FVS high 32,207, YieldCurve low 22,348). State-level structural CV is far larger:
  median 42.5% and up to 132% at 2100 (CA, OR), where FVS western run-away growth diverges from
  CBM restraint. Errors partially cancel in the CONUS aggregate.
- INTRA-MODEL (parameter): now the REAL FVS Bayesian posterior band where available. The existing
  FVS posterior pipeline (fvs_posterior_uncertainty.py, 30 draws x plot subsample) has run for 7
  states (GA ID IN ME MN OR WA); `fvs_posterior_ci_all.csv` gives relative 2.5/97.5 bounds per
  state and year, converted to a parameter SD and applied to the anchored FVS mean. For the other
  41 states the |cal-def|/2 proxy is used until the posterior array is extended (needs the
  state->variant manifest; standinit_by_variant and treeinit_h are already present). CBM's 500-draw
  posterior was NOT produced for the CONUS bau run, so a true intra-CBM band is flagged as future
  work rather than fabricated.
- FIA SAMPLING (anchor): the common FIA design CV (cv_pct), propagated as median * cv/100.

Total SD combines the three in quadrature; the 90% band is median +/- 1.645*total_sd (floored at 0).
Example 2100 state bands (Tg C): GA 1007 [821, 1193] (tight, CV 11%), PA 826 [505, 1147], MN 473
[140, 806], OH 409 [24, 794], ME 578 [71, 1084], CA 1382 [0, 3711], OR 1528 [0, 3360]. The CA/OR
bands hitting zero reflect the FVS western over-projection, tying the uncertainty back to Finding 2.

VARIANCE DECOMPOSITION (the headline uncertainty result). Mean state-level component SD (Tg C):
structural rises from 0 (2025) to ~98 (2050), 160 (2075), 200 (2100); FVS parameter ~21, 44, 60;
FIA sampling ~5, 6, 6. On the states with a real Bayesian posterior band, structural uncertainty
is 11x the parameter uncertainty by 2050 and 41x by 2100. In plain terms: which model you choose
matters far more (about 40x by end of century) than parameter uncertainty within a model or FIA
sampling error. This is why the priority is reducing structural error (the CBM and FVS refinements
above), not chasing tighter parameter bands. Figures: fig_uncertainty_A_conus.png (CONUS fan),
fig_uncertainty_B_states.png (state structural CV), fig_uncertainty_C_decomposition.png (this result).
