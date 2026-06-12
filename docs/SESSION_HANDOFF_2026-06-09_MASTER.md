# Harmonized multi-model CONUS assessment — MASTER session handoff (2026-06-09)

**Repo:** github.com/holoros/landis2HPC  ·  **Cardinal:** OSC PUOM0008, scratch `/fs/scratch/PUOM0008/crsfaaron` (home `/users/PUOM0008/crsfaaron`)

Master continuity document for the apples-to-apples multi-model assessment (Daigneault
et al. 2024 framing). Keystone config: `cbm_states/cross_state/libcbm/tools_conus/harmonized_scenarios.yml`.
Target architecture: **5 models (FVS, LANDIS, CEM, yield curves, CBM) x 4-5 scenarios
(reserve / conservation / BAU / intensive, + optional land-sparing or disturbance-exposed)
x 2 spatial datasets (FIADB-uniform vs TreeMap-painted)**, all on one FIA design anchor and
one HCS common harvest. Supersedes the earlier 2026-06-09 handoffs for status; those remain
valid for their specifics (WIMI_fix, harmonized_push).

## 1. The common pipeline (works; proven across 4 models)

Every model is reduced to a per-state reserve trajectory, anchored, then run through one
harvest+metric engine. The anchor is a ratio so units/carbon-fraction cancel; only the
no-harvest DYNAMICS differ between models (the intended signal).

- Anchor: `harmonized/*_reserve*.R` -> `model_anchored(t) = FIA_design(state) * model(t)/model(2025)`,
  FIA anchor `FIA/fia_agc_anchor_design_by_state.csv` (CONUS 15.28 Pg C live AGC).
- Engine: `harmonized/apply_harvest_scenarios.R --reserve <file> --out <traj> --summary <sum>`.
  Common HCS per-state rate, scenario multipliers reserve 0 / conservation 0.6 / BAU 1 /
  intensive 2, HWP first-order pool, timber NPV. Hardcodes model="LANDIS" in the trajectory
  (cosmetic; summary keys on state/scenario).

## 2. Model status against the 5 x scenarios x 2-dataset matrix

| Model | Common-pipeline coverage | Scenarios | FIADB | TreeMap | Notes |
|---|---|---|---|---|---|
| FVS | 48 states | 4 | yes | no | `harmonized_fvs_carbon_npv.csv`; resolved, native. |
| Yield curves | 48 states | 4 | yes | yes | re-anchored this session; `harmonized_carbon_npv_YC.csv`. rcp45 used as near-current. |
| LANDIS | 7 (WA MN OH IN WI MI ME) | 4 | yes | sub-state only | `harmonized_carbon_npv_7state.csv`. WI/MI carry MN-51 borrowed params; rest native. |
| CEM | 26 reserve / 24 summary | 4 | yes | no | adapted (`harmonized_carbon_npv_CEM.csv`); ends ~2095, array finishing toward 48. |
| CBM | 48 states, 2100 | 4 | yes | no | BUILT + locked to 2100 (`harmonized_carbon_npv_CBM.csv`); pools-based AG live C. See 4b. |

Cross-model outputs in `harmonized/`: `harmonized_crossmodel_3model_7state.csv`
(LANDIS/FVS/YC), `harmonized_crossmodel_FVS_YC_CONUS.csv`, plus per-model summaries.
Headline: under identical inputs, 2100 reserve total C diverges ~2x and flips by region
(LANDIS highest in East/Lake States/Northeast, FVS highest in PNW); scenario ordering holds.

## 2b. FVS 4-version matrix (default|calibrated x FIADB|TreeMap)

The FVS axis is two crossed factors. Default vs calibrated = the `CONFIG` column in the FVS
stress densities: `fvs_stress/out_fvs_v3/conus_*_b*.csv` (CONFIG=`default`, original FVS params
from Fortran) vs `out_gompit_v3/...` (CONFIG=`gompit`, the calibrated/remodeled version).
fvs-modern repo confirms: `config/*.json`=default, `config/calibrated/*.json`(+`_draws`)=Bayesian
posterior. FIADB vs TreeMap = allocation (state-mean anchor vs per-plot TreeMap painting).

Built this session via `harmonized/build_fvs_reserve_cfg.R --dir <out_*_v3> --config <default|gompit>`
then `apply_harvest_scenarios.R`:
- default x FIADB  -> `harmonized_carbon_npv_FVSdefault.csv` (CONUS reserve 2100 = 40,137 Tg C)
- calibrated x FIADB -> `harmonized_carbon_npv_FVScalibrated.csv` (= the existing harmonized FVS; 32,207)
Comparison: `harmonized_fvs_default_vs_calibrated.csv`. FINDING: calibration uniformly pulls FVS
to ~0.80x default 2100 carbon across all 4 scenarios (CONUS), i.e. default FVS over-projects
growth and the gompit/Bayesian calibration corrects it toward FIA-consistent dynamics.

