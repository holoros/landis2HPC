# Full handoff — harmonized multi-model CONUS forest carbon assessment

Date 2026-06-11. Supersedes/extends SESSION_HANDOFF_2026-06-09_MASTER.md. OSC Cardinal, project
PUOM0008, user crsfaaron. SSH: copy key from the mounted .ssh-cardinal, `ssh -F <cfg> cardinal`;
bash calls are isolated (45s); long ops run via nohup background + poll. Scratch root for harmonized
work: `/fs/scratch/PUOM0008/crsfaaron/FIA`. Repo: `landis2HPC/harmonized/` and `landis2HPC/docs/`.

## 1. What the assessment is

Five independent forest-carbon models (FVS, LANDIS-II, CBM, yield curves, CEM) on one common pipeline,
so model structure is the only difference. Every trajectory is anchored to the same FIA 2025 live-AGC
design total per state (total(t)=FIA x perha(t)/perha(2025), ratio cancels units/carbon-fraction) and
driven by the same HCS common harvest, four scenarios (reserve 0x / conservation 0.6x / BAU 1x /
intensive 2x) with a first-order HWP pool. The reserve (no harvest, no disturbance) is the backbone.
FVS also spans default-vs-calibrated x FIADB-vs-TreeMap.

Coverage: FVS / yield curves / CBM = 48 states; CEM = 26; LANDIS = 9 (WA MN OH IN WI MI ME NH VT).
Full-model overlap (all 5): IN, OH, NH.

## 2. Current state of each model

- FVS: native, calibrated (gompit). DG calibration now ADOPTED for all variants (was 7/25). Western
  reserve re-run with DG adopted (out_gompit_v4) shows the western over-projection is INTRINSIC
  (individual-tree no-disturbance behavior), not a calibration bug. Full-CONUS v4 re-run IN PROGRESS
  (job gom_v4dg / 11491878; 17 of ~48 states extracted so far). Intra-model band from the Bayesian
  posterior (19 states, ~3%).
- CBM: 48 states, 2100. Eastern under-initialization corrected via entry-point method
  (build_cbm_reserve.R --align). Intra-model band from OAT (run_oat_sensitivity.py via the libcbm env,
  ~3.2-3.5%, 9 states in cbm_oat_bands.csv).
- LANDIS: 9 states (NH/VT added this cycle from fresh t2 calibration -> statewide reserve_v1 ->
  add_nh_vt_landis_reserve.R). Intra-model band NOT yet measured (needs seed-varied replicates).
- Yield curves: 48 states. Intra-model band = rcp45-vs-rcp85 climate spread + simulation CI (yc_bands.csv,
  ~8%).
- CEM: 26 states, scenario-invariant; anchor SE only (appropriate).

## 3. Refinements completed

1. CBM eastern under-init corrected (30 -> 5 flagged states).
2. Disturbance/climate overlay (apply_disturbance_overlay.R + disturbance_rates_by_state.csv;
   base from CBM LCMS-natural runs, ramp from the Oregon report). Disturbance-aware CONUS 2100 median
   24.3 -> 23.1 Pg C; inter-model CV 21.5% -> 19.3%.
3. FVS DG adoption (all 18 unadopted variants), via enabling DG in equation_availability_full.csv +
   patched 06_posterior_to_json.R (sys.frame bug) + re-run. Validation: barely changes the West (it is
   structural, not a bug). Backups: .bak_predgadopt, .bak_sysframe, per-config .pre_conus_*.
4. Western harvest documented as a data-product limitation (TM2016 raster under-detects western harvest).
5. FVS NA max-SDI dropout fixed (make_sdifix_configs.py); metric-vs-Imperial hypothesis ruled out.

## 4. Uncertainty + ensemble (the headline framework)

- Cross-model CIs: build_crossmodel_ci.R -> harmonized_crossmodel_ci.csv. Each model 2100 value with a
  90% CI = anchor SE (+) intra-model band (FVS posterior, CBM OAT, YC rcp+sim; LANDIS/CEM anchor-only).
  RESULT: 14/15 model pairs distinguishable at IN, 15/15 at OH and NH -> the ~4-5x divergence is signal.
- Variance decomposition (uncertainty_ensemble.R + fig_uncertainty_*.png): structural >> parameter >>
  sampling; structural is ~40x the parameter SD by 2100.
- WEIGHTED ENSEMBLE (build_ensemble_estimate.R -> harmonized_best_estimate.csv; method in
  ENSEMBLE_METHOD_2026-06-11.md): equal-weight (primary) + benchmark-informed (down-weight FVS-West and
  CEM, sensitivity). 90% credible interval = sqrt(between^2 + within^2 + anchor^2). CONUS reserve best
  estimate (disturbance-aware): 2025 15.3, 2050 19.9, 2075 22.6, 2100 23.5 Pg C. Per-state 2100 e.g.
  IN 310 [33,587], OH 438 [65,811], NH 202 [65,340], GA 951 [766,1137], CA 1584 [0,3683], OR 1758 [122,3393].

## 5. External validation

Benchmarked against the American Forests state CBM reports (MN, OR, CA, MD, PA). Reports project western
decline (OR -> net source 2029, +825% fire) and eastern near-saturation; our no-disturbance reserves grow,
which exposed the CBM under-init and motivated the disturbance overlay. Direction/magnitude agree where the
overlay applies. See BENCHMARK_VALIDATION_2026-06-10.md, americanforests_cbm_benchmarks.csv.

## 6. Key artifacts (landis2HPC/harmonized/ unless noted)

