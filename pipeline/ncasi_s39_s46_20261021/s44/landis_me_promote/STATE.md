# s44 landis_me_promote STATE -- 20 Oct 2026
Decision (Aaron): PROMOTE ME LANDIS-II Biomass Succession fitted table (ANPPmax x2.5, BiomassMax x3.0) from s43 Track G (43c).
Sources read only: s43/landis_memn, s43/landis_memn_fit. MN not touched. MI/WI registry rows not touched.
## Step 1 DONE: read s43 STATE files and scripts
- s43 scripts md5: smoke_run_s43G.sh a505168c, score_memn_s43G.R 8c050d10, score_G.slurm 40d9211c, passrule_G.py 642c391e
- fit table s43/landis_memn_fit/out/fit_tables/ME_SppEcoregionData_fit_orig_a2.5_b3_G.csv md5 b73361188430fe67dce53bbdf9957df9 (45 rows, ecos 58 59 82; fsta copy identical)
- derivation check: landis2/states/ME/inputs/SppEcoregionData_fia.csv (b08af1f842dbf1411f760da574318969) with ANPPmax int(x*2.5+0.5), BiomassMax int(x*3+0.5)
  -> out/derive_check_a2.5_b3.csv, byte identical to fit table (cmp)
- 43c confirmation (s43 out/behav_gate_memn_confirm.csv) c_me_orig_a2.5_b3, seed 1234: stock 1.0015 prod 0.9038 mort 0.9644 net 0.8665 high 0.9439 PASS;
  net 13.967 Tg/yr vs FIA 16.1185; BMax/p99 58 2.04 59 1.92 82 1.79. Matches 1.0015/0.904/0.964/0.867/0.944. Rescore with s44 scorer copy pending in step 3.
- Seed: smoke_run_s43G.sh hard codes RandomNumberSeed 1234 in scenario.txt; s44 copy takes SEED env.
- Registry: landis2/states_fb_20260930/PARAMS_ACTIVE.csv md5 c576eb78108dfca769a00cc717dafd44 (paths relative to states_fb_20260930; no ME dir there, no ME row)
## Step 2 DONE: candidate installed (no overwrite; target absent before cp -n)
- landis2/states/ME/inputs/SppEcoregionData_fia_20261020.csv md5 b73361188430fe67dce53bbdf9957df9 (= fit table). SppEcoregionData_fia.csv unchanged b08af1f8.
- Location note: the s43 rebuild reads ME inputs from landis2/states/ME/inputs (IN in smoke_run_s43G.sh); states_fb_20260930 has no ME folder.
## Step 3 SUBMITTED
- scripts (s44 copies, diffs vs s43 = folder path only, plus seed from SEED env): smoke_run_s44.sh 9fe36732, score_memn_s44.R fd9632b4 (T only), seeds_s44.slurm 4355666f, score_s44.slurm
- copied in: runs/ME/base270_orig (md5 identical to s43 fit), out/ecoregions_s43_ME_from270.tif 2e565db4, out/ecoregions_s43_MN_from30.tif f1004a9f (scorer FIA layer only)
- array 15721235: task0 seed 1234 control, tasks 1-3 seeds 20261020/20261021/20261022; runs/ME/s_me_a2.5_b3_seed<SEED>; SRCT = installed candidate, A=B=PE=1
- score 15721251 TAG repro43c (rescore s43 c_me_orig with s44 scorer copy); score 15721252 TAG seeds (afterok 15721235)
- find job 15721191 (locate registry; registry already found at landis2/states_fb_20260930/PARAMS_ACTIVE.csv)
- 15721251 DONE: s44 scorer copy rescoring s43 c_me_orig_a2.5_b3 -> out/behav_gate_memn_repro43c.csv; VT reproduction gate PASS; max abs diff vs s43 confirm = 0.
  Step 1 ratio confirmation CLOSED: 1.0015/0.9038/0.9644/0.8665/0.9439 PASS.
- 15721235 task0 (seed 1234) LANDIS complete; tasks 1-3 running (16:28)
- 15721235 all 4 tasks COMPLETED exit 0. Seed 1234 control: TotalBiomass-10.tif and run table md5 identical to s43 c_me_orig (aba02dc2, b7336118). New seeds give distinct rasters.
- 15721252 (TAG seeds) gate rows written, out/behav_gate_memn_seeds.csv (stock/prod/mort/net/high, net Tg/yr):
  seed1234     1.0015/0.9038/0.9644/0.8665/0.9439 PASS net 13.9669
  seed20261020 1.0015/0.9038/0.9648/0.8667/0.9436 PASS net 13.9700
  seed20261021 1.0015/0.9038/0.9609/0.8681/0.9431 PASS net 13.9927
  seed20261022 1.0015/0.9038/0.9620/0.8674/0.9431 PASS net 13.9813
  Net vs FIA 16.12 (95 pct 15.50 to 16.74): all seeds below the FIA interval lower bound; gate passes only on the 0.85 floor (margin about 1.7 pp).
- 15721252 SCORE_DONE: BMax/p99 ME 58 2.04 59 1.92 82 1.79 (all in 1.15 to 2.83, same all seeds). Per ecoregion diagnostic (not gated): prod 0.907/0.848/0.816,
  mort 0.47 to 0.57 vs remeasured plot means (eco 58/59/82), stable across seeds.
## Step 3 DONE: all 3 fresh seeds PASS the registered gate.
## Step 4 DONE: registry edited (permission not refused)
- landis2/states_fb_20260930/PARAMS_ACTIVE_PREV_20261020.csv = prior registry (md5 c576eb78108dfca769a00cc717dafd44, cp -n)
- PARAMS_ACTIVE.csv now md5 219a661aa74ab284b3253b43290e8f82; diff = one appended ME row (promoted, Aaron 2026-10-20, path ../states/ME/inputs/SppEcoregionData_fia_20261020.csv,
  md5 b7336118...). All 7 rows parse with 6 fields and every path resolves to its registered md5. MI and WI rows unchanged.
- Path note: ME row uses ../states/... because ME inputs live outside states_fb_20260930 (other rows are relative to that folder).
## Step 5: MN not touched. TRACK COMPLETE 20 Oct 2026.