ALL 4 CELLS NOW BUILT. The TreeMap cells use `build_fvs_reserve_treemap.R`, which area-weights
each FVS plot by its TreeMap imputed area (`plt_area_treemap.csv`), joining FVS STAND_CN and
TreeMap PLT_CN to a common physical plot id via `cn2pid.csv` (different inventory-cycle CNs).
Outputs `harmonized_carbon_npv_FVSdefault_TM.csv` / `..._FVScalibrated_TM.csv`; consolidated 2x2
in `harmonized_fvs_2x2_matrix.csv` (48 states x 4 scenarios x 4 versions).

CONUS 2100 reserve (Tg C): default-FIADB 40,137; calibrated-FIADB 32,207; default-TreeMap 42,909;
calibrated-TreeMap 33,864. TWO CLEAN EFFECTS: calibration ~0.80x default in BOTH allocations
(0.80 FIADB, 0.79 TreeMap); TreeMap ~+5-7% vs FIADB.

CAVEAT: the TreeMap cells cover 41 states at a median of only ~23 TreeMap-donor plots/state (the
donor-subset basis of TreeMap area weighting), so they are a coarse/noisy sensitivity, NOT a
full-population estimate; the FIADB cells (48 states, all plots) are the solid versions. A proper
pixel-level TreeMap allocation (full donor raster, not just the 65k plt_area donors) would
strengthen the TreeMap cells. Headline cross-model files currently use calibrated-FIADB; all four
are now available to show the config x allocation sensitivity.

## 3. CEM (4th model) — done this session, refine + extend

`harmonized/build_cem_reserve.R` reads each state's newest
`fia_cem_projections/output/<ST>_*_conus_harmonized_sdimax_<ST>/ci_summaries.csv`, takes the
`No_harvest` scenario `mean_carbon_mean` by cycle, anchors to FIA, runs the common harvest.
21 states so far; the `cem_rerun` SLURM array (running) fills the rest toward 48 — re-run
`build_cem_reserve.R` + `apply_harvest_scenarios.R` when it completes.
REFINE: cycle->year currently `2025+5*(cycle-1)` -> 15 cycles land on 2025-2095. Confirm
whether CEM cycle 1 is the 2025 inventory or first projected step; adjust so the endpoint is
2100 (likely 16 cycles or a 2030 start).

## 4b. CBM (5th model) — BUILT + LOCKED TO 2100, 48 STATES (updated 2026-06-10)

DONE. The CBM `bau` run uses an empty disturbance-events file (no harvest, no
disturbance) = the harmonized reserve. The full-CONUS run (job 11447366) COMPLETED and wrote
`cbm_states/cross_state/libcbm/<ST>/conus_dist/pools_<ST>_BAU.csv` for all 48 states (78 rows,
timestep 0-76 -> year 2024+timestep = 2100). `harmonized/build_cbm_reserve.R` was rewired to
read those pools files: aboveground live C = SoftwoodMerch+SoftwoodFoliage+SoftwoodOther+
HardwoodMerch+HardwoodFoliage+HardwoodOther (no roots/soil/snag/DOM), keep years 2025-2100,
anchor 2025 to the FIA design total. Legacy `gcbm_state_aggregate.csv` path kept as a fallback.
Output `cbm_reserve_anchored.csv` = 48 states, 2025-2100 (3,648 rows). Ran
`apply_harvest_scenarios.R --reserve cbm_reserve_anchored.csv --summary harmonized_carbon_npv_CBM.csv`
-> 48-state CBM 4-scenario summary. Stress test re-run: 0 hard failures, 0 warnings.

ALL 5 MODELS ON THE COMMON PIPELINE. `harmonized_crossmodel_5model.csv` rebuilt at the full
2100 horizon. Reserve 2100 (Tg C):
  IN: LANDIS 583, FVS_def 359, CBM 317, FVS_cal 313, yield-curve 231, CEM 126
  OH: LANDIS 784, CBM 752, FVS_def 605, FVS_cal 511, yield-curve 366, CEM 156
CBM moved from 190 (old 2074 cutoff) to 317 for IN once extended to 2100, landing right next to
FVS_cal. 5-model overlap is IN + OH only (LANDIS covers 7 states {IN ME MI MN OH WA WI}, CEM
covers 24-26 states, and the two sets intersect only at IN, OH). Overlap grows once CEM is run
on LANDIS states or LANDIS adds CEM states. Earlier note: the 5-model overlap was just IN
(CBM 6 states, CEM 26, LANDIS 7); it grows to the LANDIS-7 and beyond as the CBM full run and
CEM array complete. CEM refreshed to 26 states.

## 4. CBM (5th model) — original blocker note (superseded by 4b)

