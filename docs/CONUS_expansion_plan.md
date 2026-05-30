# CONUS PERSEUS expansion plan

**Date:** 2026-05-30
**Author drafted by:** PERSEUS automation pass (Aaron's review needed before commitment)
**Current state:** v1.4. Six states calibrated (ME, WA, GA, MN, WI, MI), two in chain (IN, OH at iter0), 40 to go.
**Target:** All 48 CONUS states under the PERSEUS calibration + scenario matrix shown at `https://holoros.github.io/perseus-forest-intelligence/`.

## What the atlas already supports

The PERSEUS forest intelligence interface uses three dimensions, each parameterized per state:

| Dimension | Levels | Source |
|---|---|---|
| Climate | baseline, SSP245, SSP585 | CMIP6 downscaled to state ecoregions |
| Management | unmanaged, light harvest, moderate, heavy | harvest prescriptions in build_plot_scenario_{ST}.sh |
| Metric | agc_live_total, agc_dead, species_richness, ANPP, etc. | extracted from LANDIS-II tifs |

Per-state scenario suite is 3 climates × 4 managements = 12 simulation conditions. Per state, the suite is roughly 12 × 100 years × ~1500 stratified plots × ~20 minutes per plot = ~600 CPU-hours. Atlas page rendering is downstream of these tif extractions.

CONUS target: 48 states × 12 conditions = 576 state-scenario datasets, each 100-year trajectories of all metrics. Same atlas template, one card per state.

## Strategic choice: state-based vs ecoregion-based calibration

The current architecture calibrates per state (each state gets a unique 50-param per-species ANPP+BMAX theta vector via CMA-ES against state FIA hindcast). For CONUS, this duplicates effort where states share ecoregions and species: a Lake States ecoregion (EPA L3 codes 46 to 52) is currently calibrated three times for MN/WI/MI.

Three viable architectures for CONUS:

**(A) Per-state calibration, as today.** Pros: state-level matched-n eval intact; FIA hindcast per state preserves the bookkeeping. Cons: ~48 chains × 1d 10h = ~70 days serial compute on calibration alone; per-species literature parameterization repeated for shared species; the synthesis pipeline must reconcile 48 slightly different theta vectors for species that span states.

**(B) Per-EPA-L3-ecoregion calibration.** Pros: ~85 ecoregions across CONUS, but only ~25 distinct forest types; one theta per ecoregion; species shared across states share parameters. Cons: requires a refactor of the build_plot_scenario layer to be ecoregion-keyed rather than state-keyed; state-level FIA hindcast becomes a derived quantity, not the calibration target.

**(C) Hybrid: state production theta with ecoregion-shared priors.** Per-state CMA-ES initialized from the regional cluster mean theta (e.g., all Lake States start from the MN/WI/MI mean as warmstart). Preserves state-level matched-n eval. Cuts compute by ~40 percent because chains converge faster from a warm start.

Recommendation: **(C) hybrid.** Lowest risk; preserves the validation framework; reduces compute. The MN-family already operates this way implicitly (WI and MI use the MN SppEcoregionData baseline and were calibrated faster than MN itself).

## Phased rollout

### Phase 0: complete the current expansion (in flight)

Status: IN and OH chains running (Task #7). When they land in ~5 to 7 days, PERSEUS becomes 8 states. WA statewide carbon rerun under v2.0 is also in flight (Task #9, job 11105683).

### Phase 1: Eastern + Midwest infill (3 to 6 months)

Target: 20 states sharing existing pipelines.

| Region | States | Marginal cost per state |
|---|---|---|
| Northeast extension | NH, VT, NY, NJ, PA, MD, DE | low — shares ME spruce-fir + Lake States hardwoods |
| Mid-Atlantic | VA, WV, KY, TN, NC, SC | low to medium — overlaps GA southern pine pool |
| Southeast | AL, MS, AR, LA, MO | medium — needs bottomland hardwood parameters |
| Central | IL, IA | low — Lake States overlap |

Per-state marginal cost (assuming hybrid warmstart):
- 0.5 day FIA download (state FIPS table)
- 0.5 day plot_ics build (run build_plot_ics_MN.py with state SPCD swap)
- 1 day apply_theta and build_plot_scenario adapters
- 1.5 days T2 calibration chain (warmstarted from regional cluster mean)
- 1 day scenario suite (12 conditions × statewide subset)

Total per state ~4.5 days. 20 states serial = 90 days; with 4 concurrent chains = ~25 days wall clock.

### Phase 2: Plains + Mountain (4 to 8 months)

Target: 14 states needing new literature parameterization.

| Region | States | New literature work |
|---|---|---|
| Plains | ND, SD, NE, KS, OK, TX | bur oak, eastern redcedar, ponderosa pine; sparse forest cover handling |
| Northern Rockies | MT, ID, WY | lodgepole pine systems, subalpine fir |
| Southern Rockies | CO, UT, NM, AZ | pinyon pine, juniper, ponderosa pine; arid forest physiology |
| Great Basin | NV | sparse forest; mostly juniper |

Per-state marginal cost ~7 days (extra 2.5 days for literature parameterization). 14 states with 4 concurrent chains = ~25 days wall clock.

### Phase 3: Pacific Coast (2 to 3 months)

Target: 2 states reusing WA species pool with extensions.

| State | Reuse from WA | New species |
|---|---|---|
| OR | DF, WH, WC, PSF, SS, AF, LP, PP | port-orford-cedar, knobcone pine |
| CA | DF, PP | giant sequoia, coast redwood, blue oak, ponderosa pine var. |

Per-state ~5 days. 2 states with 1 concurrent chain = ~10 days wall clock.

### Phase 4: CONUS scenario suite execution (4 to 6 months)

Once all 48 states have production theta, run the full scenario matrix.

| Scenarios per state | Per-state compute | Total CONUS compute |
|---|---|---|
| 12 (3 climate × 4 management) | ~600 CPU-h | ~29,000 CPU-h per pass |

At 150 concurrent array slots: ~8 days per pass, but realistically 30 to 60 days when sharing the OSC queue with other accounts. Three passes (baseline, near-term, long-term ensemble) = ~6 months.

### Phase 5: CONUS atlas + synthesis (2 to 3 months)

Atlas page: 48 state cards replacing 6.

National-scale outputs:
- Year-100 carbon under each climate-management scenario (CONUS map)
- Regional gradient extension: the three-regime finding (West cuts 3x, Lake States 1.5 to 1.7x, NE +32 percent) gets a fourth and fifth regime quantified from CA/OR (likely strong-down extension of WA), Plains (sparse; may need a different baseline), Rockies (likely strong-down at high elevation, scale-up at montane).
- Methods paper updated to CONUS scope; results section adds the national gradient map.
- Scenario paper: CONUS impact of SSP585 + heavy harvest on standing carbon by 2125.

## Total compute estimate

| Phase | Calibration | Scenarios | Storage | Wall clock (concurrent) |
|---|---|---|---|---|
| Phase 1 (Eastern 20) | ~9,000 CPU-h | ~12,000 CPU-h | ~1 TB | ~3 months |
| Phase 2 (Plains+Mountain 14) | ~9,000 CPU-h | ~8,400 CPU-h | ~700 GB | ~2 months |
| Phase 3 (Pacific 2) | ~1,000 CPU-h | ~1,200 CPU-h | ~100 GB | ~1 month |
| Phase 4 (CONUS scenarios) | (done) | ~29,000 CPU-h × 3 passes | ~25 TB peak | ~6 months |
| Phase 5 (synthesis) | n/a | minimal | minimal | ~2 months |
| **Total** | **~19,000 CPU-h** | **~110,000 CPU-h** | **~25 TB peak** | **~14 months from today** |

## Bottlenecks and risks

**Per-state literature parameterization is the gating item.** Compute is plentiful at OSC; what limits us is the human-curated species ANPP and BMAX defaults from forestry literature (yield tables, USFS PLANTS database, regional silvics manuals). Hybrid architecture (C) cuts this cost by ~40 percent through ecoregion sharing.

**Storage at peak (Phase 4)** approaches 25 TB across the OSC scratch fileset. The build-fresh runner already deletes per-plot output tifs after biomass extraction; the same pattern needs to be enforced for the CONUS scenario sweep. Plan for a rolling-window storage strategy: complete 8 to 10 states at a time, archive trajectory tables, then delete intermediate tifs.

**Queue contention with other OSC accounts.** Current queue gates (100 jobs concurrent) and the QOSMaxSubmitJobPerUserLimit problem hit us in v1.3. The flock serializer added in v1.3 and the SLURM batch wrapper added in v1.4.1 handle this; for CONUS we may need OSC priority allocation discussion.

**FIA temporal coverage** varies by state. Eastern states have rich multi-cycle FIA; some western states have sparse coverage. The matched-n harvester floor (n >= max(300, 0.85*max_n)) may be too tight for low-coverage states; a state-specific minimum n threshold may be needed.

**Validation at scale.** The current per-state matched-n eval works because each state has thousands of FIA plots. CONUS-scale validation needs a held-out evaluation set spanning multiple regions. Forest Vegetation Simulator (FVS) outputs at FIA plots could serve as an independent benchmark; consensus with FIA biomass equations is the integrity check.

## Suggested immediate next steps (next 3 months)

1. **Finish current expansion.** Harvest IN and OH chains when they land (Task #7). Promote any v2.0 vectors. Land WA statewide v1.4.1.
2. **Build the state-adder tool.** A wrapper `perseus/tools/add_state.sh <FIPS> <NAME> <CLUSTER>` that downloads FIA tables, builds plot_to_ecoregion, drops in apply_theta from the ecoregion cluster template, builds plot_ics, and submits T2 v1 chain. Reduces per-state setup from 4.5 days to 1 day.
3. **Define ecoregion clusters.** Group EPA L3 ecoregions into ~6 clusters: Northeast hardwood, Lake States, Appalachian, Southeast pine, Mid-Atlantic, Plains, Rocky Mountain, Pacific Coast, Pacific Northwest, Subboreal. Each cluster gets a baseline theta from the existing 8-state set; new states warmstart from their cluster.
4. **Pilot Phase 1 with 3 states.** Add NH, VT, NY (Northeast extension reusing ME's spruce-fir + GA's hardwood overlap). Validate the warmstart approach and the add_state.sh tool. Time-box to 4 weeks.
5. **Update the readiness matrix.** Add the 40 remaining states with their cluster assignments and per-state cost estimates. Move IN and OH from "in flight" to "landed" when chains complete.

## What to defer until v2.0

- The bivariate choropleth (climate × management interaction maps) at the CONUS atlas page.
- Harvest scheduling at the sub-state (stand) scale.
- Disturbance extensions (wildfire, insect outbreak) — currently disabled; CONUS-scale enabling needs another calibration pass.
- Real-time stand-level dashboards (the GUI's map-click feature works at 1500 stratified plots per state; CONUS-wide click-to-run needs different backend architecture).

## Tracking

CONUS expansion would be a v2.0 or later release. Major version bump signals the architecture change from "research framework" to "national-scale operational tool." The current v1.x is the research framework; v2.0 is the CONUS operational tool.

Recommend creating a v2.0 milestone in the GitHub issue tracker with the Phase 1-5 items as separate issues, gated on Phase 0 completion (IN + OH + WA v1.4.1).
