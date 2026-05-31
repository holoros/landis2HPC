# PERSEUS session handoff (2026-05-31, part 2 — N3 unblocked + IN chain launched)

**Repo:** github.com/holoros/landis2HPC, branch main, in sync with origin
**Builds on:** `SESSION_HANDOFF_2026-05-31.md` (operational review) and the v1.5 ship
(hybrid warmstart infra + optimizer/monitor hardening).

## One paragraph summary

The N3 (Eastern Hardwood Central: IN, OH) initial-communities gap — the root cause of the
2026-05-29 IN/OH chain death — is closed. A data-derived FIA SPCD→LANDIS species map was
built from the live-tree histograms of IN_TREE.csv and OH_TREE.csv, IC rasters were
generated for the full untreated-plot universe, a single-plot LANDIS smoke test passed
end to end, and the warmstarted IN Tier 2 chain (`in_t2_v2`) is now running on Cardinal,
seeded from the MN-bootstrapped cluster N3 reference. OH is prepared identically but is
holding for its own one-plot smoke test before launch.

## What was done

### FIADB review → N3 SPCD map
No REF_SPECIES table exists on the cluster, so the map was derived empirically. The live
(STATUSCD==1) SPCD histograms of `~/fia_data/IN_TREE.csv` and `OH_TREE.csv` were tabulated;
the 23 modeled N3 species map 1:1 to their canonical FIA codes (e.g., sugar maple 318→SM,
yellow-poplar 621→YP, white oak 802→WO, white ash 541→WAS, shagbark hickory 407→SHA_HK,
mockernut 409→MOK_HK, post oak 835→POST, shingle oak 817→SHO, sycamore 731→SYC, sweetgum
611→SWEETGUM, blackgum 693→BLACKGUM, sassafras 931→SASSAFRAS, dogwood 491→DOGWOOD, white
pine 129→EWP, basswood 951→BSW, walnut 602→WALN, beech 531→BE, northern red oak 833→NRO,
black oak 837→BO). Congeners lump to the nearest modeled species exactly as the MN builder
lumps: silver/boxelder maple→RM; green/blue ash→WAS; pignut/bitternut/generic hickory→MOK_HK;
chestnut/chinkapin/swamp-white/bur oak→WO; blackjack/southern-red→BO; Shumard→NRO;
slippery/winged/rock elm→AE; cottonwood/bigtooth aspen→QA. Species outside the 23-species
pool (black cherry 762, eastern redcedar 68, black locust 901, hackberry, hophornbeam,
other pines) are dropped, the same modeled-species-only convention used for every state.
Map lives in `perseus/tools/build_plot_ics_N3.py`.

### IC generation
`build_plot_ics_N3.py` ran against the full untreated-plot lists:
- IN: 435 plots, **399 non-empty ICs**, 83.2% of live trees mapped to a modeled species.
- OH: 906 plots, **902 non-empty ICs**, 78.6% mapped.
(The unmapped ~17–21% are the intentionally-dropped non-pool species.) Output in
`states/<ST>/perseus/plot_ics_full/`, with `_summary.csv` providing the plot_id↔plt_cn map
the LL join in `run_param_set_<ST>_t2.sh` requires.

### Plot subset alignment
`in_t2_plotsubset.txt` / `oh_t2_plotsubset.txt` were regenerated (old versions backed up
to `*.bak_20260531`) to list only IC-backed, ecoregion-valid plots, stratified ≤100/eco:
IN 494, OH 369 (deduped). This keeps every runner plot backed by a real IC and observed
biomass, so the per-plot count clears the optimizer's `MIN_N_PAIRS=300` guard.

### Smoke test (the gate)
One IN plot (plot 1, 13 species cohorts) was run through the exact runner path:
`build_plot_scenario_IN.sh` → LANDIS v8 apptainer → biomass output. LANDIS exited rc=0
("Model run is complete") and wrote `biomass-<species>-{0..100}.tif` for all N3 species.
This proves the IC→scenario→LANDIS→biomass path that failed on 2026-05-29 now works.

### IN chain launched
`in_t2_v2` driver submitted as **job 11118354** (72 h, 1 cpu, 4 GB):
```
python3 tools/cma_es_optimize_cluster.py --state IN --tag in_t2_v2 \
    --warmstart tools/state_templates/cluster_N3_reference_theta.csv --max-iter 8 --population 14
```
Uses the v1.5 hardened, warmstart-capable cluster optimizer. Warmstart seeds 12/23 species
from MN; CMA-ES refines from there.

## Next steps

1. **Verify IN iter0 lands real LLs (not the 1e6 penalty).** When the array chunks finish
   the first candidate (~1–1.5 h after the driver starts), check:
   `bash tools/check_t2v2_chains.sh in_t2_v2` — expect negative per-candidate LLs and a
   growing `cma_history.csv`. If iter0 shows real LLs the warmstart pipeline is validated
   end to end.
2. **Smoke-test then launch OH.** OH ICs + subset are ready; run a one-plot smoke through
   `build_plot_scenario_OH.sh` first (it predates this session and was not smoke-tested),
   then submit `oh_t2_v1`/`oh_t2_v2` warmstarted from `cluster_N3_reference_theta.csv` the
   same way.
3. **Harvest when landed.** `python3 tools/harvest_t2_chains.py --bayesian-dir
   states/IN/perseus/bayesian/in_t2_v2 --state IN`; promote, then PERSEUS is 8 states.
4. Once IN lands, re-freeze `cluster_N3_reference_theta.csv` from IN's own production theta
   so OH and future N3 states warmstart from a calibrated reference rather than the MN
   bootstrap.

## Caveats

- The N3 map's oak/hickory analog choices (e.g., chestnut oak→WO, pignut→MOK_HK) are
  defensible nearest-neighbor lumps but were made without REF_SPECIES; worth a domain
  glance. They affect only IC cohort assignment, not the calibration target.
- The cluster optimizer ran a single-plot LANDIS smoke but the full 494-plot driver loop is
  not yet observed to completion; monitor job 11118354.