CBM per-state output is `cbm_states/states/<ST>/10_outputs/gcbm_state_aggregate.csv`
(6 states: GA IN OR MN WA ME). The right metric exists: `variable=AG_Biomass_C` (aboveground
biomass carbon), `total_TgC` by `step`. BUT: (a) it is a single scenario (the BAU/managed run,
no scenario column), so there is no no-harvest reserve trajectory to anchor + common-harvest;
(b) it runs ~50 steps (to ~2075), short of the 2100 horizon; (c) only 6 states.
NEEDED before CBM can join: a no-harvest libcbm CONUS run emitting `AG_Biomass_C` by step to
2100, then a `build_cbm_reserve.R` adapter (mirror `build_cem_reserve.R`): filter the
no-harvest run, anchor `AG_Biomass_C` to the FIA design, run the common harvest. Do NOT use
`Total_Ecosystem_C` (includes large soil/DOM pools, not comparable) or BAU-as-reserve.

## 5. Real stumpage (economics axis) — data is on Cardinal

`apply_harvest_scenarios.R` uses a flat `STUMPAGE<-14` $/m3 placeholder (line 33). The
`conus_hcs` stumpage subsystem exists but is NOT yet a finished per-state panel: there is a
source CATALOG (`conus_hcs/config/CONUS_stumpage_source_catalog.csv`: per-state source,
granularity, products, access) and model scripts (`R/07_stumpage_panel.R`,
`stumpage_price_model.R`, `ingest_western_stumpage.R`), but no computed per-state $/m3 file was
found. TO DO: acquire/ingest the catalogued sources (several are subscription, e.g.
TimberMart-South), run the price model to emit a per-state $/m3 (or $/ton + conversion via
VOL_M3_PER_MG) table, replace the scalar with a per-state lookup, regenerate all NPV in one
pass. This is a data-acquisition + modeling task, not a wiring task; do not invent values.

## 6. TreeMap dataset axis (2nd of the 2 datasets) — KEY CONSTRAINT FOUND (2026-06-09)

Yield curves carry both FIADB and TreeMap natively because they were fit per-FIA-plot and
painted on the TreeMap donor set. For the OTHER models this is NOT a free post-step:

FINDING. TreeMap allocation can only area-weight plots that ARE TreeMap 2016 donors. The
`fvs_stress/plt_area_treemap.csv` (65k plots) is already the COMPLETE donor set (it derives from
`TREEMAP_restore/TM2016/TreeMap2016.tif.vat.dbf`, which carries CN + pixel Count + carbon per
donor condition; no 15B-pixel raster scan needed). But FVS / LANDIS / CEM were each run on a
DIFFERENT FIA plot set (different inventory cycle), overlapping the donors only ~30% by physical
plot id (cn2pid). So a TreeMap-allocated FVS/LANDIS rests on that ~30% (FVS TreeMap cells: 41
states, ~23 donor plots/state; a coarse sensitivity, not a population estimate). A LANDIS
TreeMap attempt (`treemap_allocate.R` on `landis_allstate_reserve.csv`) further mis-assigned
states in the cn2pid join, confirming retrofitting is fragile.

CONCLUSION. Do NOT retrofit TreeMap onto the existing FVS/LANDIS/CEM runs. The clean FIADB
versions are the solid ones; for the FIADB-vs-TreeMap sensitivity rely on the yield curves
(native both) and FVS's caveated TreeMap cells. A full multi-model TreeMap comparison requires
RE-RUNNING the models on the TreeMap donor plot set (the ~65k 2016 plots), a defined but
substantial task, not an allocation tweak.

TOOL. `harmonized/treemap_allocate.R` is the reusable area-weighting step (any model with a
per-PLT_CN reserve PLT_CN,year,agc_MgC_ha -> TreeMap-weighted, FIA-anchored). Usable once a
model is run on donor plots, or for the partial-overlap sensitivity. `treemap_paint.R` remains
for sub-state mapping. FVS TreeMap cells: `harmonized_carbon_npv_FVS{default,calibrated}_TM.csv`.

## 7. 5th scenario (optional)

The yml documents a `land_sparing` portfolio (set_aside_frac 0.3 + intensive_frac 0.3). The
TreeMap `p_disturbance_{2016,2020,2022}.tif` rasters support a disturbance-exposed variant
(the yield curves already produced "managed (X, disturbance-exposed)"). Either is a small
addition to `apply_harvest_scenarios.R`.

## 8. LANDIS expansion (slow lane; NH wired, gated on per-plot validation)

`conus_tools/` is the durable safety net: `conus_preflight.R` (readiness doctor),
`compose_sppeco_baseline.R` (baseline-gap repair), `extract_eco_crosswalk.R`/`resolve_eco.sh`/
`ecoregion_names.csv` (data-driven build), `build_plot_ics_N1.py` (Northeast IC builder,
oak-extended), `validate_ic_coverage.py` (zero-drop check). Preflight: 7 LANDIS states PASS.
- N1 pool extended with oak (RO) + hickory (HICK); coverage ME 99.1% / NH 99.0% / VT 97.9%.
  Params from OH/IN analog on ME's scale; `states/ME/inputs/RO_HICK_provenance.md`.
