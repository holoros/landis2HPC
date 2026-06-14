# GCBM CONUS run status and the per-state parameterization gates

Date 2026-06-13. Progress and the honest boundaries for extending the GCBM spatial run
beyond Maine.

## Done
- Source stacks built for MN, WA, OR, CA, GA (build_state_gcbm_stack.R, from CONUS TreeMap).
- Per-state climate derived (state_mat_prism.csv; PRISM 30-yr normals): MN 5.2, WA 8.5,
  OR 8.7, CA 14.6, GA 17.8 degC. Maine is 5.67; using it elsewhere would bias growth.
- Tiling complete for all 5 states (build_inputs_state.sh + tile_inputs_wave.sh): WGS84
  1deg / 4000x4000 tiles, with the correct per-state MAT. Tile counts (5 layers each):
  MN ~80, WA ~77, OR ~108, CA ~196, GA ~56 spatial tiles.
- stage_maine_singletile.py made env-configurable: GCBM_TILED_SRC (which tiled stack) and
  GCBM_INPUT_DB (which growth-curve DB). Backup .bak_pre_envgen. So the run launcher is ready.

## The remaining gate: per-state GCBM input database (growth curves)
The GCBM run reads a state growth-curve database (gcbm_input_maine.db) built by
build_gcbm_input_maine.py. That builder is intrinsically state-specific: it hardcodes Maine
forest-type-group classifier values, Maine growth_curve rows per (forest_type x ecoregion),
species-composition mappings per FIA group, and clones New Brunswick vol_to_bio factors into
Maine's spatial unit. Running MN/WA/OR/CA/GA with Maine's DB would apply Maine growth curves
and biomass factors to other states = wrong science. So the GCBM run arrays gate on a
per-state gcbm_input_<ST>.db carrying that state's growth curves (from the state libcbm/FIA
volume fits and the correct CBM spatial unit vol_to_bio associations).

This is the GCBM analog of the LANDIS Plains/Rockies species step and the MAT step: a genuine
per-state domain input, not something to default from Maine. It is the CBM-team build step.

Once a state's gcbm_input_<ST>.db exists, launching is mechanical:
  GCBM_TILED_SRC=.../gcbm_<ST>_tiled/layers/tiled  GCBM_INPUT_DB=gcbm_input_<ST>.db
  array over the state tile list (run_maine_statewide.sh pattern), then retain_maine_rasters.sh
  + gcbm_me_spatial_summary.R adapted per state -> measured engine gap in cbm_engine_gap.csv.

## Maine spatial LANDIS (separate track) - GRID REBUILT, deck blocker remains
GRID REBUILD DONE (2026-06-13). Sequence of fixes after the cleanup deleted this run's inputs:
1. Source stack was dangling symlinks (maine_*.tif deleted) -> regenerated real files via
   build_state_gcbm_stack.R ME (gcbm_rasters_2022_ME, EPSG:5070 30m, 10981x17120).
2. Rebuilt the initial-communities raster on that grid (build_initial_communities.R with
   ME_TM_22.tif symlinked to me_treemap_tmid.tif) so IC and ecoregion share one grid.
3. Ecoregion cast in place with nodata 65535 -> 0 remap (codes 58/59/82 + 0).
4. MEMORY WALL: full-state 30m = 75.1M active cells -> LANDIS-II Biomass Succession crashes
   silently allocating per-cohort biomass (this is WHY the original ME LANDIS used the per-plot
   harness, not a 30m landscape). Fixed by coarsening IC + ecoregion to a matched 270m grid
   (CellLength 270): 2.32M cells, 927,667 active. Landscape now initializes cleanly and loads
   Biomass Succession. Carbon density (Mg/ha) is resolution-independent, so the spatial-vs-plot
   structural comparison still holds at 270m.

DECK PROGRESS (2026-06-13, second push): the succession file now parses. Authored
biomass_succession_me_l3.txt (valid Biomass Succession 7.0 structure: CalibrateMode,
MinRelativeBiomass keyword + table, SufficientLight, inline SpeciesParameters for the 13
SL2025 species, EcoregionParameters) and confirmed it clears the MinRelativeBiomass parse that
broke the v8 file. Remaining hard requirement found: Biomass Succession 7.0 REQUIRES a
ClimateConfigFile, and the SL2025 climate (PRISM_data_AFRI_4.18.13_v2.csv) is ECOREGION-KEYED to
codes 101-240 (columns 101,102,...). So the whole deck - ecoregion map, MinRelativeBiomass,
EcoregionParameters, AND climate - must use the native 101-240 climate-ecoregion scheme; the EPA
L3 58/59/82 shortcut cannot work (no climate columns for 58/59/82).

