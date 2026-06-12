# Harmonized session handoff — 2026-06-07d

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-07c
**Focus:** committed to the single TreeMap substrate, built and validated the plot-CN painting layer, and resolved the data/setup blockers.

---

## 1. Architecture decision (locked)

One spatial substrate: TreeMap. Every model is run per FIA plot (output keyed by PLT_CN); TreeMap's plot-to-pixel imputation paints those plot-level results onto the landscape and they aggregate to state, county, ecoregion, and hex. No model is run spatially. FIADB is the statistical truth set and year-0 anchor, not a parallel initialization. This dissolves the LANDIS statewide initial-communities blocker entirely; LANDIS runs per-plot like the others. Full writeup: `docs/treemap_substrate_plan.md` (supersedes `dual_initialization_plan.md`).

## 2. Painting layer (built and validated)

`harmonized/treemap_paint.R`. Joins any per-plot per-ha table (PLT_CN, value_per_ha) to `fvs_stress/plt_area_treemap.csv` (PLT_CN to area_ha, 65,044 plots CONUS) and aggregates to a domain; pixel maps use the TM_ID to PLT_CN donor raster (`me_treemap_donors.csv` pattern). ME validation: painted 2,008 plots to 316 Tg C over 6.9 M ha (45.8 Mg C/ha), forest area matching FIA Maine within tolerance. This is the same mechanism FVS already used (`fvs_treemap_vs_fiadb.csv`), now generalized for all models.

## 3. FIA design anchor (resolved, computing)

All 48 `POP_PLOT_STRATUM_ASSGN` tables are now on Cardinal. Compute nodes cannot reach the Datamart even via the OSC proxy (downloads fail on the node), but the login node has direct internet; the working pattern is parallel foreground `wget` on the login node. The design-based estimator (`harmonized/fia_design_estimate.R`, EVALIDator algorithm, EXPNS times ADJ_FACTOR over the most recent EXPVOL evaluation) is validated: ME 374 Tg C, WA 819, RI 12.8. The 48-state run is SLURM job 11322160, still computing at session end; it writes `FIA/fia_agc_anchor_design_by_state.csv`. Pull that file next session and add a one-state cross-check against published EVALIDator carbon to certify it as the publication anchor.

## 4. Operational lesson for Cardinal

Login-node background processes (nohup, setsid, disown) are reaped when the SSH session closes, so long work stalled twice. Use SLURM for compute. For internet-dependent steps (FIA Datamart, CRAN), run on the login node in the foreground (parallelize and `wait`), because compute nodes lack outbound internet here even with the proxy.

## 5. sf install (deferred, with a workaround)

The `sf`/`terra` install failed on the compute node (no internet for CRAN there) and is heavy for a login-node foreground build. It is deferred. It is not on the critical path: ecoregion aggregation can instead be done by overlaying the EPA L3 raster on the painted surface (terra/GDAL already in the LANDIS container), avoiding a per-plot sf point-in-polygon step. Decide between installing sf on the login node versus the raster-overlay route next session.

## 6. Status of the whole assessment

Shared spine: protocol fixed; HCS harvest table done (48 states); FIA anchor design-based, computing for 48; painting layer built and validated. Models: CEM extending (cem_conus array running); LANDIS calibrated 8 states and now unblocked to run per-plot and paint; FVS already paints by CN; CBM and yield curves are FIA-native and need a thin per-plot per-ha adapter. No model has yet produced the four harmonized scenarios end to end through the painter.

## 7. Next steps (priority order)

1. Pull `fia_agc_anchor_design_by_state.csv` (job 11322160) and cross-check one state vs published EVALIDator; promote to the publication anchor.
2. Build the harmonized aggregation layer over the painter: model by scenario by domain by year, per-ha live AGC, anchor rescale, acceptance gate.
3. Give each model a per-plot per-ha output adapter (LANDIS per-plot first, then FVS, CEM, CBM, yield curves), run the four scenarios at current climate with HCS harvest, and paint.
4. Settle ecoregion: install sf on the login node or use the raster-overlay route; produce state/county/ecoregion anchors.
5. Run the LANDIS pilot end to end (eight calibrated states, four scenarios, painted) as the first full pass through the pipeline.

## 8. Files created or changed this session

Repo: `harmonized/treemap_paint.R`, `docs/treemap_substrate_plan.md`, `docs/SESSION_HANDOFF_2026-06-07d.md`. Cardinal: all 48 `FIA/*_POP_PLOT_STRATUM_ASSGN.csv`; `FIA/submit_anchor.slurm`; `FIA/treemap_paint.R`; design anchor job 11322160 (running) writing `FIA/fia_agc_anchor_design_by_state.csv`.
