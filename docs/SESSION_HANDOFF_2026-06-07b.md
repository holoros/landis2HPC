# Harmonized session handoff — 2026-06-07b

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-07
**Focus:** multi-resolution FIA estimation framework (mirroring FIA), Cardinal job review, and the spatial-resolution roadmap toward TreeMap.

---

## 1. Jobs currently running on Cardinal

A `cem_conus` array (job 11321543) is active: ~11 tasks RUNNING, more PENDING under JobArrayTaskLimit, 12 h walls. This is the CEM model's CONUS extension, one of the five harmonized models. No LANDIS scenario jobs are running (the WA pilots failed earlier on the IC format issue). The earlier `tm_total_chain` has cleared.

## 2. FIADB on Cardinal: what is and is not there

Full national FIADB is on scratch. `FIA/` holds the `ENTIRE_*` national tables (PLOT, COND, TREE at 13 GB, PLOTGEOM, POP_STRATUM with EXPNS and all ADJ_FACTORs, POP_ESTN_UNIT, POP_EVAL*, REF_SPECIES) plus abbrev-named per-state bundles; `fia_by_state/` holds FIPS-named per-state bundles (the config's `fia_by_state`); `FIA_fresh/` is an FVS/TreeMap pull.

The one table absent everywhere is **`POP_PLOT_STRATUM_ASSGN`** (PLT_CN to STRATUM_CN). It is the link required to attach EXPNS to plots, so it is the only thing standing between us and an estimator that reproduces EVALIDator exactly. `ENTIRE_EVALIDATOR_POP_ESTIMATE.csv` is the EVALIDator SQL dictionary, not estimates. Action: download `POP_PLOT_STRATUM_ASSGN` (per-state or ENTIRE) from the FIA Datamart; that flips the framework into exact-mirror mode.

You also already have FIADB aggregation tooling (`FIA/R/07_aggregateFIADB.R`) that aggregates to state, state-by-county, species, and ecodivision. The new framework below is consistent with that and adds the harmonized carbon attribute and EPA L3 ecoregion.

## 3. Multi-resolution FIA estimator framework (delivered)

`harmonized/fia_domain_estimator.R`. One framework, two modes, three domains.

Modes. `design` reproduces FIA EVALIDator: total over a domain equals the sum over plots of EXPNS(plot) times the per-plot tree attribute expanded by TPA_UNADJ and the stratum ADJ_FACTOR. It is coded and gated on `POP_PLOT_STRATUM_ASSGN`; it errors with guidance until that table is present. `ratio` is the interim transparent estimator (mean attribute per forested acre times domain forest area) that runs on the data in hand.

Domains. `state` (STATECD), `county` (STATECD x COUNTYCD, FIA's focal unit), and `ecoregion` (EPA Level III). Attribute defaults to CARBON_AG (live aboveground carbon) and generalizes to any TREE column. Live trees and forested conditions only.

Validation. State mode reproduces the interim anchor exactly: ME 44.0, WA 90.3 Mg C/ha. County mode produced 51 counties across ME and WA spanning 25 to 152 Mg C/ha (median 58), the expected within-state spread. Tables: `harmonized/fia_agc_county_ratio.csv` (demo, ME+WA), `harmonized/fia_agc_anchor_interim_by_state.csv` (48 states).

Known minor item: in state mode the per-state total uses the HCS forest-area table keyed by abbreviation while the domain key is STATECD, so `agc_TgC_total` comes back NA in that path; the 48-state totals in the interim anchor file are correct. A small STATECD-to-abbreviation map fixes the state-total merge.

## 4. Spatial resolution roadmap (your stated goal)

State: done. County: done for density (Mg C/ha); county totals need a per-county forest-area source (FIA area estimate, or design mode once EXPNS is available). Ecoregion (EPA L3): the framework is ready but needs a plot-to-L3 crosswalk (`PLT_CN, ECO_L3`), built once by intersecting PLOT lat/lon with `Disturbance/us_eco_l3.shp`. That needs `sf`, which is not installed; install it under the gdal/geos/proj modules, generate the crosswalk, then pass `--eco-crosswalk`. The `fia_locator` project has both fuzzed and true plot coordinates if precise placement matters.

Spatially explicit (TreeMap). The endpoint you want. TreeMap imputes an FIA plot ID to every 30 m pixel, so per-pixel values inherit a single plot and are not defensible at pixel resolution. Aggregating TreeMap to the FIA hexagon frame (roughly one plot per ~2,400 ha) restores a defensible support that matches the inventory's actual information content, which is your own argument. Recommended path: keep the design-based FIA estimator as the truth set at state/county/ecoregion, use TreeMap only for spatial allocation within those domains, and report TreeMap maps aggregated to hexes. Prior `fiadb_vs_treemap` comparisons in `FIA/Output` and `ME_AGB_Map_Comparison` are the calibration evidence for that aggregation level.

## 5. Next steps (priority order)

1. Download `POP_PLOT_STRATUM_ASSGN` and switch the estimator to `mode=design`; confirm it reproduces published FIA state carbon within a few percent, then regenerate the anchor as the publication version.
2. Install `sf` on Cardinal, build the `PLT_CN -> ECO_L3` crosswalk from `us_eco_l3.shp`, and produce the ecoregion-level estimates.
3. Add a county forest-area source so county totals (not just densities) are available.
4. Wire the FIA estimator output (state/county/ecoregion per-ha live AGC) in as the year-0 anchor and validation truth set for the harmonized aggregation layer.
5. Define the TreeMap-to-hex aggregation step as the spatial-allocation layer, calibrated against the existing fiadb-vs-treemap comparisons.
6. Continue per SESSION_HANDOFF_2026-06-07 items 1, 2, 4 (aggregation layer, LANDIS harmonized per-plot mode, 48-state rollout).

## 6. Files created or changed this session

Repo: `harmonized/fia_domain_estimator.R`, `harmonized/fia_agc_county_ratio.csv`, `docs/SESSION_HANDOFF_2026-06-07b.md`. Cardinal: `FIA/fia_domain_estimator.R`, `FIA/fia_agc_county_ratio.csv`.