- ME oak retrofit ABANDONED: the calibrated `eco_v2` SppEco that produced ME's validated run
  is deleted and unreconstructable (tested base / base*mult vs the existing log: PINE off ~2.4x,
  HE off ~8x). ME stays 13-species in the comparison; its oak is in the anchor LEVEL only.
- NH VALIDATED end-to-end (2026-06-09): `tools/plot_to_ecoregion_NH.csv` (ecos 58/59, both in
  ME pool), inputs symlinked to ME's N1 reference, oak ICs built (`states/NH/perseus/plot_ics_full`).
  `build_plot_scenario_NH.sh` was patched (backup `*.bak_prefix`) to fix two generic-template
  bugs the single-plot gate caught: (1) ecoregions.txt now copies the state's working multi-eco
  file (was a malformed single-eco line -> LANDIS "extra data" error); (2) climate now feeds the
  wide PRISM directly as ME does (was a broken long-format transpose). Smoke run of NH plot_1000
  (eco 58) completes: total AGB 20,096 g/m2 (2025) -> 28,010 (2100), with red oak 6,794 -> 10,584
  (~34% of biomass), confirming the oak-extended N1 pool works. These fixes should be folded back
  into `state_templates/build_plot_scenario_template.sh` so every N1 (and similar) state inherits them.
  NH + VT CALIBRATION CHAINS LAUNCHED (2026-06-09): NH job 11415281 (`nh_t2_v1`), VT 11415282
  (`vt_t2_v1`), 2-day CMA-ES via `cma_es_optimize_N1.py` warmstart from
  `state_templates/cluster_N1_reference_theta.csv` (RO/HICK cold-start at 0.60 by design).
  Two bugs were fixed to get them running correctly (both would otherwise waste a 2-day run):
  (1) ENV: the driver imports scipy/cma; the default and R/4.4.0 python have a numpy/scipy binary
      mismatch. Fix: the sbatch `--wrap` does `module load python/3.12` (numpy 1.26.4, scipy 1.13.1,
      cma present). Use python/3.12 for any future chain.
  (2) CN PAIRING: the likelihood pairs model trajectories to observed FIA biomass in
      `untreated_plots_<ST>.csv` by `FIRST_PLTCN`. The first NH ICs used each plot's LATEST CN
      (0/999 overlap -> n=0 -> every candidate penalized). Fix: rebuilt NH/VT ICs with
      `build_plot_ics_N1.py --plot-list untreated_plots_<ST>.csv` (FIRST_PLTCN keyed) -> 999/999
      and 854/854 overlap. This also makes the IC the first-inventory state (correct: project from
      first cycle, validate against remeasurements). Per-state runners `run_param_set_{NH,VT}_t2.sh`
      (sed from MN), targets `untreated_plots_{NH,VT}.csv`, plot_to_ecoregion built via the shp tool
      in the SIF. VT required ecoregion 83 composed (SppEco rows + a PRISM climate column, both from
      eco-59) since ME's pool is 58/59/82; VT eco-83 plot validated (LANDIS completes).
  (3) DEGENERACY GUARD: a third bug after env+pairing. `cma_es_optimize_cluster.py`
      `check_active_growth()` globbed the runner's `runs/` dir, but the runner deletes it before
      the driver checks, so frac was always 0; combined with the `frac<0.50 and ll>-100` guard,
      small states (NH LL~-92 because only ~188 residuals) were penalized on EVERY candidate.
      Fixed: `check_active_growth` now reads the persistent `per_plot.csv` (backup
      `cma_es_optimize_cluster.py.bak_activegrowth`). Confirmed working after resubmit (NH jobs
      11420402/11420403): candidates now score real values (e.g. iter0 cand5 negLL=92.21), while
      genuinely non-growing thetas still correctly get the 1e6 penalty.
  A daily monitor (`~/Documents/Claude/Scheduled/landis-calibration-monitor`, 8 AM) reports chain
  state, best negLL, and CEM coverage. The two build-script fixes were FOLDED BACK into
  `state_templates/build_plot_scenario_template.sh` (backup `.bak_prefix`) so future states inherit
  them. CEM refreshed to 24 states (2026-06-09).
  MONITOR: `squeue -u crsfaaron | grep t2_v1`; per-candidate LL in
  `states/<ST>/perseus/bayesian/<tag>/<tag>_iter*_cand*/launch.log` (look for `n=` >0 and finite LL).
  On completion the best theta lands in the bayesian dir; then build each state's statewide reserve
  (landis_adapter pattern) and fold into the LANDIS multi-state table.
  FOLD-BACK: apply the two build-script fixes (ecoregions copy + direct wide-PRISM climate) to
  `state_templates/build_plot_scenario_template.sh`, and have `add_state.sh` use python/3.12 +
  build ICs from `untreated_plots_<ST>` so future states inherit all of this.
