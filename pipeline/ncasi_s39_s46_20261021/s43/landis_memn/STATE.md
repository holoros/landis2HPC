# s43 Track A (landis_memn) STATE  -- 19 Oct 2026
Plan: /mnt/user-data/outputs/ncasi/2026-10-19_ncasi-next-steps-to-13nov_PLAN.md Track A (frozen).
## Step 1 DONE: patched builder
- scripts/build_initial_communities_v3_orig.R md5 d9a08889 (copy of landis2/tools/build_initial_communities_v3.R)
- patch_drybio_tons_20261001.py (84abe265) applied with APPLY=1 to COPY scripts/build_ic_v3_drybio_s43.R only; diff = lines 240 and 328 only
  (DRYBIO_L*1000*0.4536/0.4047 -> DRYBIO_L*2000*0.45359237/0.40468564). Backup build_ic_v3_drybio_s43_PREV_20261001.R (= orig).
- copied in: anchor_ic_fourstate_20261006.R ad3fc8fe, smoke_gates_fb_20261001.R 3ca58154, smoke_build_fb_20261001.sh 58fd73de,
  behav_gate_score_20261015.R bc41629a, fia_bins_memn_20261015.R 365d18bd, fiadb_live_agb_fourstate_20261001.R 6990de37,
  ~/s34/confirm_mi_20261015.sh, fit_behav_20261015.sh, lakestates_pesc3_20261015.sh
## Jobs
- 15671212 find (logs/find_results.txt): no species crosswalk, no stage7 ecoregion script on Cardinal. FIADB ME/MN in ~/fia_data.
- 15671278 probe1 (grids, tables)
## Step 2 (scripts generalized) -- see later entries (anchor_ic_states_s43.R, smoke_build_states_s43.sh)
## Step 3 DONE: 30 m ecoregion layers (job 15671296, scripts/build_ecoregions_s43.R d1cb3e52, logs/ecoregions_s43.log)
- Mirror check (out/ecoregion_mirror_check_s43.csv): NH and MI ecoregions_20260929.tif equal a nearest-neighbour resample of the
  state 270 m L3 raster onto the TM grid in 100% of cells (NH 26,633,319; MI 166,789,362 cells). So stage seven = near resample of 270 m L3.
- ME primary: out/ecoregions_s43_ME_from270.tif = near resample of ME_ecoregion_l3_270m_20260925.tif onto ME_TM_22 grid
  (11049x17186, origin 1928715,3014985, 30 m, EPSG 5070; compareGeom TRUE). 58=35932.1 59=3045.3 82=45190.8 km2, total 84168.2.
- ME sensitivity: out/ecoregions_s43_ME_from30fm.tif from ME_ecoregion_l3.tif (named in plan) = forest-restricted (MEMORY item three), 67618.0 km2.
  DEVIATION: plan names ME_ecoregion_l3.tif; mirrored method (270 m L3) used as primary because the 30 m file is forest-masked.
- MN: out/ecoregions_s43_MN_from30.tif = near resample of MN_ecoregion_l3.tif (origin differs from TM by <1 mm); 46..52, total 218532.3 km2.
## Lookups: scripts/make_lookups_s43.R 9f8482b1 -> out/species_lookup_{ME,MN}_s43.R (ME 59 SPCD->15 codes from NH+VT embedded; MN 50 SPCD->24 codes from MI+WI)
  DEVIATION: species_crosswalk_NE_LS_20260929.csv not on Cardinal; reconstructed from per-state embedded lookups.
## Step 7 DONE: climate inert (job 15671291, scripts/climtest_s43.sh 6ff87c1d)
- VT confirm r2 inputs rerun with climate +5 C temps, precip x0.5: TotalBiomass 5/10, ANPP 5/10, Biomass-succession-log.csv md5
  IDENTICAL to control and to the original run (2087f1a1, b315991c, 14fff4ed, 2f6ac0f1, d14d57b8). Biomass Succession v7.0 in this
  configuration does not use the climate table -> PRISM normals used for ME/MN, substitution declared inert.