EXACT REMAINING RECIPE (full 101-240 reconstruction, a dedicated task not a quick fix):
1. ecoregions: resample the Dryad ecoregions.img (101-240, 7456x8481 30m) to 270m -> ecoregions.tif;
   ecoregions.txt = Dryad 101-240.
2. biomass_succession: expand biomass_succession_me_l3.txt MinRelativeBiomass + EcoregionParameters
   from 3 columns to the 80 ecoregions (101-140, 201-240), same universal values; keep ClimateConfigFile.
3. climate: stage biomass-succession_ClimateGenerator.txt + PRISM_data_AFRI_4.18.13_v2.csv (101-240 keyed).
4. IC: reproject the rebuilt TreeMap IC raster to the Dryad 270m grid (co-register with the ecoregion
   map); keep my initial_communities.txt (mapcodes are independent of ecoregion codes).
5. species.txt (the 13 SL2025 species, present in v8/Dryad). scenario CellLength 270, Duration 75, reserve.
The IC mapcodes and ecoregion codes are independent layers, so my TreeMap IC + the 101-240 ecoregion
map can coexist once co-registered. This is the clean path; it needs ~1 focused session, not a quick push.

## 2026-06-14 reconstruction progress: deck parses through ~85%, landscape initializes
Executed the full 101-240 reconstruction (run_me_spatial_101_240.sh, job chain 11555975 -> 11566986):
- Ecoregion: Dryad ecoregions.img warped to 270m UTM19N, clamped to 0/101-240 (R/terra, gdal_calc.py
  absent). IC: my TreeMap IC reprojected to the IDENTICAL grid (mode), clamped. Both co-registered:
  942 x 828, 779,976 cells, 421,442 active. Memory wall solved (vs 75M at 30m).
- Climate: built climate_me_80eco.csv (replicated the AFRI monthly series across all 80 codes 101-240;
  uniform-climate assumption, defensible for a reserve structural comparison).
- Deck: staged the v8 deck (SpeciesData.csv, SppEcoregionData.csv, species.txt 9-col, IC CSV) on a
  bare-code ecoregions.txt (names 101-240, matching the v8 tables, SppEcoregionData, and climate).
RESULT: the landscape now initializes cleanly and the succession file parses through MinRelativeBiomass,
SufficientLight, SpeciesDataFile, EcoregionParameters, and SpeciesEcoregionDataFile (to ~line 122 of 142).
REMAINING: the v8 succession file (older binary) omits section KEYWORDS the current Biomass Succession
7.0.0 binary requires. I inserted the ones the errors named (CalibrateMode, MinRelativeBiomass,
SufficientLight); the run now stops at "expected FireReductionParameters" - the trailing
FireReductionParameters + light-establishment + harvest-reduction blocks need their exact 7.0.0 keywords
and ordering from the Biomass Succession v7 user guide, not error-by-error guessing. That is the only
remaining gap; everything upstream (grid, IC, ecoregion, climate, species, MinRelativeBiomass,
SufficientLight) is solved. Driver + all inputs are staged at landis2/tools/run_me_spatial_101_240.sh and
the run dir maine_spatial_101_240, ready to finish once the trailing-block keywords are confirmed.

SUPERSEDED quick-fix note: the v8 reference deck is internally inconsistent.
biomass_succession.txt lacks the required CalibrateMode / MinRelativeBiomass keywords, and its
parameter tables are keyed to ecoregion codes 101-240 while ecoregions.txt uses EPA L3 codes
58/59/82. The original deck that reconciled the ecoregion scheme (maine_v1_5_epa_l3) was deleted
in the same cleanup. Completing the run needs a consistent Maine LANDIS deck (succession file
with valid keywords + SppEcoregionData + ecoregions.txt all on one ecoregion scheme) - a LANDIS
deck-reconstruction task, not a grid or memory fix. Stopped resubmitting to avoid thrashing.
The per-plot LANDIS member (the cross-model comparison) is unaffected.

## What is safe to run on autopilot now
The CEM 48-state array and its re-adapt; LANDIS calibration-wave integration; refreshing the
ensemble/CI/master. NOT the GCBM run arrays (need per-state DBs) and NOT the spatial LANDIS
(needs the IC+ecoregion grid rebuild). The daily monitor has been updated to respect both gates.
