# PERSEUS multi-state readiness matrix

**Date:** 2026-05-21 (all six chains landed: ME/GA/WA/MN/WI/MI)
**Purpose:** definitive accounting of which states can enter the PERSEUS calibration framework, what each has, and what each still needs.

## Current live status (2026-05-21)

All six chains have **completed** (8 iterations, 112 candidates each) and are harvested by `perseus/tools/harvest_t2_chains.py --all`:

| State | Chain | Job | Status |
|---|---|---|---|
| GA | ga_t2_v2 | 10021254 | **LANDED** — production iter5_cand8, per-plot LL −0.8871 over n=1255 |
| MN | mn_t2_v1 | 10124727 | **LANDED** — production iter7_cand0, per-plot LL −0.9325 over n=2741 |
| WI | wi_t2_v1 | 10126909 | **LANDED** — production iter2_cand11, per-plot LL −0.6470 over n=916 |
| MI | mi_t2_v1 | 10126910 | **LANDED** — production iter7_cand5, per-plot LL −0.1292 over n=562 |

GA selection note: the raw CMA-ES min negLL (iter5_cand10, −367) was a **settling-check timeout artifact** — that candidate ran on only 240/779 plots (n=398). The defensible production vector is iter5_cand8 (n=1255, ~92% of max), chosen by per-plot LL among near-full-n candidates. A matched-n evaluation now confirms Tier 2 (per-plot LL −0.8871) beats the Tier 1 θ=0.30 vector (−0.9603 over n≈1280), so GA's production tier is Tier 2. All six states are Tier 2 production.

When all land, PERSEUS spans **6 states (ME, GA, WA, MN, WI, MI)**. The EPA L3 ecoregion shapefile (`/users/PUOM0008/crsfaaron/Disturbance/us_eco_l3.shp`) unlocked MI/WI; they calibrate on ecoregions shared with MN (46–52), reusing MN species/climate/SppEcoregionData with zero new literature parameterization.

### Landing workflow (when a chain completes)

```bash
cd /fs/scratch/PUOM0008/crsfaaron/landis2/tools
python3 harvest_t2_chains.py --all      # writes theta_best_production.csv per chain
```
The harvester (v1.1, n-aware) parses the true paired-observation count and signed LL from each candidate's `launch.log` (`n=NNN ... LL=...`), requires **n ≥ max(300, 0.85 × max_n)** (near-full settling), and selects the **highest per-plot LL** among those. This supersedes the earlier cma_history.csv fallback, which trusted the settling check to guarantee comparable n and so could mis-select a settling-timeout artifact (the GA iter5_cand10 case). It defends the sample-size degeneracy mode against re-entry through a timed-out settling check.

## Two independent prerequisites

A state needs BOTH of the following before it can be calibrated:

- **(A) LANDIS-II inputs** — `states/{ST}/inputs/`: species.txt + SpeciesData.csv, an EPA L3 ecoregion GeoTIFF, SppEcoregionData.csv (literature Tier 0 ANPPmax/BiomassMax), and processed climate (PRISM/HadGEM). Plus a state initial-communities.tif for scenario work.
- **(B) Multi-cycle FIA tables** — full PLOT + COND + TREE (with DRYBIO_AG) in `/fs/scratch/PUOM0008/crsfaaron/FIA/`. Required to build `untreated_plots_{ST}.csv` and per-plot ICs for the hindcast.

## State-by-state status

| State | (A) LANDIS inputs | (B) FIA tables | Calibration status | Gap to calibrate |
|---|---|---|---|---|
| **ME** | yes | (from earlier pipeline) | **T2 production (v1.0)** | none — done |
| **GA** | yes | yes | **T2 production (v1.2; iter5_cand8, per-plot LL −0.8871)** | none — T2 confirmed > T1 (matched-n: −0.8871 vs −0.9603) |
| **WA** | yes | yes | **T2 production (v1.0)** | none — done |
| **MN** | yes | yes | **T2 LANDED (v1.2; iter7_cand0, per-plot LL −0.9325, n=2741)** | none — harvested |
| **WI** | reuses MN (shared eco) | yes | **T2 LANDED (v1.2; iter2_cand11, per-plot LL −0.6470, n=916)** | none — harvested; southern eco 53/54 deferred |
| **MI** | reuses MN (shared eco) | yes | **T2 LANDED (v1.2; iter7_cand5, per-plot LL −0.1292, n=562)** | none — harvested; southern eco 55/56/57 deferred |
| **IN** | yes (no IC raster) | **no** | not started | build IC raster + download IN FIA (state 18) |
| **OH** | yes (no IC raster) | **no** | not started | build IC raster + download OH FIA (state 39) |

FIA folder states present: AL, FL, GA, IA, ID, MI, MN, NC, OR, SC, TN, WA, WI.
LANDIS state dirs present: GA, IN, ME, MN, OH, WA (+ MI, WI now reuse MN inputs on shared ecoregions).
**Six states (ME, GA, WA, MN, WI, MI) are now calibrating or done; IN/OH remain blocked on FIA downloads.**

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

1. **GA T2 v2** — LANDED (v1.1, job 10021254). Production vector archived; matched-n T1-vs-T2 evaluation pending to set GA's production tier.
2. **MN, WI, MI** — running at iter1 (jobs 10124727, 10126909, 10126910). Harvest with the n-aware `harvest_t2_chains.py --all` on completion (~12-15h ETA), then build the six-state production table + heatmap.
3. **IN, OH** — download their FIA tables (states 18, 39) to the FIA folder; build IC rasters; then run the MN pipeline. Ecoregion dependency already solved.
4. **MI, WI southern ecoregions (53-57)** — need state-specific literature parameters beyond the MN-shared 46-52 set.

A 5–6 state PERSEUS framework (ME, GA, WA, MN + IN/OH) is achievable with only FIA downloads. An 8-state framework adding MI/WI requires the ecoregion-raster generation step.

## Single external action that unblocks the most states

Downloading four FIA state bundles (IN=18, OH=39 — and MI=26, WI=55 are already present) plus sourcing the EPA Level III ecoregions vector would unblock IN, OH immediately and MI, WI after input generation. The EPA ecoregions vector is the single highest-leverage missing GIS asset for the eastern/midwestern expansion.
