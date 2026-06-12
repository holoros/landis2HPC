# Harmonized session handoff — 2026-06-07c

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-07b
**Focus:** design-based FIA estimator that mirrors EVALIDator, plus the FIADB-vs-TreeMap dual-initialization design and consolidated plan.

---

## 1. Jobs on Cardinal

`cem_conus` array (11321543) running: 13 tasks running, 1 pending. CEM CONUS extension in progress. No LANDIS scenario jobs; the two WA pilots (11315259, 11315509) are confirmed FAILED on the initial-communities format blocker.

## 2. Design-based FIA estimator now works (mirrors EVALIDator)

The one missing table, `POP_PLOT_STRATUM_ASSGN`, is downloadable onto Cardinal one state at a time from the FIA Datamart via the normal data path (confirmed RI, ME, WA). With it, the design estimator is implemented and validated: `harmonized/fia_design_estimate.R`.

Method is the EVALIDator algorithm: total = sum over evaluation plots of EXPNS times sum over live trees of CARBON_AG times TPA_UNADJ times ADJ_FACTOR (microplot adj for DIA < 5, subplot adj otherwise), using the most recent EXPVOL evaluation per state. A two-digit-year wrap bug was found and fixed (1995 was sorting above 2022); it now selects the correct recent evaluations.

Validation (`harmonized/fia_design_validate.csv`): ME 374.0 Tg C (EVALID 2024, ~55 Mg C/ha), WA 818.7 Tg C (2022, ~92 Mg C/ha), RI 12.8 Tg C (2024). WA matches the interim anchor within 2 percent; ME is 25 percent higher and RI 73 percent higher than interim, because the interim pooled old inventory cycles and biased low. The design values are authoritative and are the FIADB-arm truth set. Remaining QA: pull all 48 assignment tables, run design for all states, and cross-check one or two against published EVALIDator carbon for a digit-level certification.

## 3. FIADB-vs-TreeMap dual initialization (new design, full writeup in docs/dual_initialization_plan.md)

Run the harmonized assessment twice, FIADB-initialized and TreeMap-initialized, turning the study into a two-factor design: model (5) by initialization (2) by scenario (4), everything else held constant. This decomposes 2100-carbon spread into a model main effect (the apples-to-apples result), an initialization main effect (how much disagreement is about the starting forest rather than dynamics), and their interaction. FIADB is the statistically rigorous, non-spatial pole; TreeMap is the spatially complete, statistically thin pole, and must be aggregated to the FIA hex support (about one plot per 2,400 ha) before initializing any model, per the support argument.

This maps directly onto LANDIS: the per-plot pipeline is the FIADB arm (works), the statewide-raster path is the TreeMap arm (blocked on a Universal-format statewide IC). The dual-init design gives that blocked path a clear scientific purpose.

## 4. LANDIS alignment with the framework

Convert the LANDIS factorial from 3 climate by 4 harvest with flat rates to the four Daigneault scenarios at current climate, harvest from the HCS per-state rate times the scenario multiplier, output rescaled to the FIA year-0 anchor as per-ha live AGC. Climate becomes the separate capability-restricted sensitivity layer. Each scenario runs under both initializations.

## 5. Where things stand

Shared spine mostly built: protocol fixed; HCS harvest table done (48 states); FIA anchor available as interim (48 states) and design-based (validated 3 states, certifiable for 48). Estimation framework spans state (done), county (done, density), ecoregion (needs sf + plot-to-L3 crosswalk; sf not installed). Models: CEM extending now; LANDIS calibrated 8 states, scenarios blocked on the TreeMap-arm IC, per-plot arm proven; CBM, FVS, yield curves need schema confirmation. No model yet run end to end under the harmonized protocol or under both initializations.

## 6. Next steps (priority order)

1. Pull all 48 POP_PLOT_STRATUM_ASSGN, run design estimator CONUS-wide, cross-check vs published EVALIDator; promote to the publication anchor.
2. Install sf on Cardinal, build plot-to-L3 crosswalk from us_eco_l3.shp, produce state/county/ecoregion anchors.
3. Define and validate the TreeMap-to-hex aggregation against existing fiadb-vs-treemap comparisons; this is the TreeMap arm's initialization.
4. Build the harmonized aggregation layer (model x initialization x domain x scenario x year; per-ha live AGC; anchor rescale; acceptance gate).
5. Pilot the two-factor design with LANDIS on the eight calibrated states (FIADB per-plot arm vs hex-aggregated TreeMap arm), four scenarios.
6. Bring CEM, CBM, FVS, yield curves into both arms; settle how to construct a defensible TreeMap initialization for the FIADB-native models.

## 7. Files created or changed this session

Repo: `harmonized/fia_design_estimate.R`, `harmonized/fia_design_validate.csv`, `docs/dual_initialization_plan.md`, `docs/SESSION_HANDOFF_2026-06-07c.md`. Cardinal: `FIA/fia_design_estimate.R`; downloaded `FIA/{RI,ME,WA}_POP_PLOT_STRATUM_ASSGN.csv`; `FIA/fia_design_validate.csv`.