RECOMMENDATION: do not gate the framework on LANDIS CONUS-completeness; 7-10 states is a valid
structural exemplar while FVS + YC carry CONUS.

## 8b. Stress-test — PASS (re-run 2026-06-10 after CBM 2100 lock)

`harmonized/stress_test_harmonized.py` is a reusable adversarial check on every model's outputs.
Run: `python3 stress_test_harmonized.py` (exit 0 = pass). Latest run:
- ANCHOR: every model reserve starts at exactly the FIA design value in 2025 (LANDIS 7, FVS 48 x2,
  YC 48, CEM 26, CBM 48) - zero mismatches.
- MONOTONICITY: reserve >= conservation >= BAU >= intensive total 2100 carbon - zero violations, all models.
- RESERVE HWP == 0, no NaN/negative/absurd values - clean.
- CROSS-MODEL ANCHOR: on IN and OH (the all-6-file overlap) all models share the 2025 anchor (IN 179,
  OH 251), spread 0.0.
=> 0 hard failures, 0 warnings. The cross-model divergence is real, not a pipeline artifact.

## 8c. External benchmark validation (2026-06-10) — see BENCHMARK_VALIDATION_2026-06-10.md

Validated the harmonized outputs against the American Forests state CBM reports (CBM-CFS3+HWP,
same family as our CBM): MN, OR (2026), CA (2025), MD, PA (2023). Benchmarks in
`harmonized/americanforests_cbm_benchmarks.csv`; checks in `harmonized/benchmark_validation.py`,
`harmonized/cbm_init_diagnostic.py`; cross-model reserve growth in `reserve_growth_crossmodel.csv`.
Four findings, all fixable:
1. CBM under-initializes the eastern US: 25/48 states start below 1.5x FIA stocking (WV 2.65x,
   MD 2.47x, PA 2.43x, OH 2.39x). The no-disturbance reserve then regrows 150-207% in those
   states. Anchoring keeps that shape, so eastern CBM over-projects 2-2.7x. Fix: re-init CBM
   from FIA stocking. Interim: prefer FVS_cal for the eastern reserve shape.
2. FVS over-projects the West: CA/OR reserves grow 300-600% (impossible for mature fire-prone
   conifer). CBM is more restrained there (CA +54%, OR +22%). Fix: density-dependent mortality / max-SDI ceiling.
3. Every model's reserve is a no-disturbance CEILING, not a forecast. Median reserve growth:
   YC +34%, FVS_cal +100%, CBM +127%, FVS_def +145%. Only YC has any declining states. None
   reproduce the climate+fire decline the reports project for the West (OR flips to a net SOURCE
   by 2029, +825% wildfire). A disturbance overlay is required before reserves read as projections.
4. The common HCS harvest under-harvests the West: CA 0.002%/yr, OR 0.003%/yr, WA 0.010%/yr
   (vs MN 0.335%), collapsing CA/OR scenario spread to <1%. Fix: re-derive western harvest rates.
The 4-5x cross-model divergence is now attributed to these specific causes, not irreducible
uncertainty. Internal consistency (8b) still passes; these are accuracy/initialization issues.

## 8d. Refinements + uncertainty (2026-06-10) — see BENCHMARK_VALIDATION_2026-06-10.md

CBM eastern under-initialization CORRECTED: `build_cbm_reserve.R --align TRUE` (default) estimates
CBM's own carrying capacity + rate by regressing AG increment on AG size, then enters the curve at
the FIA-observed stocking. Eastern reserve growth fell from 176-207% to 50-87%; under-init flags
30 states -> 5 edge cases. Raw kept at `cbm_reserve_raw_anchored.csv`. Interim pending a true
FIA-initialized CBM re-run. Western harvest confirmed a data-product limitation (TM2016 harvest
raster: 31% GA pixels vs 0.03% OR), deferred to a better western harvest layer.

UNCERTAINTY: `uncertainty_ensemble.R` decomposes (1) inter-model structural spread [dominant:
CONUS reserve CV 0% in 2025 -> 21.5% by 2100; state median CV 42.5%, up to 132% in CA/OR],
(2) intra-model parameter [now the REAL FVS Bayesian posterior band for 7 states via
`fvs_posterior_ci_all.csv`; cal-vs-def proxy elsewhere; CBM draws flagged], (3) FIA sampling
[common cv_pct]. Combined in quadrature -> 90% band. VARIANCE DECOMPOSITION: structural >> parameter
>> sampling; structural is 41x the FVS parameter SD by 2100 (model choice dominates). Outputs
`uncertainty_by_state_year.csv`, `uncertainty_conus.csv`, `fig_uncertainty_{A,B,C}*.png`.