## Step 4 RUNNING: builder jobs 15674087 (ME) 15674088 (MN), scripts/build_ic_s43.slurm bb36c6f9 -> build/<ST>/
## Step 4 DONE: builder jobs 15674087 (ME) 15674088 (MN) -> build/<ST>/initial_communities/ (BUILDER_EXIT=0)
- ME: 3877 MapCodes, 37177 cohort rows, 4026 TM_IDs; MN: 3237 MapCodes, 20188 cohort rows, 4540 TM_IDs.
- Builder step 10 prints 0.0 Tg (existing defect: sums TM_ID counts, not pixels; diagnostic only, not used).
- Builder age backstop: MN median STDAGE backstop = 1 yr (median over all CONDID 1 rows incl. nonforest); applies to 9.1 pct of
  MN live BA (plots not in MN_COND). ME backstop 52 yr on 4.7 pct. Reported, not repaired (builder run as staged).
## Steps 5-6 DONE: scripts/preanchor_gates_anchor_s43.R df5019cb, pa.slurm; jobs 15674109 (ME from270) 15674110 (MN from30)
- out/preanchor_gates_{ME,MN}_s43.csv, out/preanchor_shares_{ME,MN}_s43.csv, out/active_mapcode_eco_{ST}_s43.csv
- ME: P1 PASS; P2 BA mapped 0.993 PASS; P3 active 67557 km2 PENDING; P4 species max 2.10 pp (HE) PASS, ecoregion 1.70 pp (58) PASS;
  FIADB EVALID 232401 forest live AGB 762.4297 = EVALIDator; pre 555.996 Tg; scale 1.37129 vs 1.372 (-0.05 pct) PASS; anchored 762.4247; md5 4138a454
- MN: P1 PASS; P2 0.9845 PASS; P3 73903.9 km2 PENDING; P4 species FAIL max 4.82 pp (QA, IC 0.197 vs FIA 0.245; RP -2.77), ecoregion 1.12 pp PASS;
  FIADB 272401 = 633.4494; pre 499.364 Tg; scale 1.26851 vs 1.275 (-0.51 pct) PASS; anchored 633.4503; md5 2f2f3e1e
## Step 8 NEXT: scripts/smoke_run_s43.sh (270 m, PRISM, anchored IC) then scorer
## Step 8 smokes DONE (scripts/smoke_run_s43.sh 7b728034): jobs 15674274 ME anch_d10_me_current (ME SppEcoregionData_fia.csv b08af1f8 x1), 15674275 MN anch_d10_mn_pe0.1 (MN SppEcoregionData_fia.csv 4df18984, ProbEstablish x0.1); both complete
- 270 m base: ME active 928336 cells (6767569 ha) IC implied 763.554 Tg; MN 1013843 cells (7390915 ha) 634.051 Tg (runs/<ST>/base270/build_summary.csv)
## Scoring: scripts/score_memn_s43.R ef96690e, score.slurm; job 15674343 TAG s43a -> out/behav_gate_memn_s43a.csv, behav_by_ecoregion_memn_s43a.csv, bmax_vs_fia_p99_s43a.csv
- s43a results (out/behav_gate_memn_s43a.csv): reproduction gate PASS (VT r2 to <5e-15). ME current: stock 1.0015 prod 0.388 mort 0.915 net 0.074 high 0.057 FAIL (ME stops; no ME tuning registered).
  MN pe x0.1: stock 1.0009 prod 0.740 mort 1.541 net 0.139 high 0.162 FAIL -> MN 3x3 grid jobs 15674382-15674390 (runs/MN/grid_d10_mn_pe0.1_a{1,1.3,1.6}_b{2.5,3,3.5})
- DEFECT in s43a per-ecoregion diagnostic: LANDIS output rasters read flipped vs input maps (align job 15674398: overlap 221366 of 1013843 MN cells unflipped, 1013843 flipped). Statewide gate unaffected (outputs joined to outputs). Fixed in scripts/score_memn_s43b.R c08278de (s43a by-ecoregion file superseded).
## Step 9 DONE: MN 3x3 grid (jobs 15674382-15674390) all complete; scored with score_memn_s43b.R c08278de, job 15674607 TAG s43b
- No grid point passes (out/behav_gate_memn_s43b.csv). Best loss a1.3 b3: prod 1.061 mort 0.922 net 1.157 high 0.594. a1.3 b2.5 passes prod/mort/net (1.078/1.104/1.058) but high 0.562.
- VERDICT: ME FAIL (behavioural; stop, no ME tuning registered). MN FAIL (pre-anchoring P4 species shares 4.82 pp QA; behavioural fails at x0.1 and at all 9 grid points). Nothing promoted.
- Summary: out/SUMMARY_trackA_s43.md. TRACK COMPLETE 19 Oct.
