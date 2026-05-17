# PERSEUS LANDIS-II GUI — Scoping Memo v1

**Date:** 2026-05-16
**Status:** Pre-build scoping. Decide audience, scope, and tech stack before committing to a build.

## Why now

The PERSEUS calibration framework is publication-ready. A reproducible code base + 5 validated disturbance agents + scenario explorer prototype demonstrate that the *research* layer works. The next question is whether to extend this into a tool that broadens who can use LANDIS-II calibrated projections — and if so, what form that takes.

The honest case for building: state forestry agencies and CRSF stakeholders need state-scale forest carbon projections under climate × harvest × disturbance scenarios. Currently the only people who can produce these are research labs with LANDIS-II expertise and HPC access. A GUI could shift that distribution substantially.

The honest case against building: a GUI without a clear user is software theater. The PERSEUS pipeline already produces outputs that policy analysts can read. Building a GUI before knowing exactly what decisions it will support is the path to a 6-month project with 5 users.

## Audience decision (drives everything else)

Three plausible target users, each implying a fundamentally different product:

### Option A: Research-grade GUI for LANDIS-II practitioners

**Who:** Scientists at universities and research stations who currently build LANDIS scenarios by hand-editing text files.

**Pain point:** Constructing a scenario directory is fiddly and error-prone (witness the WA single-cell scenario debug we did this week). Reviewing scenario differences across factorial cells is hard without custom code.

**Product:** Scenario authoring tool — visual scenario builder, parameter editor with validation, output viewer for comparing multi-cell factorials, integration with HPC submission.

**Scope:** ~3-4 months for a usable v1.

**Distinguishing feature:** Reduces the "fiddly text-file editing" pain. Doesn't change the analysis itself.

### Option B: Decision-support GUI for state forestry agencies

**Who:** Forest analysts at state agencies (Maine BPS, GA DNR, WA DNR) who want to read calibrated PERSEUS projections and answer "what's the state's carbon trajectory under SSP585 with current harvest policy?"

**Pain point:** They cannot run LANDIS themselves and don't have time to interpret scientific outputs. They need a clean dashboard with state aggregates, simple scenario comparisons, and confidence intervals.

**Product:** Read-only browser dashboard fed by pre-computed PERSEUS results. Map view of plot-level biomass, state-aggregate trajectories under each scenario, side-by-side scenario comparisons, downloadable summary reports.

**Scope:** ~6-8 weeks for v1; could be substantially built atop the existing scenario explorer prototype.

**Distinguishing feature:** No simulation runtime — fast, no compute requirements, runs in a browser.

### Option C: Land manager / extension tool for individual forest managers

**Who:** State foresters, extension agents, large private landowners who want to compare their stand against state-scale projections.

**Pain point:** They want "is my stand growing as expected? What if I harvest 50%?" — concrete management questions tied to specific stands.

**Product:** Upload-your-FIA-equivalent-plot interface, automated calibrated LANDIS projection (using PERSEUS state parameters), comparative reports against state averages, simple climate scenario toggles.

**Scope:** ~6-9 months. Substantially more complex because it runs LANDIS per-user.

**Distinguishing feature:** Per-user simulation = high compute cost, account management, data privacy.

## Recommended path: Option B first, evolve to A or C later

**Why B over A:** The audience is bigger, the impact is more direct (state forestry agencies are CRSF stakeholders), and the build is faster (read-only is much simpler than authoring). It also positions PERSEUS as a state-scale carbon analytics platform, which fits Aaron's CRSF strategic priorities.

**Why not C:** Multi-tenant LANDIS-II is a major infrastructure project; deferring until B has demonstrated user demand is the safer play.

**Why not A:** Research labs are already building LANDIS scenarios; "easier scenario authoring" isn't the bottleneck for them. Their bottleneck is calibration (which PERSEUS solves) and HPC scaling (which doesn't need a GUI).

## Option B technical scope: PERSEUS Carbon Atlas

### Core capabilities

1. **State selector** — Maine / Georgia / Washington (extensible to other states with FIA coverage)

2. **Map view** — interactive plot-level biomass map. Toggle layers:
   - FIA Round 1 observed biomass (baseline)
   - LANDIS Tier 0 (literature) projection at year 50, 100
   - LANDIS calibrated (Tier 1 or 2) projection at year 50, 100
   - Per-ecoregion calibration confidence (from leave-one-eco-out CV)

3. **Trajectory view** — state-aggregate biomass over time, with confidence bands. Scenario filter: climate (baseline / SSP245 / SSP585) × harvest (none / current rate / PERSEUS reference) × disturbance (none / baseline / climate-amplified).

4. **Scenario comparison** — side-by-side year-100 biomass + carbon stocks under different scenario combinations. Tabular and graphical.

5. **Plot-level drill-down** — click a plot on the map, see its observed FIA cycles, calibrated trajectory, and per-species composition over time.

6. **Calibration provenance** — clickthrough from a number to the underlying calibration tier (T0/T1/T2), parameter values, and validation diagnostic.

7. **Download** — PDF report per state, CSV of per-plot projections, citation snippet.

### Out of scope for v1