## 8e. All-fronts push (2026-06-10)

1. FVS posterior extended: state->dominant-variant map built (`build_post_manifest.py`), priority
   12-state x 24-draw array launched (job 11460953, %40 throttle) to grow the real intra-FVS band
   to the benchmark + high-CV states. MaxArraySize=1001 and the 1000 submit cap forced the subset;
   queue the remaining states when the queue drains.
2. DISTURBANCE OVERLAY (`apply_disturbance_overlay.R` + `disturbance_rates_by_state.csv`): first-order
   state fire-mortality applied to all model reserves (`*_disturbed.csv`). FVS CA +272%->+64%,
   OR +223%->+116%, AZ +72%->-32% (declines); eastern ~unchanged. Disturbance-aware CONUS 2100 median
   24.3->20.6 Pg C, inter-model CV 21.5%->17.3%. `uncertainty_ensemble.R --mode disturbed`;
   `fig_disturbance_compare.png`. Rates are order-of-magnitude (MTBS-era + OR report); calibrate next.
3. CBM parameter draws: libcbm imports only in the apptainer SIF; an intra-CBM ensemble needs a
   parameter-perturbation harness = future work. LANDIS NH/VT still calibrating (iter5, NH negLL 89.4,
   VT 71.0); integrate the reserves when they finish to widen the cross-model overlap beyond IN/OH.

## 8f. Disturbance rate calibration + posterior expansion (2026-06-10)

DISTURBANCE RATES CALIBRATED to data: `derive_disturbance_rates.py` computes each state's base
fire/disturbance loss rate from the CBM no-disturbance BAU vs LCMS natural-only run
(`pools_<ST>_lcms_nat_HIST.csv`, 50yr) - the AG-live gap on the pipeline's own basis. Came out ~10x
lower than the first guesses (CA 0.072, OR 0.113, ID 0.234, WA 0.194 %/yr); ramp kept from the OR fire
trend. `disturbance_rates_by_state.csv` rebuilt; overlay re-applied to all models. Disturbance-aware
CONUS 2100 median 24.3 -> 23.1 Pg C, CV 21.5% -> 19.3% (modest, honest reduction). KEY FINDING: with
data-grounded rates + 3x ramp the FVS western over-projection PERSISTS (CA +272% -> +241%), so it is
substantially an FVS growth-engine issue (needs density-dependent mortality / max-SDI), not just
missing disturbance. LCMS base predates recent fire escalation = conservative.

FVS POSTERIOR expanded 7 -> 19 states (priority array 11460953 done; `aggregate_posterior_ci.py`
rebuilds `posterior_ci_all.csv`). Parameter bands tight (most +/-0-3.5%, ID +/-10.5%). Structural/
parameter SD ratio now 15x (2050) to ~40x (2075-2100) on 19 states - model choice still dominates.
Note: a few states show +/-0.0% (degenerate draw spread for those variants) - minor data-quality item.

## 8g. FVS max-SDI audit (2026-06-10) - see FVS_SDIMAX_AUDIT_2026-06-10.md

Tested AW's hypothesis that western over-projection is a metric-vs-Imperial max-SDI bug. RULED OUT:
the engine is Imperial (morts.f90, English Reineke const) and calibrated SDImax are English and ~=
FIA-observed (WS median 394 vs FIA 415, CR 423 vs 465; metric would be ~2.47x higher). Real gaps
found and one fixed: (1) NA max-SDI dropout - calibrated configs carry NA for 9-25% of species,
which the keyword writer skips so they revert to high FVS built-in defaults (WS redwood -> 1052).
Fixed with `make_sdifix_configs.py` -> `config/calibrated_sdifix/` (NA filled with variant calibrated
median; redwood now 394). (2) EC/WA never recalibrated (calibrated == default). (3) SO/CI/PN/WC store
sdimax under a different key - verify they carry real calibrated values. EMPIRICAL TEST (`test_sdimax.py`,
40 WS plots to 2100): 2100 carbon IDENTICAL (80.6 MgC/ha) under current, NA-fix, AND an extreme
SDImax=120 cap -> the ceiling does not bind for the sample; the western over-projection is
GROWTH-ENGINE driven, not a max-SDI problem. Next lever: temper the western diameter-growth multiplier
and/or regenerate the western FVS reserve via the production conus runner with the sdifix configs.
Scripts saved in harmonized/ (make_sdifix_configs.py, test_sdimax.py, sdifix/ws_sdifix.json).

## 8h. FVS diameter-growth ADOPTION GAP - root cause (2026-06-10) - see FVS_DG_ADOPTION_GAP_2026-06-10.md

