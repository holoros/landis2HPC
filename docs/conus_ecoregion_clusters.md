# CONUS ecoregion cluster scheme for PERSEUS

**Date:** 2026-05-30
**Purpose:** group EPA Level III ecoregions into ~13 forest clusters so that new states can warmstart their per-species theta from a cluster reference, cutting per-state calibration time from ~5 days to ~2 days.
**Empirical basis:** species-pool overlap analysis across the 8 currently calibrated states (ME, WA, GA, MN, IN, OH; WI and MI inherit the MN baseline).

## Species overlap matrix (current 6 species pools)

| State | n species | Distinctive species | Closest neighbors |
|---|---|---|---|
| ME | 13 | BF, BS, RS, WS (spruce-fir); CE (white cedar) | MN (8 shared) |
| WA | 25 | DF, WH, WC, PSF, GF, NF, SS, ES, AF, LP, PP, PSF, WBP | (only WA so far) |
| GA | 27 | LL, SL, SP (southern pines); BG, LO, WAO (oaks) | IN (5 shared) |
| MN | 24 | JP, RP, TAM (boreal); BO, RO (oaks); AE, BAS (hardwoods) | ME (8 shared), IN (10 shared) |
| IN | 22 | EWP, NRO, SHO, MOK_HK, SHA_HK, YP, WALN, SYC | OH (22 shared, identical) |
| OH | 22 | identical to IN | IN (22 shared) |

**Key empirical finding:** IN and OH have IDENTICAL species pools (22 species, perfect overlap). This validates the cluster concept directly: states sharing eastern deciduous ecoregions can share a single baseline.

**Bridge states:** MN bridges boreal/Lake States (shared with ME via BF/BS/WS/PB/QA) and the eastern hardwoods (shared with IN via AE/BAS/BE/BO/QA/RM/SM/WO/YB).

## Proposed CONUS cluster scheme (13 clusters)

Each cluster has a reference state whose calibration theta serves as the warmstart for new states in the cluster. New states only need literature parameterization for species NOT in the reference (the "extension species").

### Eastern (4 clusters)

**N1 — Northeast Hardwood-Boreal**
- Reference: ME
- Member states: ME (done), NH, VT, upper-NY (Adirondacks)
- EPA L3 ecoregions: 58 (Northeastern Highlands), 59 (Northeastern Coastal Zone), 82 (Acadian Plains)
- Extension species needed for new states: minimal (NH/VT essentially overlap ME)
- Per-state cost: ~2 days

**N2 — Lake States Boreal-Hardwood**
- Reference: MN
- Member states: MN (done), WI (done, baseline shared), MI (done, baseline shared), and lower-MI, NE-IA
- EPA L3 ecoregions: 46, 47, 48, 49, 50, 51, 52 (Lake States series)
- Per-state cost for new additions: ~1 day (baseline already shared)

**N3 — Eastern Hardwood Central**
- Reference: IN
- Member states: IN (done), OH (done, identical pool), KY, TN, MO, southern IL, IA
- EPA L3 ecoregions: 70 (Western Allegheny Plateau), 71 (Interior Plateau), 72 (Interior River Valleys), 54 (Central Corn Belt Plains), 55 (Eastern Corn Belt Plains)
- Per-state cost: ~1.5 days (warm-start from IN/OH theta)

**N4 — Mid-Atlantic**
- Reference: blend (IN hardwoods + ME spruce-fir at high elevation)
- Member states: PA, NY (lowlands), NJ, MD, DE, VA, WV
- EPA L3 ecoregions: 60 (Northern Appalachian Plateau), 64 (Northern Piedmont), 65 (Southeastern Plains), 67 (Ridge and Valley), 69 (Central Appalachians)
- Per-state cost: ~2.5 days (needs IN + ME blend; some new species)

### Southeast (2 clusters)

**S1 — Southeast Coastal Plain**
- Reference: GA
- Member states: GA (done), FL, southern AL, MS, eastern LA, eastern SC, NC coastal
- EPA L3 ecoregions: 75 (Southern Coastal Plain), 65 (Southeastern Plains), 84 (Atlantic Coastal Pine Barrens)
- Per-state cost: ~1.5 days (GA reference applies directly)

**S2 — Appalachian-Piedmont**
- Reference: blend GA + IN
- Member states: NC, SC (upcountry), TN (eastern), KY (eastern), WV, VA (western), AL (northern)
- EPA L3 ecoregions: 66 (Blue Ridge), 68 (Southwestern Appalachians), 45 (Piedmont)
- Per-state cost: ~2.5 days (blend reference)

### Plains (2 clusters)

