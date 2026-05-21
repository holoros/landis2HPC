# PERSEUS Forest Intelligence: GUI architecture and roadmap

**Date:** 2026-05-21
**Status:** v1 frontend prototype shipped (`perseus/dashboard/perseus_forest_intelligence_v1.html`)
**Goal:** a slick, browser based interface for the PERSEUS / LANDIS-II framework that lets a user build scenarios, inspect calibration, and view statewide carbon projections, with the map plus growth curve experience modeled on the CTrees Forest Intelligence platform.

## What the user wants

A single product that covers three jobs that today live in scattered scripts, figures, and SLURM logs:

1. **Build scenarios.** Pick a state, a climate pathway, a harvest regime, and disturbance settings, then run a projection.
2. **Do calibration.** See how each state was calibrated (tier, parameters, likelihood, per species multipliers) and monitor chains that are still running.
3. **Complete projections at statewide level.** Turn the calibrated parameters into wall to wall biomass and carbon trajectories that can be mapped and summarized.

The visual reference is the CTrees Forest Intelligence detail view: an interactive map with switchable layers, a detail panel of growth curves over time, a layer switcher, and a time control. PERSEUS adds two research specific surfaces on top of that pattern: a scenario builder and a calibration monitor.

## The three surfaces

| Surface | Question it answers | Core visuals |
|---|---|---|
| Scenario builder | What future am I simulating? | climate / harvest / disturbance controls, year slider, run action |
| Calibration monitor | How good is the model here, and how was it fit? | tier and likelihood cards, per species multiplier bars, predicted vs observed, chain progress |
| Projection viewer | What does the calibrated forest do over 100 years? | map layers (observed, projected, net change), statewide growth curves, per plot growth curve |

## v1 (shipped now): self contained frontend

`perseus_forest_intelligence_v1.html` is a single file that opens in any browser with no server. It carries an embedded sample of 170 real FIA plot coordinates per state (six states) plus the real production calibration metrics, and renders:

- a dark basemap map (Leaflet) with plots colored by observed biomass, projected biomass at year T, or net change;
- the signature growth curves panel built with Chart.js, showing statewide median biomass under the three climate pathways for the chosen harvest, with the literature Tier 0 line for contrast, and a per plot trajectory when a plot is clicked;
- a calibration card per state (tier, per plot log likelihood, paired sample size, and the Maine per species ANPP multipliers).

What is real in v1: plot coordinates, first cycle observed biomass, calibration tier, per plot log likelihood, paired sample size, year-100 medians for the production states, and the Maine multiplier vector. What is illustrative in v1: the climate and harvest responses, which are simple envelopes (climate scales the asymptote by roughly 6 to 11 percent, harvest reduces standing biomass by 14 to 44 percent) standing in for the 27 cell factorial sweep that has not yet been run. The growth model is a Chapman-Richards form anchored on each plot's observed biomass and the calibrated state asymptote, so scenario and calibration choices visibly propagate to the curves.

v1 is hostable as is on GitHub Pages from the repo, which gives a shareable link with no infrastructure.

## Tech stack and phased build

### Phase 1, frontend prototype (done)
Static single page app, Leaflet for the map, Chart.js for curves, data embedded or read from precomputed JSON bundles next to the page. No backend, no auth, no live runs.

### Phase 2, real precomputed data wiring (in progress, no new infrastructure)
Replace the modeled trajectories with the real per plot trajectories already produced on Cardinal. As of 2026-05-21 Washington is wired to its real per plot Tier 0 and Tier 1 trajectories from `WA.json` (biomass at years 0, 25, 50, 75, 100); the statewide growth curve is the median of those real per plot curves, and a data source label marks the difference. Georgia, Maine, Minnesota, Wisconsin, and Michigan still use the modeled fallback (Chapman-Richards anchored on observed biomass and the calibrated asymptote) because their per plot trajectories are not yet exported into the atlas JSON. Closing this means writing per plot trajectories for the remaining production states and, once the chains land and the factorial sweep runs, replacing the climate by harvest envelopes with real cells. Still a static site, just backed by richer JSON.

### Phase 3, live runs through a backend (the real product)
A thin API service (FastAPI is the natural choice) that sits between the GUI and Cardinal. The GUI posts a scenario config; the service translates it into the existing pipeline (`build_plot_scenario_{ST}.sh`, `cma_es_optimize_{ST}.py`, the factorial scenario builder), submits the SLURM jobs, polls `squeue`, and writes results to a store. The GUI polls a job id and renders results when ready. Hosting options are an OSC OnDemand interactive app, a UMaine or CRSF virtual machine with key based SSH to Cardinal, or a small container. Authentication rides on OSC accounts. This is what turns the calibration monitor from a read only view into a launch button, and the scenario builder from a what if envelope into an actual run.

### Phase 4, statewide raster projections
Precompute wall to wall projection rasters per scenario cell as cloud optimized GeoTIFF or PMTiles, served as map tiles so the map shows continuous biomass and carbon rather than plot points. Growth curves for any drawn area come from zonal statistics over the rasters. This is the step that delivers true statewide carbon accounting and the closest match to the CTrees supply shed experience.

### Phase 5, multi user and publishing
Saved scenarios, shareable links, side by side scenario comparison, export to report, and a public read only mode for outreach and funders.

## Data flow (phase 3 target)

GUI scenario config -> API validates and maps to pipeline arguments -> SLURM submission on Cardinal -> per plot LANDIS runs and aggregation -> results store (parquet for tables, COG or PMTiles for maps) -> API serves results -> GUI renders map layers, growth curves, and calibration metrics.

## How this maps to CTrees Forest Intelligence

CTrees gives us the interaction grammar: a map with a layer switcher, a detail panel of growth curves, and a time control over an area of interest. PERSEUS keeps that grammar and adds the modeling layer underneath. Where CTrees shows observed and remotely sensed carbon, PERSEUS shows calibrated process model projections under user chosen futures, plus the calibration provenance for every number on screen. The growth curve is the shared signature visual; the scenario builder and calibration monitor are what make this a forest modeling tool rather than a monitoring dashboard.

## Honest limitations to close before this is decision grade

The climate and harvest responses are envelopes until the factorial sweep runs. Statewide totals need area weighting and an expansion from the FIA plot sample to the full landscape, which is the phase 4 raster step. Live runs need the phase 3 backend; the current page cannot submit jobs. Three of the six states (MN, WI, MI) are still calibrating, so their numbers are provisional.

## Immediate next steps

Wire the real atlas JSON per plot trajectories into v1 (phase 2, no infrastructure). Stand up a minimal FastAPI service that can submit one scenario to Cardinal and return its trajectory, as the phase 3 seed. Decide hosting: GitHub Pages for the static prototype now, OSC OnDemand or a CRSF VM for the live version later.