Followed AW's pointer to fvs-conus. DG calibration fits EXIST for all 26 variants
(`categories_conus/diameter_growth` = dg_kuehne_cspi_traits1 CONUS model; per-variant posteriors in
fvs-conus/output/variants/<v>/; summary dg_all_variants_summary_final.csv). BUT runtime adoption
(provenance available.DG=True + dds_multiplier intercept-shift -> BAIMULT) was completed for only 7
variants (acd, ca, cs, kt, ls, nc, on). 18 variants have DG:False, dds=1.0, running NATIVE
uncalibrated FVS diameter growth - including ALL western (ws=CA, so=OR, ec=WA, ci=ID, cr, em=MT,
pn, wc, tt, ut) and the two biggest eastern (ne, sn); ~38 states affected. THIS is the western
over-projection root cause: FVS grows the West 3-6x the FIA-grounded CBM/YC consensus by 2050
(CA FVScal +112 vs CBM +17/YC +19), and gompit calibration barely helped (CA def 333->cal 272)
precisely because DG was never adopted for ws. Not metric, not SDImax (ruled out), not a model-
structure limit - a calibration-DEPLOYMENT gap. FIX (highest-impact FVS action): compute
dds_multiplier=exp(delta b0) per species from the existing dg_kuehne posteriors for the 18 variants,
set available.DG=True, regenerate configs (re-run 06_posterior_to_json.R / the adoption step), re-run
western FVS reserve, recheck vs consensus + American Forests benchmarks. Expect FVS western growth to
drop toward consensus and inter-model CV to tighten. Diagnostic scripts: western_growth_compare.R.

ADOPTION CANNOT be reverse-engineered: validated against adopted variant ls, exp(species intercept)
reproduces only 2/33 of the deployed dds_multiplier - the "delta b0" is relative to FVS NATIVE DG
(needs native coefficients + ecodiv weights + b1 slope + modifier_lambda), not in the config. The
original calibration-bridge script was not locatable (likely fvs-conus or a one-off). Completing
adoption is a calibration-author re-run, NOT a hand reconstruction (which would risk corrupting the
calibration). Diagnosis complete; the remaining step is a pipeline re-run with inputs that all exist.

## 8k. All-fronts cycle 2 (2026-06-11): YC band, full FVS re-run, synthesis report

YC INTRA-MODEL BAND added: `yc_bands.csv` = rcp45-vs-rcp85 climate spread (small, <1-3%) + the YC
simulation CI mmt_agc_lo/hi (~8%, dominant); combined into build_crossmodel_ci.R. Now 3/5 models carry
real intra bands (FVS posterior, CBM OAT, YC rcp+sim); LANDIS/CEM still anchor-only. CI conclusion holds:
14/15 distinguishable at IN, 15/15 OH/NH.
FULL-CONUS FVS DG re-run: eastern/other 277 tasks launched (job 11491878 -> out_gompit_v4); western
already in v4. When complete, re-extract full FVS reserve (build_fvs_reserve_v4.R) and check the East.
SYNTHESIS REPORT drafted: docs/HARMONIZED_ASSESSMENT_REPORT_2026-06-11.md (design, refinements, CI
comparison, uncertainty decomposition, benchmark validation, findings, caveats).
LANDIS replicate band still outstanding (needs seed-varied statewide reruns); CEM scenario-invariant
(anchor SE appropriate).

## 8j. Cross-model CIs + CBM OAT env + FVS DG adoption EXECUTED (2026-06-11)

CONFIDENCE INTERVALS (`build_crossmodel_ci.R` -> `harmonized_crossmodel_ci.csv`): each model's 2100
reserve value with a 90% CI = anchor SE (FIA cv, in every reserve file) (+) intra-model parameter band
where available [FVS = Bayesian posterior `fvs_posterior_ci_all.csv`; CBM = OAT envelope
`cbm_oat_bands.csv`]. RESULT: model differences dwarf within-model uncertainty - 14/15 distinguishable
pairs at IN (only FVS_cal~CBM overlap), 15/15 at OH and NH. The cross-model divergence is signal, not noise.

CBM OAT ENV FOUND: libcbm lives in `/users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/python` (not the
plain modules). `run_oat_sensitivity.py <ST> --base business_as_usual --years 76` produces the +/-25%
5-parameter envelope. Half-range ~3.2-3.5% of central (IN 3.5, OH 3.2, NH 3.2). Run for IN/OH/NH (+
ME/MN/WA/OR/CA/PA in progress). This is the intra-CBM band.

