# Scenario Paper Section 2. Methods (draft)

**Companion to "Multi-state inverse parameterization of LANDIS-II Biomass Succession"**
**~2,400 words. Target: Forest Ecology and Management.**

## 2.1 Calibration source

The succession parameters used in this study are the v1.0 production calibrations developed in our companion methods paper (Weiskittel et al. *in prep*) and summarized in Table 1. Each of the three states (Maine, Georgia, Washington) has a state-specific calibration vector fit to the FIA multi-cycle hindcast against untreated FIA plots in 2001–2022. Maine and Washington use Tier 2 per-species multipliers (26 and 50 free parameters respectively); Georgia uses Tier 1 uniform θ = 0.30 (Tier 2 deferred from the v1.0 release pending a pipeline diagnostic, with re-run in flight at submission time).

Table 1. PERSEUS v1.0 production calibrations applied across the scenario factorial. Per-plot LL values are reported on the multi-cycle hindcast paired-plot sample described in the companion methods paper Section 2.4.

| State | Tier | LL | n paired plots | Per-plot LL | 100-yr asymptote vs T0 |
|---|---|---:|---:|---:|---:|
| Maine | T2 per-species (26 params) | +34.2 | 612 | +0.056 | −7.5% |
| Georgia | T1 uniform θ = 0.30 | +5.26 | 218 | +0.024 | −35% |
| Washington | T2 per-species (50 params, iter1_cand11) | −174.4 | 805 | −0.217 | −67% |

The companion methods paper presents six stress + validation tests (k-fold CV, time-out-of-sample, leave-one-ecoregion-out, cross-state, bootstrap CI, IC perturbation) that establish parameter set robustness. It also reports a three-mode calibration degeneracy pathology (active-growth, empty-aggregator, sample-size) and three driver guards that we recommend as standard practice for any inverse-parameterization framework using per-plot Monte Carlo runs anchored against landscape-scale observations.

## 2.2 Scenario factorial design

We define a 3 × 3 × 3 = 27-cell factorial across three orthogonal axes: climate, harvest, and disturbance. Each axis has three levels (Table 1).

**Climate axis:**
- *baseline*: Historical PRISM monthly precipitation + min/max temperature, 1991–2020 reference period.
- *ssp245*: HadGEM3-GC31-LL forcing downscaled to per-ecoregion monthly values via bias-corrected statistical downscaling (Hempel et al. 2013 for global; per-state regional downscaling: Maine via Fer et al. 2018, Georgia via Liu et al. 2022, Washington via Halofsky et al. 2020).
- *ssp585*: Same procedure under high-emission scenario.

For each climate level we generate a 100-year `climate.csv` covering the 2001–2100 projection horizon, filtered to the per-plot ecoregion as required by the single-cell scenario architecture (companion paper Section 2.3).

**Harvest axis:**
- *none*: No harvest extension loaded.
- *current rate*: State-specific baseline harvest rates derived from FIA `TRTCD` records. Maine: 1% area per year, 30% basal area removal (Pelletier et al. 2015). Georgia: 4% area per year, 60% basal area removal (Coulston et al. 2014; primarily even-aged plantation rotation). Washington: 1.5% area per year, 50% basal area removal (Curtis et al. 1999; mixed federal + private).
- *PERSEUS reference*: Uniform 2% area per year, 50% basal area removal across all states. This is the PERSEUS-designed reference scenario used to enable cross-state comparison of carbon-vs-harvest tradeoff.

**Disturbance axis:**
- *none*: No disturbance extension loaded.
- *baseline*: State-appropriate disturbance regime parameterized to historical 1991–2020 rates. Maine: Original Wind (Original Wind v4 extension with ME-calibrated parameters from Foster et al. 2015) plus Climate BDA / SBW (Spruce Budworm agent — see Methods paper Section 2.6 for parameter source). Georgia: Original Wind (low-intensity baseline) plus Climate BDA / SPB (Southern Pine Beetle, parameterized from Asaro et al. 2017). Washington: Original Fire (parameterized to USFS NW Region 6 historical fire return interval data 1985–2020) plus Climate BDA / MPB (Mountain Pine Beetle, Carroll et al. 2003).
- *climate-amplified*: State-specific climate amplification of the baseline regime. Maine: SBW outbreak amplitude increased by 25% (Régnière et al. 2012 SSP585 projection). Georgia: SPB outbreak frequency increased from every ~10 years to every ~7 years (Trân et al. 2007 climate sensitivity). Washington: fire return interval reduced from 75 to 50 years (consistent with Kitzberger et al. 2017 SSP585 projection); MPB outbreak probability increased by 50% (Bentz et al. 2010).

Hurricane v3 is parameterized for Georgia using Atlantic Hurricane Database (HURDAT2) climatology; we apply Hurricane parameters only in the Georgia *baseline* and *climate-amplified* disturbance levels.

## 2.3 Per-plot scenario instantiation

Each factorial cell × plot combination produces an independent LANDIS-II scenario directory. The unified scenario builder (`build_plot_scenario_factorial.sh` — released with the methods paper) constructs scenarios with the per-plot ecoregion, calibrated species parameters, climate file appropriate to the selected scenario level, harvest extension file appropriate to the selected harvest level, and one to three disturbance extension files appropriate to the selected disturbance level. The single-cell architecture is preserved for tractability (companion paper Section 2.3) but the disturbance extensions retain their full stochastic event scheduling: each plot in the factorial cell sees an independent realization of disturbance events appropriate to its scenario's amplitude parameters.