Reserves: {fvs_reserve_calibrated,fvs_reserve_default,cbm_reserve,yc_reserve}_anchored.csv,
harmonized_landis_reserve_9state.csv, cem_reserve_anchored.csv (+ *_disturbed.csv each).
Summaries: harmonized_carbon_npv_*.csv. Comparison: harmonized_crossmodel_5model.csv,
harmonized_crossmodel_ci.csv, reserve_growth_crossmodel.csv, harmonized_best_estimate.csv.
Uncertainty: uncertainty_by_state_year{,_disturbed}.csv, uncertainty_conus{,_disturbed}.csv,
cbm_oat_bands.csv, yc_bands.csv, fvs_posterior_ci_all.csv, fig_uncertainty_{A,B,C}*.png,
fig_disturbance_compare.png. Scripts: build_cbm_reserve.R, apply_disturbance_overlay.R,
derive_disturbance_rates.py, build_crossmodel_ci.R, build_ensemble_estimate.R, uncertainty_ensemble.R,
stress_test_harmonized.py, benchmark_validation.py, cbm_init_diagnostic.py, make_sdifix_configs.py.
Docs (landis2HPC/docs/): HARMONIZED_ASSESSMENT_REPORT_2026-06-11.md, ENSEMBLE_METHOD_2026-06-11.md,
BENCHMARK_VALIDATION_2026-06-10.md, FVS_SDIMAX_AUDIT_2026-06-10.md, FVS_DG_ADOPTION_GAP_2026-06-10.md.

## 7. Running background jobs (2026-06-11)

- gom_v4dg (FVS full-CONUS DG-adopted re-run -> out_gompit_v4): ~25 running, 1 pending; eastern states
  pending. When done: Rscript build_fvs_reserve_v4.R, then re-run build_crossmodel_ci.R /
  build_ensemble_estimate.R / uncertainty_ensemble.R and recheck the East.
- CBM OAT, NH/VT statewide: complete. (Other jobs cspi/v7/gee/v_hybrid are unrelated raster work.)

## 7b. FINALIZED all-scenarios CONUS matrix (2026-06-11)

`build_master_scenarios.R` consolidates every model x scenario x state x disturbance mode:
`harmonized_master_all_scenarios.csv` (long: model, dist_mode, state, scenario, total/forest/hwp/npv),
`harmonized_ensemble_by_scenario.csv` (per state x mode x scenario ensemble equal+benchmark + 90% CI),
`harmonized_conus_by_scenario.csv` (CONUS rollup). Ensemble median CONUS 2100 total carbon (Tg C):
  nodisturb: reserve 24,294 / conservation 22,261 / BAU 20,218 / intensive 17,860
  disturbed: reserve 23,074 / conservation 21,061 / BAU 19,040 / intensive 16,714
Monotonic harvest gradient (~26% reserve->intensive); disturbance overlay -5% per scenario. Western
scenario response near-flat (harvest under-detection caveat). The Word report
(Harmonized_Assessment_Report_2026-06-11.docx) now includes this matrix.

## 7c. HWP accounting + CEM/LANDIS finalization (2026-06-11) - see HWP_AND_COVERAGE_FINALIZATION

HWP: long-term product storage IS apples-to-apples - one common first-order IPCC Tier-2 HWP model
(HWP_FRAC 0.5, long-lived 35yr + short 4yr + landfill 100yr) applied to EVERY model's removed carbon;
total = forest + in-use HWP + landfill. We deliberately do NOT use each model's native HWP (would
confound the comparison). Substitution benefit NOT included (optional extension).
CEM FINALIZED: extended 2095 -> 2100 by linear extrapolation of the last cycle (26 states); master/stress
refreshed, passes. Partial-coverage (26 states), enriches per-state ensemble, doesn't gate CONUS.
LANDIS FINALIZED: locked at 9 states as a regional cross-check (full CONUS impractical: ~20h calibration
per state). Expansion via the onboarding recipe; best next adds are CEM-covered states (KY/MD/WV/NJ).
CONUS-WIDE projection is COMPLETE on the 3 full-coverage models (FVS/YC/CBM, 48 states) x 4 scenarios x
2 disturbance modes; CEM/LANDIS are partial-coverage checks.

## 8. Open items / refinement queue (priority)

1. Finish the full-CONUS FVS v4 re-extract (eastern), refresh ensemble/CI/best-estimate.
2. LANDIS replicate band (seed-varied statewide reruns) + a CEM scenario-uncertainty term -> all 5
   models with a measured within-model SD.
3. Better western harvest layer (LCMS/FIA TPO) so western scenario contrast + the OR 45% benchmark are testable.
4. True FIA-initialized CBM run (replace the interim entry-point correction).
5. Calibrate disturbance rates against MTBS/LANDFIRE burned-area + severity.
6. More LANDIS states (full onboarding: IC build, ~20h calibration, statewide) to widen 5-model overlap.
7. Bayesian model averaging (continuous benchmark-skill weights) for the ensemble.
8. Convert HARMONIZED_ASSESSMENT_REPORT to a formatted docx for circulation.

## 9. Recipes (quick)

- New LANDIS state: build_plot_scenario_<ST>.sh + apply_theta_<ST>_perspecies.py + SppEcoregionData
  baseline -> calibrate (cma_es) -> run_statewide_buildfresh.sh <ST> theta_best.csv reserve_v1 ->
  add to harmonized_landis_reserve via the add_nh_vt pattern.
- CBM OAT: PATH=cbm_maine/envs/libcbm/bin; python run_oat_sensitivity.py <ST> --base business_as_usual --years 76.
- FVS DG adopt a variant: enable DG in equation_availability_full.csv; FVS_PROJECT_ROOT=fvs-modern
  Rscript calibration/R/06_posterior_to_json.R --variant <v>.
- Re-stress everything: python3 stress_test_harmonized.py (0 failures = pass).
