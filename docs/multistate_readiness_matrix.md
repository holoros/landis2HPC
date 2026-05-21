# PERSEUS multi-state readiness matrix

**Date:** 2026-05-20
**Purpose:** definitive accounting of which states can enter the PERSEUS calibration framework, what each has, and what each still needs.

## Two independent prerequisites

A state needs BOTH of the following before it can be calibrated:

- **(A) LANDIS-II inputs** — `states/{ST}/inputs/`: species.txt + SpeciesData.csv, an EPA L3 ecoregion GeoTIFF, SppEcoregionData.csv (literature Tier 0 ANPPmax/BiomassMax), and processed climate (PRISM/HadGEM). Plus a state initial-communities.tif for scenario work.
- **(B) Multi-cycle FIA tables** — full PLOT + COND + TREE (with DRYBIO_AG) in `/fs/scratch/PUOM0008/crsfaaron/FIA/`. Required to build `untreated_plots_{ST}.csv` and per-plot ICs for the hindcast.

## State-by-state status

| State | (A) LANDIS inputs | (B) FIA tables | Calibration status | Gap to calibrate |
|---|---|---|---|---|
| **ME** | yes | (from earlier pipeline) | **T2 production (v1.0)** | none — done |
| **GA** | yes | yes | **T1 v1.0 / T2 v2 finishing** | T2 v2 chain landing now |
| **WA** | yes | yes | **T2 production (v1.0)** | none — done |
| **MN** | yes | yes | **T2 chain launched (job 10124727)** | none — running now |
| **IN** | yes (no IC raster) | **no** | not started | build IC raster + download IN FIA (state 18) |
| **OH** | yes (no IC raster) | **no** | not started | build IC raster + download OH FIA (state 39) |
| **MI** | **no** | yes | not started | generate full LANDIS inputs (ecoregion raster, species params, climate) |
| **WI** | **no** | yes | not started | generate full LANDIS inputs (ecoregion raster, species params, climate) |

FIA folder states present: AL, FL, GA, IA, ID, MI, MN, NC, OR, SC, TN, WA, WI.
LANDIS state dirs present: GA, IN, ME, MN, OH, WA.
**Only MN, GA, WA (and ME from the earlier pipeline) satisfy both prerequisites today.**

## What MI + WI specifically need (the requested states)

MI and WI have complete multi-cycle FIA tables in the FIA folder but no `states/{MI,WI}/` LANDIS setup. To calibrate either, we must first generate the LANDIS inputs:

1. **EPA L3 ecoregion GeoTIFF** clipped to the state. Requires the national EPA Level III ecoregions vector (not currently on Cardinal) rasterized to the LANDIS grid. This is the hard dependency — without it, plots can't be assigned to ecoregions, climate can't be stratified, and SppEcoregionData can't be keyed.
   - *Shortcut worth testing:* MI and WI share most of their EPA L3 ecoregions with MN (50 Northern Lakes & Forests, 51 North Central Hardwood Forests, 47 Western Corn Belt Plains, 48 Lake Agassiz Plain edge). If the national ecoregion vector is obtained, the MN SppEcoregionData literature parameters are a defensible Tier 0 for the shared ecoregions because the species pool and productivity regime are nearly identical.

2. **SpeciesData.csv + species.txt.** MI/WI share ~22 of MN's 24 species (BF, TAM, WS, BS, RS, JP, RP, WP, CE, HE, RM, SM, YB, PB, BE, WAS, BAS, QA, BA, WO, RO, BO, BSW, AE). MN's parameters transplant cleanly; add black/scarlet oak and a couple of central-hardwood species for the southern WI/MI counties.

3. **Climate.** PRISM baseline + HadGEM SSP scenarios processed to per-ecoregion monthly tmin/tmax/precip, same pipeline that produced MN's climate files.

4. Then the MN pipeline applies unchanged: `build_plot_list.py` → `build_plot_ics_MN.py` (swap SPCD map) → `build_plot_to_ecoregion.py` → `build_plot_scenario_MN.sh` (swap state) → `cma_es_optimize_MN.py` (swap species) → `run_param_set_MN_t2.sh`.

**Estimated effort for MI or WI:** ~1 day each once the EPA L3 ecoregion raster is in hand. The blocking item is the ecoregion vector/raster, which needs to be sourced (EPA publishes it publicly; it would need to be downloaded outside the web-restricted tools and placed on Cardinal).

## What IN + OH need

IN and OH already have LANDIS inputs (species, ecoregion raster, climate, SppEcoregionData) but are missing: (a) the state initial-communities.tif, and (b) their FIA tables in the FIA folder (download state 18 / state 39). Once their FIA tables are downloaded, the MN pipeline applies directly — and they're actually closer than MI/WI because the hard ecoregion-raster dependency is already solved.

## Recommended priority order

1. **MN** — running now (job 10124727). First non-original-three calibration.
2. **GA T2 v2** — landing now (job 10021254). Upgrades GA from T1 to T2 in v1.x.
3. **IN, OH** — download their FIA tables (states 18, 39) to the FIA folder; build IC rasters; then run the MN pipeline. Ecoregion dependency already solved.
4. **MI, WI** — source the EPA L3 ecoregion vector, generate LANDIS inputs (reusing MN species params for shared ecoregions), then run the MN pipeline.

A 5–6 state PERSEUS framework (ME, GA, WA, MN + IN/OH) is achievable with only FIA downloads. An 8-state framework adding MI/WI requires the ecoregion-raster generation step.

## Single external action that unblocks the most states

Downloading four FIA state bundles (IN=18, OH=39 — and MI=26, WI=55 are already present) plus sourcing the EPA Level III ecoregions vector would unblock IN, OH immediately and MI, WI after input generation. The EPA ecoregions vector is the single highest-leverage missing GIS asset for the eastern/midwestern expansion.