With 4,461 WA plots, 5,167 GA plots, and 1,216 ME plots = 10,844 total plots × 27 cells = **292,788 LANDIS-II runs.** At single-cell runtime of ~15 seconds per run, this is 1,220 CPU-hours. Each plot runs 100 years from the first FIA measurement to support consistent reporting at calendar year 2003, 2025, 2050, 2075, and 2103.

## 2.4 Stochastic replicates

LANDIS-II disturbance extensions schedule events stochastically. Two replicates with different `RandomNumberSeed` values produce different disturbance event trajectories. To capture this variability we run 5 replicates per factorial cell × plot, each with a different seed (42, 17, 137, 1985, 2024). This gives us 5 × 292,788 = **1.46 million runs** for the full factorial, or ~6,100 CPU-hours = approximately 2.5 weeks of Cardinal time at our typical 150-task concurrency. For undisturbed factorial cells (*none* on the disturbance axis), the single realization is deterministic and replicates collapse to a single run; this brings the effective total to ~1.0 million runs.

We report median + 95% CI (across replicates) for all per-state aggregate biomass and carbon metrics.

## 2.5 Output extraction

Each plot run produces standard LANDIS-II outputs (per-species biomass tifs per timestep, plus disturbance event logs). The factorial-paper aggregator (`aggregate_factorial.py`) extracts the per-year TotalBiomass, woody, non-woody, and per-species biomass into a flat compact CSV per plot × cell × replicate, then deletes the run directory to free inodes. The resulting per-plot CSVs are ~5 KB each, totaling ~1 GB across the full factorial.

We track three derived quantities:

1. **Total ecosystem biomass (Mg/ha)** per plot per year — the primary carbon-stock metric.
2. **Cumulative harvested wood volume (Mg/ha)** per plot — read from the harvest extension's event log.
3. **Disturbance-driven mortality (Mg/ha)** per plot — read from the wind/fire/BDA event logs.

For harvested wood we apply a 30-year exponential decay function to estimate harvested wood products (HWP) carbon storage (Skog 2008; consistent with USFS NIR-FCRF methodology). HWP carbon plus standing carbon plus dead-wood/litter carbon comprises total ecosystem carbon.

## 2.6 Aggregation to state scale

For each (state, climate, harvest, disturbance, replicate) combination, we aggregate per-plot biomass and carbon trajectories to state scale via plot expansion using FIA's `EXPNS` weights (Bechtold and Patterson 2005). The state aggregate is reported in MMT (million metric tons) of biomass or carbon. We also aggregate to ecoregion to enable spatial pattern visualization in the Results section.

## 2.7 Compute infrastructure

The factorial runs on the Ohio Supercomputer Center Cardinal cluster, the same infrastructure used for the methods paper calibration. Each factorial cell × state is launched as a chained SLURM array submission with 150-task concurrency, identical to the Tier 1 ladder submission pattern. The full factorial expected completion is approximately 14 days of wall-clock time at the typical Cardinal availability.

Per-state factorial submission follows: build chunks → submit chunk 0 → master-chain wrapper submits subsequent chunks as queue clears → aggregator runs once all chunks complete. The reproducibility statement matches the methods paper's verbatim.

## 2.8 Statistical analysis of factorial results

We analyze three categories of comparison.

**Climate sensitivity:** For each state and each (harvest, disturbance) combination, we compute the difference in year-100 biomass between SSP245 and baseline, and between SSP585 and baseline. We report the median and 95% CI of these differences across plots and replicates. Significance is assessed via paired Wilcoxon signed-rank tests at p < 0.05 with Bonferroni correction for the 27 cells × 3 states × 4 metrics = 324 comparisons.

**Harvest tradeoff:** For each (climate, disturbance) combination we compute the difference in total ecosystem carbon between the no-harvest and PERSEUS-harvest scenarios. We report whether the harvested-wood-products carbon gain offsets the standing-biomass carbon loss.

**Disturbance amplification effect:** For each (climate, harvest) combination we compare baseline-disturbance and climate-amplified-disturbance scenarios. The interaction between climate and disturbance amplitude is of particular policy interest.

**Calibration tier sensitivity:** A subset of the factorial (3 climates × 1 harvest × 1 disturbance = 3 cells) is also run under Tier 0 (literature) parameters in addition to the calibrated parameter set. We report the cases where the calibrated and uncalibrated parameter sets give different scenario rankings, and identify the policy-relevant decisions that depend on the calibration choice.

## 2.9 Validation against held-out FIA observations

For the factorial cells whose climate input is the baseline (historical PRISM) and whose duration overlaps the 2001–2022 FIA observation period, we apply the same multi-cycle FIA hindcast validation used in the methods paper to test whether the factorial-cell projections track FIA observations. This is a stronger test than the in-sample validation because the factorial introduces disturbance and harvest extensions that were not active during calibration. If the factorial-cell baseline-baseline-baseline trajectories track FIA observations as well as the calibration-only no-disturbance trajectories did, we have an additional layer of confidence in the factorial's other cells.

## Section 2 open items

1. Some climate datasets (HadGEM3 ssp245 + ssp585 downscaled to per-ecoregion monthly resolution) are not yet generated for GA and WA. ME uses the v6 workbook generator from the methods paper. GA + WA need ~2 days of climate preprocessing.

2. The "current rate" harvest level needs verification against FIA `TRTCD` records aggregated to state-level area-weighted rates. Currently using literature defaults from the cited sources; preferable to re-derive from FIA directly.

3. Replicate seeds chosen pseudo-randomly. Should we sample seeds from a fixed sequence (e.g., the first 5 prime numbers > 40) for permanence and reproducibility? Recommend yes.

4. Cross-state comparison of harvest tradeoff requires standardizing the *current rate* baseline definition. We currently use state-specific rates; should we also report a uniform 2% area / 50% BA scenario across states for the cross-state comparison panel?