- Per-user LANDIS runs (deferred to Option C)
- Adjustable calibration parameters in the GUI (read-only; calibration is the science layer's job)
- Real-time data refresh (precomputed snapshots, refreshed quarterly)
- Multi-state federated analysis (one state at a time)
- Login / accounts (anonymous read access)

### Technical stack recommendation

| Layer | Recommendation | Justification |
|---|---|---|
| Frontend | React + Plotly / D3 | Industry standard; large ecosystem; can embed maps via Leaflet/Mapbox |
| Backend API | FastAPI (Python) | Lightweight, fast to develop, good for serving pre-computed data |
| Data storage | PostgreSQL + PostGIS | Mature, supports spatial queries for the map view |
| Map tiles | Mapbox or self-hosted MapLibre | Mapbox for speed; self-hosted for cost control after scale |
| Hosting | UMaine RCDS or AWS | RCDS for institutional alignment; AWS for scale + reliability |
| CI/CD | GitHub Actions | Free for public repos |

### MVP build sequence (6-8 weeks)

**Week 1-2:** Data pipeline — convert per-plot calibrated results into a structured PostgreSQL schema, build seed loading scripts. Get the existing scenario explorer prototype connected to this DB.

**Week 3-4:** Map view — Leaflet-based interactive map with plot markers colored by biomass, toggleable layers for Tier 0 vs calibrated projections. Test on Maine first (smallest dataset).

**Week 5:** Scenario comparison view — side-by-side year-100 carbon stocks across scenario combinations. Use the factorial scenario data when it arrives.

**Week 6:** Plot drill-down — clicking a plot opens a panel with FIA observed cycles, LANDIS predicted trajectory, per-species composition.

**Week 7:** Download + report generation — PDF/CSV exports, citation snippet.

**Week 8:** UAT with one state agency contact (Maine BPS?), iterate based on feedback.

### Resource budget

- 1 full-time developer for 6-8 weeks (estimated)
- Or: 2 part-time developers for 12-16 weeks
- Cloud hosting: ~$50-100/month for v1 (data is small)
- Mapbox if used: ~$0-100/month at MVP traffic
- Domain + SSL: ~$30/year

Estimated cost: $15,000-25,000 in developer time + ~$1,000/year operating. CRSF could likely absorb this from existing developer time or contract a Maine-based freelancer.

## Risks

1. **Scope creep**: Once Option B exists, agencies will request features that drift toward Option A or C. Pre-decide: v1 is read-only, period. v2 strategic decision after measuring use.

2. **Calibration parameter staleness**: PERSEUS results are anchored to FIA 2001-2022 cycle. As new FIA cycles arrive (2024-2027), the calibrated parameters need refresh. Build a "Last calibrated: YYYY-MM" disclosure into every view.

3. **State agency politics**: Aaron's CRSF stakeholders may have agency preferences (which state to prioritize, which scenarios to highlight). Worth a stakeholder conversation before final scoping.

4. **Comparison-to-existing-tools**: How does this differ from USDA FS Forest Carbon Reporting Framework (FCRF)? Need a one-page positioning document. Plausibly: PERSEUS is calibrated to FIA cycles directly (FCRF uses different inputs); PERSEUS supports user-defined scenarios (FCRF is fixed national-scale); PERSEUS is per-state high-resolution (FCRF is regional summaries).

## Immediate next steps (if pursuing Option B)

This week:

1. **Stakeholder check-in (2-3 hours)**: Aaron + 1-2 state agency contacts. Validate the audience hypothesis: would they actually use this? What features matter most?

2. **Compete analysis (4 hours)**: Look at existing forest-carbon-projection tools (USFS FCRF, NRT regional carbon projections, climate adaptation portals). Position PERSEUS Carbon Atlas relative to them.

3. **Sketch wireframes (6 hours)**: Three sketches (map view, trajectory view, scenario comparison) with realistic data. Test on internal CRSF audience before commissioning development.

Next two weeks:

4. **Decide whether to build (1 hour)**: Based on stakeholder + competitive analysis, decide go/no-go. If go, set MVP scope + budget.

5. **If go**: assemble the developer resource (in-house vs contract), start Week 1-2 data pipeline.

## What the existing prototype gives us

The HTML scenario explorer (`perseus_scenario_explorer.html`) ships ~70% of the look-and-feel for Option B's trajectory view + ladder comparison. It's a working preview of what a finished Option B dashboard would look like at one state. Use it as the artifact for stakeholder conversations, not as the actual production codebase.

The prototype demonstrates: data binding from CSV → interactive chart, scenario selectors, cross-state table. What it doesn't demonstrate: map view (Leaflet), backend API, scenario factorial slicing, plot-level drill-down. Those are the new builds in the 6-8 week MVP plan.

## Decision recommended this week

Pick one of:

- **A: Build Option B "PERSEUS Carbon Atlas"** — 6-8 weeks, ~$15-25k effort, high stakeholder leverage
- **B: Stakeholder conversations first** — talk to 2-3 state agency contacts before committing to build
- **C: Wait until methods paper is out** — defer GUI decision until publication establishes the science layer's credibility
- **D: Build a smaller v0 — extend the HTML prototype with backend data, 1-2 weeks** — minimal MVP to validate the Option B hypothesis

Recommendation: **C followed by D**. Methods paper publishes; then build a 1-2 week extended prototype tied to the paper's data; use it as the conversation-starter with stakeholders; then make the full-MVP decision.

## Notes for next session

The GUI work is genuinely deferrable. The methods paper publication is the gating event for any serious downstream tool work. Once the paper is in (or accepted), the GUI conversation becomes much more concrete:

- "Here's the framework, here are the results, here's what a tool that surfaces these would look like — would you use it?"

That conversation works dramatically better than starting with "I think we should build a GUI for LANDIS-II."

Until then, the existing scenario explorer prototype is an excellent stakeholder-conversation artifact. Carry it around.
