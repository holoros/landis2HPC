# GCBM spatial run + Plains/Rockies LANDIS clusters

Date 2026-06-11. Two final campaigns toward all-five-models-everywhere: the GCBM spatial
realization (with retained rasters) and the 5 Plains/Rockies LANDIS clusters.

## 1. GCBM spatial run — LAUNCHED with raster retention

The harmonized CBM member uses libcbm (SIT, stratum-based). GCBM (moja FLINT, spatially
explicit) is the second CBM engine, +21-26% higher stock density in N/W states (the
dominant intra-CBM uncertainty, folded in via cbm_engine_gap.csv). This campaign runs the
actual spatial GCBM and KEEPS the rasters.

Readiness confirmed on Cardinal (cbm_maine):
- Apptainer image PRESENT: data/external/gcbm_containers/flint_gcbm_fixed.sif (688M).
- Maine tiled input stack PRESENT: data/processed/gcbm_maine_tiled/ (128 GeoTIFFs, db,
  configs, layers). WGS84, 1-deg tiles, 4000x4000 cells.
- WriteVariableGeotiff output module already ENABLED in configs/modules_output.json for
  Age, AG_Biomass_C (aboveground live C = the harmonized comparable), Total_Ecosystem_C.

Launched:
- Job 11505497 — run_maine_statewide.sh, 20-tile SLURM array (lon -71..-68 x lat 43..47),
  GeoTIFF-only output per tile to runs/gcbm_maine_statewide_<tx>_<ty>/output/<Variable>/.
- Job 11505514 — retain_maine_rasters.sh, dependency=afterany:11505497. Runs
  mosaic_retain_gcbm.py: mosaics the per-tile, per-step GeoTIFFs into full-extent Maine
  rasters per variable per year (gdalbuildvrt -> LZW GTiff + overviews) into
  /fs/scratch/PUOM0008/crsfaaron/FIA/gcbm_rasters/ME. This closes the gap the prior pipeline
  left (it only ran aggregate_geotiffs.py -> CSV and never mosaicked/kept the rasters).

Result when complete: the first MEASURED GCBM realization for the harmonized assessment
(replaces the regional-default +21% engine gap for ME with a measured spatial value) AND a
retained spatial carbon layer (AG live C, total ecosystem C maps by 5-yr step), ready for
the zenodo-deposit skill (DOI, FAIR archive). CONUS extension = building the tiled input
stack per state (build_inputs.sh), then the same array+retain pattern; Maine is the pilot
that verifies the retention path end-to-end.

Scripts (landis2HPC/harmonized/): mosaic_retain_gcbm.py (staged on Cardinal at
tools/gcbm_maine/; retain_maine_rasters.sh authored there too).

## 2. Plains/Rockies LANDIS clusters — extension-species scaffolds AUTHORED

The 14 remaining states (KS NE OK ND SD MT CO NM AZ UT WY NV ID TX) span 5 clusters with
NO frozen reference theta. They cannot warmstart from the eastern (IN/ME/MN) or PNW-westside
(WA) floras: their species pools differ (dry conifer, pinyon-juniper, prairie margin), and
those species have no LANDIS SpeciesData. The blocker is species parameterization, a domain
step. To make it precise rather than open-ended, I built data-driven target lists from FIA.

Method: FIA basal-area dominance (build_plains_rockies_species.py over the per-state TREE
tables -> plains_rockies_species_ba.csv, top-8 species/state by BA = 0.005454*DIA^2*TPA on
live trees). Union per cluster, flag species NEW vs the warmstart parent pool, attach the
LANDIS-II SpeciesData columns to fill + a published-source hint per species.

Clusters (cluster_<C>_extension_species.csv, staged Cardinal
landis2/tools/state_templates/plains_rockies/ + repo harmonized/plains_rockies/):
- P1 (KS,NE,OK + e-CO/e-NM/e-TX; warmstart MN+IN): 18 species, 10 need literature —
  eastern redcedar, eastern cottonwood, hackberry, bur oak, post oak, blackjack oak, honey
  mesquite, ponderosa, winged elm, Osage-orange.
- P2 (ND,SD + e-MT; warmstart MN): 10 species, 4 need literature — ponderosa (Black Hills,
  64% of SD BA), Rocky Mtn juniper, bur oak, eastern cottonwood.
- R1 (MT,ID,WY; warmstart WA): 13 species, 9 need literature — lodgepole, subalpine fir,
  Engelmann spruce, western larch, ponderosa, whitebark pine, limber pine, grand fir, aspen.
- R2 (CO,NM,AZ,UT; warmstart WA+IN): 14 species, 10 need literature — Utah juniper, oneseed
  juniper, Colorado pinyon, ponderosa, lodgepole, alligator juniper, Gambel oak, Arizona
  white oak, Rocky Mtn juniper, white fir.
- R3 (NV; warmstart WA, sparse): 8 species, 7 need literature — Utah juniper (46%),
  singleleaf pinyon (39%), curlleaf mountain-mahogany, white fir, limber pine, Jeffrey pine,
  western juniper. Great Basin pinyon-juniper end-member.

Source hints flag the tractable vs hard cases: ponderosa, lodgepole, Douglas-fir, subalpine
fir, Engelmann spruce, western larch, white fir, aspen, eastern oaks all have PUBLISHED
LANDIS-II parameterizations (Creutzburg PNW; Loehman N. Rockies; Loudermilk/Sierra; eastern
LANDIS lit) that can be lifted directly. The PINYON-JUNIPER woodland species (Utah/oneseed/
alligator juniper, Colorado/singleleaf pinyon, mountain-mahogany, mesquite) have sparse-to-no
LANDIS literature and need derivation (Bradford PJ studies + trait databases) — the genuine
domain-expert work, now scoped to a specific ~12-species list rather than "all of the West."

Bootstrap path (per cluster): fill SpeciesData from the source hints -> author cluster
reference SppEcoregionData -> run add_state.sh on the seed state (P1=KS, P2=SD, R1=ID, R2=CO,
R3=NV) to convergence -> freeze theta_best as cluster_<C>_reference_theta.csv -> onboard the
members via add_state.sh (FIA already pre-staged for all 14 in ~/fia_data).

## Status

GCBM: Maine spatial run + retention chain LAUNCHED (11505497 -> 11505514), self-completing;
verifies the raster-retention path and yields the first measured GCBM engine value + retained
maps. Plains/Rockies: 5 cluster extension-species scaffolds AUTHORED from FIA dominance and
staged; the remaining work is the SpeciesData literature fill (most species have published
LANDIS parameters; ~12 PJ-woodland species need derivation), which is the LANDIS domain step.
Both campaigns are now unblocked to the point where each next action is concrete.
