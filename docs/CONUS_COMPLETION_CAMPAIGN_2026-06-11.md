# CONUS completion campaign: CEM and LANDIS to all 48 states

Date 2026-06-11. Goal: fully harmonized model runs across CONUS for all five models, same scenarios,
uncertainty quantified. FVS, yield curves, CBM already cover 48 states. This campaign brings CEM and
LANDIS to 48 with native 2100 horizons.

## CEM -> 48 states, native 2100 (16-cycle)

LAUNCHED (job 11505310 array 1-47 + 11505312 for MS = all 48). Per state:
  Rscript run_projection.R --state <ST> --n_sims 100 --cycles 16 --cores 32 --scenario_set harvest \
    --tag conus2100_<ST> --save_per_plot --use_brms_sdimax
`--cycles 16` reaches 2100 (vs the prior 15-cycle 2095, which we had been extrapolating); `--use_brms_sdimax`
draws each state's max-SDI from the CONUS brms lookup, so it works for every state (the 4-row state_constants
table is only the seed states). himem 180G, 32 cores, ~6-20 h/state, throttled %10. Submit:
fia_cem_projections/submit_cem_conus2100.slurm + cem_conus2100_states.txt.
WHEN DONE: re-run build_cem_reserve.R (point at the new conus2100_<ST> dirs) -> 48-state CEM reserve to a
NATIVE 2100 (drops the extrapolation), then re-run the disturbance overlay, harvest scenarios, master.
DONOR-POOL NOTE: production uses a regional + stratified donor pool (not full-CONUS, not same-state);
donor scope is a real intra-CEM uncertainty (~10% in mismatched cases, e.g. GA plantation bias) - see
HWP_AND_COVERAGE_FINALIZATION.

## LANDIS -> 48 states via cluster warmstart (add_state.sh)

LANDIS uses `tools/add_state.sh <FIPS> <ST> <CLUSTER>`: stages FIA, builds the SppEcoregionData baseline +
apply_theta + build_plot_scenario from the cluster reference theta, and submits the T2 calibration chain
(~1.5 days/state). Clusters defined in docs/conus_ecoregion_clusters.md (13 clusters, each warmstarts from a
reference state). Ready references (frozen): N1(ME), N2(MN), N3(IN), S1(GA), P3(WA-Pacific).
FIA download from the datamart fails on Cardinal (no outbound net) - PRE-STAGE by symlinking the CEM
project's per-state tables: ln -sf ~/fia_data/<ST>_*.csv landis2/FIA/<FIPS>/ (then add_state skips the download).

WAVE 1 LAUNCHED + DONE (setup): NY(N1), KY/TN/MO/IL(N3), FL/AL/MS/LA/SC/NC(S1), OR(P3) - 12 states, T2
chains submitted (e.g. NY job 11505340). WAVE 2: CA(P3), IA(N3) (CA FIA partial in fia_data - verify).
Already done (9): WA MN OH IN WI MI ME NH VT.
REMAINING CLUSTERS need their reference theta frozen first (calibrate one seed state per cluster), then
members: N4 (PA,NY-low,NJ,MD,DE,VA,WV; blend IN+ME), P1 (KS,NE,OK,e-CO,e-NM,e-TX; blend MN+IN +bur oak/
redcedar/post oak), P2 (ND,SD,e-MT; blend MN), R1 (ID,w-MT,WY; WA+lodgepole/subalpine fir/etc.),
R2 (CO,NM,AZ,UT; WA+IN +pinyon/juniper/aspen), R3 (NV; sparse juniper-pinyon), S2 (NC,SC-up,e-TN,e-KY,WV,
w-VA,n-AL; blend GA+IN). Freeze each cluster ref by running add_state on the reference state to convergence,
copy its theta_best -> tools/state_templates/cluster_<C>_reference_theta.csv, then onboard members.

## Integration (when runs land)