FVS DG ADOPTION EXECUTED (the western over-projection fix, in-pipeline): enabled DG in
equation_availability_full.csv (fvs-modern + fvs-conus copies, backed up), patched the sys.frame self-
location bug in 06_posterior_to_json.R line 43 (.bak_sysframe), re-ran the driver per variant. 14/18
adopted so far (ws so ec cr ci em ne sn pn + more finishing; each config keeps .pre_conus_* backup),
real dds_multiplier now reaching the engine (WS 0.58-1.65 across 35/43 species, available.DG=True).
VALIDATION DONE (2026-06-11): DG adoption is 18/18 complete. The western FVS reserve was re-run
(job 11490666 -> out_gompit_v4) and re-extracted (build_fvs_reserve_v4.R). KEY RESULT: DG adoption does
NOT fix the western over-projection - growth barely moves (CA 272->254, OR 223->215, WA 177->171; ID/NV
rise). The over-projection PERSISTS (170-570% vs CBM/YC 22-54%). So it is INTRINSIC to FVS individual-tree
no-disturbance dynamics (western conifers aggrade toward their real 400-1000 MgC/ha old-growth potential),
NOT a calibration bug -> REAL structural uncertainty, correctly captured by the inter-model spread. The
DG adoption remains the right correctness fix (closes the deployment gap, calibrates all variants), but it
does not reconcile FVS with the other models in the West; only the disturbance overlay + treating FVS as
the high-potential end-member does. CBM OAT bands now for 9 states (cbm_oat_bands.csv: IN 3.5% OH 3.2%
NH 3.2% ME 3.0% MN 3.7% WA 2.8% OR 2.2% CA 2.3% PA 3.0%). Optional: full-CONUS DG-adopted FVS re-run to
refresh the East (NE/SN also adopted), but the western result implies the headline spread is robust to it.

## 8i. NH/VT LANDIS calibration FINISHED + statewide reserve builds launched (2026-06-10)

NH and VT t2 calibration converged (NH negLL ~89.3, VT ~69.5; theta_best.csv written). Launched the
statewide reserve_v1 builds (`run_statewide_buildfresh.sh <ST> theta_best.csv reserve_v1`) for both -
background SLURM jobs (NH 233 plots, VT 180 plots, stratified <=200/ecoregion, 100yr). When they land,
anchor the state-median TotalBiomass trajectory to FIA design and add to harmonized_landis_reserve
(7 -> 9 states: + NH, VT), then re-run uncertainty_ensemble.R + stress_test_harmonized.py. This widens
the LANDIS coverage and the 5-model overlap. Logs: states/{NH,VT}/perseus/statewide/reserve_v1/launch.log.

DONE (2026-06-10): both builds finished fast (state_trajectory.csv). Integrated via
`add_nh_vt_landis_reserve.R` (LANDIS yr 0/25/50/75 -> 2025/2050/2075/2100, anchored to FIA design):
NH 153.2->271.1 Tg C (+77%), VT 142.9->277.0 (+94%). `harmonized_landis_reserve_9state.csv` (+disturbed,
+4scenario summary harmonized_carbon_npv_9state.csv). uncertainty_ensemble.R + stress_test_harmonized.py
repointed to the 9-state files; stress test PASSES (LANDIS 9 states, anchor OK, monotonicity 0, 0 failures).
5-MODEL OVERLAP grew {IN,OH} -> {IN,OH,NH} (CEM also covers NH). NH 2100 reserve (Tg C): FVS_def 408,
FVS_cal 291, LANDIS 271, CBM 215, YieldCurve 178, CEM 78 (~5x spread; LANDIS sits mid-ensemble, sensible
for the Northeast). harmonized_crossmodel_5model.csv refreshed. Next LANDIS states onboard the same way.

HORIZON STATUS: FVS/YC/LANDIS/CBM all reach 2100. CBM is now locked to 2100 (section 4b). CEM
still ends ~2095 (15 cycles); read CEM "2100" as end-of-horizon until the CEM team's 16-cycle
re-run lands. Minor open item: CEM reserve has 26 states but the harvest summary has 24 (2 states
drop in the HCS join) - worth a look.

## 9. Recommended next sequence

1. CEM to 2100 + 48 states: needs the CEM team's 16-cycle re-run; then re-run the adapter and fix
   the cycle->year mapping (2025+5*(cycle-1)). Resolve the 26-vs-24 HCS-join state drop.
2. Real stumpage from `conus_hcs` -> regenerate NPV across all models (quick, high value).
3. TreeMap allocation pass (`treemap_allocate.R`) for FVS/CEM/LANDIS -> 2-dataset axis (donor-limited;
   the clean version runs each model ON the TreeMap donor plots).
4. Add the 5th scenario (land-sparing or disturbance-exposed).
5. LANDIS NH/VT calibration chains (in iter4 as of 2026-06-10, NH best negLL 90.09, VT 74.92),
   then more N1/S1/P3 states. Expanding LANDIS coverage grows the 5-model overlap beyond IN/OH.

## 10. Cardinal background jobs (as of 2026-06-09)

`cem_rerun` array (CEM CONUS, filling toward 48); `ga_conus_hm2` (GA LANDIS build, ~20h+, no
statewide trajectories yet); plus unrelated raster jobs (v5/v7_30m, gee_rs). WI/MI LANDIS
stable (838/859 run dirs, real data). SSH via the `hpc-cardinal` skill key.
