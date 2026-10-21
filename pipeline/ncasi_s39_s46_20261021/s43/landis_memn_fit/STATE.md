# s43 Track G (landis_memn_fit) STATE -- 19 Oct 2026
Plan: /mnt/user-data/outputs/ncasi/2026-10-19_ncasi-january-tracks_PLAN.md Track G (frozen). Source: s43/landis_memn (read only).
## Step 0 DONE: copies + derived scripts (scripts/patch_g.py writes all derived files; asserts each substitution unique)
- copied (md5 = Track A STATE): build_ic_v3_drybio_s43.R 274eb84f, score_memn_s43b.R c08278de, preanchor_gates_anchor_s43.R df5019cb,
  smoke_run_s43.sh 7b728034, build_ic_s43.slurm bb36c6f9; out/ ecoregions_s43_ME_from270.tif 2e565db4, ecoregions_s43_MN_from30.tif f1004a9f,
  species_lookup_ME_s43.R d354e0aa, species_lookup_MN_s43.R 7bdca1a1
- derived: build_ic_v3_drybio_s43_fsta.R (age backstop = median over CONDID 1 & COND_STATUS_CD 1 rows, same pmax(.,1)); build_ic_fsta.slurm;
  preanchor_gates_anchor_s43G.R + pa_G.slurm (T -> this folder); smoke_run_s43G.sh (BUILD=orig uses landis_memn/build read only,
  base270_<BUILD>); score_memn_s43G.R + score_G.slurm (args TAG RUNROOT PATTERN; skips base270_*)
- runs/<ST>/base270_orig = copy of landis_memn/runs/<ST>/base270
- Source tables: ME landis2/states/ME/inputs/SppEcoregionData_fia.csv b08af1f8 (PE 1); MN .../MN/... 4df18984 (PE 0.1)
## Jobs
- 15691515 scorer reproduction (TAG repro, landis_memn runs ^anch_)
- 15691516 ME fsta build, 15691517 MN fsta build
- orig grid 18 smokes 15691521..15691538 (logs/jobs_grid_orig.txt), run names g_orig_a{2.25,2.5,2.75}_b{2.5,3,3.5}
## Step 1 scorer reproduction DONE (job 15691515): out/behav_gate_memn_repro.csv vs landis_memn/out/behav_gate_memn_s43b.csv max abs diff 0
  (out/repro_check_G.txt): ME current 1.0015/0.388/0.915/0.074/0.057; MN x0.1 1.0009/0.740/1.541/0.139/0.162. VT reproduction gate PASS.
## Step 2 fsta builds DONE (15691516 ME, 15691517 MN; builder f7b9d073): ME backstop 60 yr (orig 52), 3875 MapCodes (orig 3877);
  MN backstop 50 yr (orig 1), 4151 MapCodes (orig 3237). Rule includes forested STDAGE 0 rows as 1 (builder transform); Track A diag
  (forested STDAGE>0) gave 61/54.
- aspen diagnosis jobs 15691712 (MN) 15691713 (ME), scripts/aspen_diag_G.R
## Step 3 preanchor/anchor fsta DONE (15691730 ME, 15691731 MN; out/preanchor_gates_{ME,MN}_s43.csv in THIS folder):
  ME P1 P2 P4 PASS, scale 1.37127 (-0.05 pct), anchored 762.4249, md5 ed35a32f; MN P4 species FAIL 4.79 pp QA, eco 0.99 PASS, scale 1.27273
  (-0.18 pct), anchored 633.4450, md5 2a88027c. P3 PENDING (firebreather).
- orig grid 18/18 complete; scored job (TAG orig) submitted
- fsta grid 18 smokes 15691784..15691806 (logs/jobs_grid_fsta.txt; first per state builds base270_fsta, others depend on it)
- aspen diag resubmitted 15691746 MN 15691747 ME (integer overflow fix)
- run dirs renamed g_orig_* -> g_<st>_orig_* after completion (scorer keys on run name; names collided across states; first score job 15691829 failed on this)
## Step 4 orig grid scored (job 15691893, out/behav_gate_memn_orig.csv; pass rule scripts/passrule_G.py -> out/passrule_orig_G.csv)
- ME orig: registered gate passes a2.5_b3, a2.75_b3; BMax/p99 all in [1.15,2.83] -> 2 passing; chosen a2.5_b3 (Chebyshev 0)
- MN orig: 0 pass (production 1.85-2.35; BMax/p99 eco 46 >= 3.60, eco 47 0.91 at b2.5)
- ME orig confirmation: table out/fit_tables/ME_SppEcoregionData_fit_orig_a2.5_b3_G.csv (copy of grid run table), fresh run c_me_orig_a2.5_b3 x1 (logs/jobs_confirm.txt)
- fsta grid 18/18 COMPLETED; dirs renamed g_fsta_* -> g_<st>_fsta_*; scorer 15692093 (TAG fsta). 15692091 submitted without env by mistake, cancelled
## Step 5 fsta grid scored (job 15692093, out/behav_gate_memn_fsta.csv, out/passrule_fsta_G.csv)
- ME fsta: 2 passing (a2.5_b3, a2.75_b3), chosen a2.5_b3; MN fsta: 0 passing
- ME fsta confirmation: out/fit_tables/ME_SppEcoregionData_fit_fsta_a2.5_b3_G.csv (b7336118 = orig fit table), run c_me_fsta_a2.5_b3 job 15692104
- ME orig confirmation c_me_orig_a2.5_b3 job 15692036 complete
- aspen diag DONE (15691746 MN, 15691747 ME): out/aspen_diag_stages_{MN,ME}_G.csv
## Step 6 confirmations scored (job 15692249, out/behav_gate_memn_confirm.csv, out/passrule_confirm_G.csv)
- c_me_orig_a2.5_b3: 1.0015/0.9038/0.9644/0.8665/0.9439 PASS, BMax/p99 58 2.04 59 1.92 82 1.79 -> ME orig CONFIRMED
- c_me_fsta_a2.5_b3: 1.0015/0.9038/0.9643/0.8667/0.9438 PASS -> ME fsta CONFIRMED (same seed 1234: deterministic rerun from written table)
- MN: 0/9 passing on both builds -> MN FAIL. Nothing promoted. TRACK G COMPLETE 19 Oct.
