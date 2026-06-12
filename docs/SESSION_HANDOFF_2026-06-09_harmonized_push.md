# Harmonized multi-model push — session handoff (2026-06-09)

**Repo:** github.com/holoros/landis2HPC | **Cardinal:** PUOM0008, scratch `/fs/scratch/PUOM0008/crsfaaron`

Consolidated state after a long working session. Covers the WI/MI fix, the CONUS
onboarding toolkit, the cross-model results now in hand, and the in-progress ME
oak extension with its exact resume recipe.

## 1. What shipped and is verified

**WI/MI LANDIS fixed.** Root cause was a missing `states/{WI,MI}/inputs/SppEcoregionData.csv`
(apply_theta FileNotFoundError -> empty per-plot SppEco -> header-only stubs) compounded
by `build_plot_scenario_{MI,WI}.sh` only handling ecoregions 46-52. Built the baselines
(MN-flora, uncovered southern ecoregions inheriting MN ecoregion-51), patched the build
scripts, validated 6 plots, cleared 1,697 stale stubs, relaunched. Both states now carry
real trajectories. Detail: `docs/SESSION_HANDOFF_2026-06-09_WIMI_fix.md`.

**conus_tools/ toolkit (new).** Generalizes the failure class so it cannot recur:
`conus_preflight.R` (per-state ecoregion/baseline/build/theta readiness, exit 1 on any
FAIL), `compose_sppeco_baseline.R` (fill baseline gaps from a same-flora donor, provenance
logged), `extract_eco_crosswalk.R` + `resolve_eco.sh` + `ecoregion_names.csv` (data-driven
build resolution), `build_plot_ics_N1.py` (Northeast IC builder), `validate_ic_coverage.R/py`
(zero-drop species-map check). The preflight immediately caught and we closed latent gaps
on GA (ecoregion 68) and OH (ecoregion 83). README in `conus_tools/`.

**FVS confirmed apples-to-apples with LANDIS.** Both use the same FIA design anchor
(`fia_agc_anchor_design_by_state.csv`), the same ratio anchor (units/carbon-fraction
cancel), and the same `apply_harvest_scenarios.R` engine. Only the reserve dynamics differ.

**Cross-model results (common FIA anchor + common HCS harvest):**

LANDIS now 7 states (added WI, MI, and ME via log extraction). Yield curves re-anchored
to the FIA design under the common harvest across 48 states, which resolved the old
native-harvest artifact (yield-curve intensive was -73% vs reserve under native harvest;
it is -30% under common harvest, against FVS -21%). Files in `harmonized/`:
`harmonized_carbon_npv_7state.csv` (LANDIS), `harmonized_crossmodel_3model_7state.csv`
(LANDIS/FVS/yield-curve), `harmonized_crossmodel_FVS_YC_CONUS.csv` (48-state FVS vs YC).
2100 reserve total-carbon ratios LANDIS/FVS: ME 2.14, MN 2.16, WI 1.98, IN 1.86, MI 1.62,
OH 1.54, WA 0.60 (FVS higher in the PNW). The `landis_param_basis` column flags WI/MI as
carrying the MN-51 borrowed parameters; WA, MN, IN, OH, ME are native.

## 2. ME oak extension — IN PROGRESS (resume here)

ME's 13-species Acadian pool omits oak/hickory (Maine is north of the oak zone), which is
fine for ME alone but blocks the N1 cluster (NH/VT/MA/CT need oak). Decision: extend the
N1 pool with oak before onboarding NH/VT.

**Done and verified:**
- `conus_tools/build_plot_ics_N1.py` extended with RO (red-oak group: SPCD 802/806/812/823/832/833/837)
  and HICK (hickory: 400/401/402/403/407/409); black cherry 762 -> IH, sweet birch 372 -> YB.
  Coverage of live AGB rose to ME 99.1% (was 94.4%), NH 99.0% (was 83.0%), VT 97.9% (was 90.5%).
- ME inputs extended with RO/HICK and backed up (`*.backup_20260609`): `states/ME/inputs/`
  `species.txt`, `SpeciesData.csv`, `SppEcoregionData.csv`. Traits from OH NRO/SHA_HK;
  productivity = ME SM/RM scaled by OH oak:SM (1.05 ANPP, 1.13 BMAX) and hickory:RM (1.0/1.07)
  ratios, so the new species sit on ME's northern scale. Establishment RO 0.060, HICK 0.030.
  Provenance: `states/ME/inputs/RO_HICK_provenance.md`.
- ME ICs rebuilt with the extended map -> `states/ME/perseus/round2_plot_ics_v3/`
  (3,632 plots, 422 now carry oak/hickory cohorts; sample plot_1003 has RO at 250 and 1,154 g/m2).

**ME oak re-run: BLOCKED and abandoned (2026-06-09, smoke test caught it).**
The calibrated `bayesian/eco_v2/SppEcoregionData_eco_v2.csv` that produced ME's existing
`round2_runs_eco_v2` outputs is deleted (dangling symlink) and is NOT reconstructable from
surviving files. Verified by re-running plot 1003 against the existing log:
- inputs x per-eco multiplier: total off -8.7%, HE +393%, BE -36%.
- calibrated `round2_t2_climfix/SppEcoregionData_baseline_t2.csv` as-is: PINE 3,911 vs
  existing 9,310; HE 3,798 vs 492.
