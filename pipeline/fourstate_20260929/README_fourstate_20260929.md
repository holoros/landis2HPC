# Four state LANDIS-II input build, NH VT MI WI (28 to 30 September 2026)

NCASI Model Evaluation Phase II. Stages one to seven built on firebreather (ifm-kershaw, R 4.5.1) under
`~/landis2_fb/`, with FIA TREE, COND, PLOT and POP tables under `~/restricted/ncasi-modeleval/` (mode 700).
Stage one: `landis_stage1_ecoregions_20260928.R` (EPA Level III at 270 m, EPSG:5070). Stages two to six:
`stage2_clip_treemap.R`, `stage3_*`, `stage4_*`, `stage5_*`, `stage6_placeholder_ma.R` with the shared
species crosswalk `species_crosswalk_NE_LS_20260929.csv`. Stage seven (session 32): `stage7_ecoregions30_20260930.R`
(30 m ecoregion raster on the initial communities grid), `state_finish_ecoregion_fb_20260930.R` (FIA BiomassMax
table, patched paths only), and the two gate scripts. Every gate is one row in `gates_20260929.tsv`.
Management areas are PLACEHOLDER (statewide, single area) until Solarik's definitions arrive. Stage eight
(LANDIS-II smoke runs) is not built: firebreather has no dotnet and no apptainer.
No file here carries plot coordinates; the FIA tables stay on the server.