- LANDIS: each state's T2 chain -> theta_best.csv -> run_statewide_buildfresh.sh <ST> theta_best.csv
  reserve_v1 -> add to harmonized_landis_reserve via the add_nh_vt pattern (extend to N-state).
- CEM: re-adapt all 48 from conus2100 dirs -> native 2100 reserve.
- Then refresh: apply_disturbance_overlay, apply_harvest_scenarios, build_master_scenarios,
  uncertainty_ensemble, build_crossmodel_ci, build_ensemble_estimate, stress_test_harmonized.
- LANDIS replicate band (seed-varied statewide reruns) becomes feasible at scale -> intra-LANDIS CI,
  closing the last anchor-only model.

## GCBM refinements (CBM is two engines, not one)

Our harmonized CBM uses libcbm (SIT, stratum-based: pools_<ST>_BAU). The cbm_maine pipeline also has a
GCBM (spatially explicit, tiled) engine (env + github.com/holoros/GCBM2hpc). The CBM team documented a
structural GCBM-vs-libcbm ENGINE GAP (HANDOFF.md): GCBM projects HIGHER stock density than libcbm by
+21% (ME), +24% (MN), +26% (WA), with GA near-parity (-5%). They concluded it is a stock-density methods
phenomenon (spatial vs stratum), NOT a disturbance-horizon artifact (within-libcbm disturbance is <=4.1%
total C at year 50, second-order).

Implications / refinements:
1. BIGGEST: the engine gap (+21-26% in N/W states) DWARFS our CBM intra-model band (OAT ~3%). Our CBM
   member uses libcbm = the lower engine, so it likely understates CBM. The refinement is to run GCBM as a
   second CBM realization and carry the libcbm-vs-GCBM gap as the dominant intra-CBM uncertainty (or pick a
   reference engine explicitly). This is ~7x larger than the band we currently report for CBM.
2. NATIVE SPATIAL DISTURBANCE: 04_disturbance_history ingests MTBS (fire) + LCMS natively, so GCBM can run
   observed spatial disturbance per pixel-year instead of our first-order overlay - more accurate for the
   western fire escalation. (Caveat: the team found CBM-internal disturbance second-order, <=4%/50yr, so
   the overlay and native disturbance are both modest in CBM; the engine gap is the larger effect.)
3. EASTERN INIT: the entry-point under-initialization correction we applied to libcbm should be checked on
   the GCBM spin-up too (cbm_init_diagnostic.py logic).
4. HWP: GCBM has its own HWP module (06_hwp_module); we override with the common HWP for apples-to-apples -
   keep that for the comparison.
Recommendation: run the GCBM2hpc statewide chain for the harmonized states, report libcbm and GCBM as the
CBM engine envelope, and fold the +21-26% gap into the CBM uncertainty.

APPLIED (2026-06-11): the engine gap is now folded into the CBM uncertainty band. `cbm_engine_gap.csv`
(build_cbm_engine_gap.py) gives per-state GCBM-over-libcbm % (measured ME21/MN24/WA26/GA-5; regional
defaults by forest type: W conifer ~26, N mixed ~22, SE pine ~0, Central/Plains ~12). build_crossmodel_ci.R
and build_ensemble_estimate.R now combine the OAT band with |gap|/100/1.645 in quadrature for CBM. Effect:
CBM CI widens substantially (e.g. NH CBM [206,224] -> [167,263]); CBM now overlaps a neighbor at NH (14/15
distinguishable, was 15/15), honestly reflecting that the engine choice is the dominant intra-CBM
uncertainty (~7x the OAT band). STILL TO DO: the actual GCBM CONUS run (spatial-tiling campaign on the
GCBM2hpc toolchain) to replace the regional-default gaps with measured per-state values + spatial MTBS
disturbance.

## GCBM spatial rasters — yes, retain them (currently discarded)