- same x per-eco multiplier: RM 22,667 vs 14,037; HE 4,839 vs 492.
None match (PINE off ~2.4x, HE off ~8x), so the eco_v2 per-species calibration is lost.
Re-running ME from any available base would corrupt its validated 13-species reserve.

DECISION: leave ME at 13 species in the cross-model comparison. Its red oak (~5% of AGB) is
captured in the carbon LEVEL by the FIA design anchor; only post-2025 dynamics omit it, a
bounded documented limitation. Retrofitting oak would need a full multi-day re-calibration
of the lost eco_v2 and is not worth it for the reference state.

The oak work is NOT wasted: it is for NH/VT (and other N1 states), which calibrate FRESH via
add_state.sh and so include oak from the start using the extended `build_plot_ics_N1.py` and
the extended ME inputs as the N1 reference pool. ME inputs were left at 15 species (backups at
`states/ME/inputs/*.backup_20260609`) to serve as that reference; ME's own results stay
13-species. Scratch from the attempt is under `states/ME/perseus/_fidelity_smoke/`.

**NH onboarding — ~90% wired (2026-06-09), gated on per-plot scaffold + 1-plot validation):**

Done and verified:
- `tools/plot_to_ecoregion_NH.csv` built via `build_plot_to_ecoregion_shp.py` run INSIDE the
  apptainer SIF (osgeo is only in the container, not base python). NH falls entirely in
  ecoregions 58 (1,162 plots) and 59 (180), both already in ME's N1 pool, so NH needs no
  new ecoregions, species, SppEco, or climate.
- `states/NH/inputs/` wired as symlinks to ME's extended N1 reference (species.txt,
  SpeciesData.csv, SppEcoregionData.csv, ecoregions.txt, climate_template.csv->PRISM_ME_l3.csv).
- NH ICs built with the extended N1 map: `states/NH/perseus/plot_ics_full/` (1,344 plots,
  1,126 non-empty, oak-inclusive). `tools/build_plot_scenario_NH.sh` + `apply_theta_NH_perspecies.py`
  generated from the N1 templates. NH plot-list: `states/NH/perseus/plotlist_nh.csv`.

The single-plot validation (the gate) caught that the GENERIC `build_plot_scenario_template.sh`
does not match ME's actual working format on two points, so do NOT use it as-is for N1:
1. ecoregions.txt: the template's name lookup emits an extra/duplicated field (LANDIS
   "extra data after Description" error). ME's working file simply lists all of 58/59/82 as
   `yes <code> <code> "<Name>"`; the 1-cell raster selects the active eco. Use ME's file.
2. climate: the template transposes a long-format climate; ME instead feeds the WIDE
   `PRISM_maine_l3.csv` (Year,Month,Variable,58,59,82) DIRECTLY via a `ClimateGenerator.txt`
   (Monthly_AverageAllYears). No transpose. Use ME's approach.

CORRECTED FINISH for NH (and the N1 pattern): build per-plot scenarios by cloning ME's
working run-dir scaffold (`round2_runs_eco_v2/plot_*__clim_baseline_harv_none`: scenario.txt,
biomass_succession.txt, biomass-succession_ClimateGenerator.txt, ecoregions.txt, PRISM file,
SppEco/species symlinks) and swapping in NH's oak IC + the plot's 1-cell eco raster. Then:
(a) validate ONE NH eco-58 plot end to end, confirm a real trajectory and that oak (RO) is
present where the IC has it; (b) submit the N1 calibration via `cma_es_optimize_N1.py`
(symlink to `cma_es_optimize_cluster.py`) warmstarted from `state_templates/cluster_N1_reference_theta.csv`;
(c) repeat for VT (FIPS 50; build its plot_to_ecoregion the same way, expect ecos 58/59/82
and possibly 83 — if 83 appears, add it to the N1 SppEco/climate first, it is in
ecoregion_names.csv). The chains run ~2 days.

The N1 template should be hardened to match ME's working format (items 1-2) so future N1
states onboard without re-deriving this.

## 3. LANDIS onboarding gate (for NH/VT and beyond)

`add_state.sh` warmstarts a ~1.5-day CMA-ES chain per state. Optimizers exist for all 13
clusters. The gate is the per-cluster IC builder with a curated FIA SPCD->LANDIS species
map: only MN, GA, WA, N3 had one; N1 now built. Every other path falls back to the MN map
and silently drops non-Lake-States flora. Cluster references frozen: N1 (ME), N2 (MN),
N3 (IN/OH provisional), S1 (GA), P3 (WA). Clusters N4/S2/P1/P2/R1-3/P4 still need literature
parameterization. Per-state full FIA (with SPCD) is in scratch `FIA/<ST>_TREE.csv`; the
`fia_by_state/` extracts have no SPCD.

## 4. Next steps (priority)

1. Finish the ME oak re-run (section 2), then re-verify the 7-state cross-model table.
2. Onboard NH then VT off the extended N1 reference (build_plot_ics_N1.py + add_state.sh,
   validate zero-drop with validate_ic_coverage first), submit calibration chains.
3. Remaining ready-cluster states (S1: FL/SC/NC/AL off GA; P3: OR/ID off WA) need their
   cluster IC builder wired (GA/WA builders use a `--tree/--plot-list` interface that
   add_state.sh does not call; reconcile that), then onboard.
4. CEM and CBM onto the common per-plot pipeline for the five-model frontier.
5. Replace the $14/m3 synthetic stumpage with regional series; regenerate NPV.