**P1 — Central Plains**
- Reference: blend MN + IN (with new species: bur oak, eastern redcedar, post oak)
- Member states: KS, NE, OK, eastern CO, eastern NM, TX (east)
- EPA L3 ecoregions: 27 (Central Great Plains), 25 (Western High Plains), 26 (Southwestern Tablelands), 29 (Cross Timbers), 33 (East Central Texas Plains)
- Per-state cost: ~3 days (new arid-oak species)

**P2 — Northern Plains**
- Reference: blend MN + (new: bur oak, eastern redcedar)
- Member states: ND, SD, MT (eastern)
- EPA L3 ecoregions: 42 (Northwestern Glaciated Plains), 43 (Northwestern Great Plains), 17 (Middle Rockies foothills)
- Per-state cost: ~3 days (sparse forest cover; needs threshold tuning)

### Rocky Mountain (3 clusters)

**R1 — Northern Rockies**
- Reference: WA + extension (lodgepole pine, subalpine fir, limber pine, Engelmann spruce, ponderosa pine var.)
- Member states: ID, MT (western), WY
- EPA L3 ecoregions: 15 (Northern Rockies), 16 (Idaho Batholith), 17 (Middle Rockies), 41 (Canadian Rockies)
- Per-state cost: ~2.5 days (WA shares DF, LP, AF, ES, WBP; needs PIPN, PIEN var.)

**R2 — Southern Rockies**
- Reference: blend WA + IN (new: pinyon pine, juniper, aspen)
- Member states: CO, NM, AZ (high), UT
- EPA L3 ecoregions: 19 (Wasatch and Uinta Mountains), 20 (Colorado Plateaus), 21 (Southern Rockies), 23 (Arizona/New Mexico Mountains)
- Per-state cost: ~3.5 days (new pinyon-juniper species; reference WA mountain species)

**R3 — Great Basin**
- Reference: minimal (sparse forest; mostly juniper-pinyon)
- Member states: NV, UT (western), AZ (lowland), CA (eastern)
- EPA L3 ecoregions: 13 (Central Basin and Range), 14 (Mojave Basin and Range), 22 (Arizona/New Mexico Plateau)
- Per-state cost: ~3 days (entirely new species pool; deferred sparse-forest handling)

### Pacific (2 clusters)

**P3 — Pacific Northwest**
- Reference: WA
- Member states: WA (done), OR
- EPA L3 ecoregions: 1 (Coast Range), 2 (Puget Lowland), 3 (Willamette Valley), 4 (Cascades), 9 (Eastern Cascades), 11 (Blue Mountains)
- Per-state cost: ~2 days (OR shares all WA species; adds knobcone pine, port-orford-cedar)

**P4 — Pacific Coast (CA)**
- Reference: WA + significant extension (coast redwood, giant sequoia, blue oak, ponderosa pine var.)
- Member states: CA
- EPA L3 ecoregions: 5 (Sierra Nevada), 6 (Central California Foothills), 7 (Central California Valley), 8 (Southern and Central California Chaparral)
- Per-state cost: ~5 days (CA is the most diverse; many endemic species)

## Cost reduction estimate

Without clustering (each state from scratch): ~5 days per state × 40 new states = 200 days human work.

With clustering (warmstart from cluster reference): ~2.5 days average per state × 40 = 100 days human work. **50 percent reduction.**

Plus the compute savings: warmstarted CMA-ES chains converge ~30 to 40 percent faster (similar to how WI and MI converged faster than MN as v1.2 chains).

## Implementation tasks

1. For each cluster, pick the reference state and freeze its production theta as `cluster_${N}_reference_theta.csv`.
2. For each species in the extension list, source literature ANPP (Mg/ha/yr) and BiomassMax (kg/m^2) from USFS PLANTS database or regional silvics manuals; cap each cluster's extension work at 2 days.
3. The `add_state.sh <FIPS> <NAME> <CLUSTER>` wrapper picks up the cluster reference theta, the extension literature CSV, and a state-specific FIA download, then generates the apply_theta_${ST}, build_plot_scenario_${ST}, plot_to_ecoregion_${ST}, and SppEcoregionData baseline from templates.

## Open questions

- **Should clusters reuse the same `apply_theta_${CLUSTER}_perspecies.py` script across member states?** Pro: less code duplication. Con: makes the per-state matched-n eval slightly harder because the production vector is shared rather than per-state-tuned. Recommendation: per-state theta but cluster-shared apply_theta script (like the MN family does today).
- **Should the cluster reference be the highest-LL state in the cluster or the most-FIA-rich state?** Recommendation: most-FIA-rich, because that calibration sees the largest validation surface and is most reliable as a warmstart.
- **How to handle ecoregions that span clusters?** (e.g., L3 67 "Ridge and Valley" appears in PA, MD, VA, TN). Recommendation: assign each L3 ecoregion to its dominant cluster, then let state-specific calibration adjust the per-ecoregion theta within the matched-n eval framework.