GCBM (moja FLINT) natively writes SPATIAL rasters via the `WriteVariableGeotiff` output module: one
GeoTIFF per variable per tile per timestep (output/<Variable>/<tilex>_<tiley>/<Variable>_<x>_<y>_<step>.tif),
for indicators like aboveground biomass C, total ecosystem C, NPP, and disturbance flux, per pixel per
5-yr step per scenario. The cbm_maine GCBM run dirs (10_outputs/perseus_gcbm/{noharvest,harvest}_{noclimate,
rcp45,rcp85}) exist but are EMPTY: the pipeline currently runs `tools/gcbm_maine/aggregate_geotiffs.py`,
which area-weights the per-tile rasters into a state CSV and the raw GeoTIFFs are not kept.

To RETAIN them for the harmonized assessment + archive:
1. In the GCBM run config keep the per-tile GeoTIFF output tree (do not clean output/<Variable>/ after
   aggregation).
2. Mosaic the per-tile-per-step GeoTIFFs into full-extent rasters per variable per year (gdal_merge /
   gdalbuildvrt, or extend aggregate_geotiffs.py to emit a mosaicked GeoTIFF alongside the CSV).
3. Retain at minimum: aboveground live C (the harmonized comparable), total ecosystem C, and disturbance
   flux, per 5-yr step x scenario.
4. ARCHIVE with the zenodo-deposit skill (built for moving large Cardinal rasters to a public archive):
   mint a DOI, FAIR-compliant, data on Dryad/Zenodo at publication (matches the cbm_maine data plan).
This gives the assessment a spatial layer (carbon maps by scenario) complementing the state aggregates,
and is the natural way to publish GCBM. Enable it in the GCBM2hpc CONUS run config when that campaign runs.

## LANDIS wave progress (2026-06-11)

33 of 48 states now in the LANDIS pipeline (all floristically compatible with a ready cluster reference):
- Integrated (9): WA MN OH IN WI MI ME NH VT.
- Calibrating (24): wave1 NY KY TN MO IL FL AL MS LA SC NC OR; wave2 CA IA; wave3 PA NJ MD DE VA WV MA CT RI;
  wave4 AR. All via add_state.sh cluster warmstart (N1 ME / N2 MN / N3 IN / S1 GA / P3 WA), FIA pre-staged
  from ~/fia_data (datamart download blocked on Cardinal). T2 chains ~1.5 days each.
- REMAINING 14 (Plains + Rocky Mountain): KS NE OK ND SD MT CO NM AZ UT WY NV ID TX (+ GA needs statewide
  integration from its existing S1 reference theta). These clusters (P1,P2,R1,R2,R3) have NO frozen
  reference theta and need their EXTENSION-SPECIES literature (bur oak, eastern redcedar, post oak,
  lodgepole/subalpine fir/limber pine/Engelmann spruce/ponderosa, pinyon/juniper/aspen) parameterized
  before onboarding - a per-cluster domain step (don't warmstart plains/dry-conifer from eastern/MN floras;
  the species pools differ). Bootstrap path: author cluster_<C>_extension_species.csv + seed reference theta
  (blend parent thetas), calibrate one seed state per cluster, freeze its theta as cluster_<C>_reference_theta.csv,
  then onboard the members via add_state.sh.

## Status snapshot

CEM 48-state native-2100 array running; LANDIS 24 states calibrating + 9 integrated (33/48); GCBM engine
gap folded into the CBM uncertainty. Monitor: squeue (cem2100, *_t2_v1); check_t2v2_chains.sh for LANDIS.
INTEGRATION as each lands: LANDIS theta_best -> run_statewide_buildfresh -> add_nh_vt pattern; CEM -> re-adapt
conus2100. The CONUS-wide 3-model backbone (FVS/YC/CBM, all scenarios x disturbance modes, CIs, ensemble) is
already complete; these campaigns deepen LANDIS/CEM toward all-five-models-everywhere. Remaining manual steps:
14 Plains/Rockies LANDIS clusters (extension-species literature) and the GCBM spatial CONUS run (with raster
retention + Zenodo deposit).
