# s45 landis_miwi (Track M) STATE -- 20 Oct 2026
Spec: Gates for this session, 2026-10-20_ncasi-session45-autopilot_PLAN.md (frozen). No registry edit, no promotion.
## Step 1 DONE: md5
- MI/inputs/SppEcoregionData_fia_20261015.csv b8752e12bf80bacdfb319f5808b8c225 (prefix OK)
- WI/inputs/SppEcoregionData_fia_20261015.csv 46aa9ec78d3b5b8d6e445ad2c8968fc5 (prefix OK)
- PARAMS_ACTIVE.csv (read only) 219a661aa74ab284b3253b43290e8f82 (= s44 post edit md5)
- Sources: s40 build scripts ~/s34/confirm_mi_20261015.sh, confirm_wi_20261015.sh (scenario seed 1234 from smoke_20261001_d10/scenario.txt);
  registered scorers scripts_20261001/pesc3_score_20261015.R c8fe1035 (TAG g, MI) and pesc4_score_20261015.R 45e5b3a1 (TAG h, WI); differ only in TAG and grid.
- Old runbook found on device: CRSF-Cowork/active-projects/ncasi-modeleval/landis-stage8-20261003/s40_20261015/RUN_promote_miwi_20261015.md
## Step 2 SUBMITTED
- scripts (s45 copies): confirm_miwi_s45.sh 86f48099 (diff vs s40: no table write, md5 check of existing table, run dir in track, SEED env),
  score_miwi_s45.R 82d04cb0 (diff vs pesc4: TAG/GRID env, track run root, out/ folder, raw table written), score_s45.slurm, repro_s45.slurm
- repro array 15725435 (MI, WI seed 1234) -> runs/<ST>/confirm_seed1234; scorer 15725465 TAG repro1234 (afterok)
- Stock inputs read: gates/fiadb_live_agb_fourstate_20261001.csv (MI 1050.96, WI 814.17, NH 314.26, VT 294.27, evalid 2024);
  gates/anchor_ic_fourstate_20261006.csv scale MI 2.99764 WI 2.61137 NH 2.64116 VT 2.52462 (instate_raw MI 350.596 WI 311.779);
  cohort_biomass_by_mapcode_fiadb.csv / cohort_biomass_by_mapcode.csv uniform row ratio MI 1.49875 WI 1.30567 NH 1.32054 VT 1.26226 (= half the anchor table scale)
- NH/VT check from gates/behav_gate_confirm_20261015c.csv t0_Tg: NH 315.1061/314.26, VT 294.1651/294.27 (compute in step 3)
## Step 2 DONE: reproduction PASS (F9)
- 15725435 both tasks LANDIS_EXIT=0 complete=1. Scorer 15725465 (TAG repro1234): step 0 REPRODUCTION GATE PASS; out/behav_gate_runs_repro1234.csv, out/raw_runs_repro1234.csv
- Fields 5 to 9 and 17 to 25 (anpp_mean, mort, net, high, rmse, fia cols, r_prod r_mort r_net, g_*, pass, loss) string identical to s40 rows in gates/_20261015g (MI) and _20261015h (WI)
  MI 0.993/0.877/1.069/0.866 PASS; WI 1.018/0.981/1.049/0.823 PASS
- Rasters TotalBiomass-0, -10, anpp-5 and run inputs (SppEcoregionData_fia.csv, initial-communities.csv) md5 identical to s40 run folders. Filtered table = full table (121 MI, 145 WI lines).
## Step 3 DONE: stock (gate reads anchored)
- anchored t0_Tg / FIA 2024 (fiadb_live_agb_fourstate_20261001.csv = EVALIDator values given): MI 1054.063/1050.96 = 1.0030; WI 815.657/814.17 = 1.0018; NH 315.106/314.26 = 1.0027 (1.003 OK); VT 294.165/294.27 = 0.9996 (1.000 OK)
- diagnostics: t0 / cohort table row scale -> MI 703.29 Tg 0.6692, WI 624.70 0.7673, NH 0.7593, VT 0.7919;
  anchor_ic_fourstate_20261006.csv instate_raw / FIA -> MI 0.3336 (scale 2.99764), WI 0.3829 (2.61137), NH 0.3786, VT 0.3961. The table scale is 2x the cohort row ratio in all 4 states (not diagnosed here).
- All anchored ratios within 10 pct and within 0.5 to 2; no code diagnosis triggered.
## Step 4 SUBMITTED: seeds array 15725604 (MI, WI x 20261020-22), scorer 15725605 TAG seeds (afterok) on grid_seeds_s45.csv (includes seed 1234)
- derivation check: awk rule of s40 on _20260929 (MI f4ae759c, WI 9104d7d6) reproduces b8752e12 and 46aa9ec7 (out/derive_check_MI.csv, _WI.csv)
## Step 4 DONE: seeds 15725604 (6 tasks LANDIS_EXIT=0 complete=1), scorer 15725605 TAG seeds: REPRODUCTION GATE PASS, complete 8 of 8
- out/behav_gate_runs_seeds.csv, out/raw_runs_seeds.csv. prod/mort/net/dense, net Tg/yr:
  MI 1234     0.9929/0.8767/1.0691/0.8659 PASS net 20.023
  MI 20261020 0.9929/0.8765/1.0700/0.8657 PASS net 20.039
  MI 20261021 0.9929/0.8769/1.0677/0.8657 PASS net 19.998
  MI 20261022 0.9929/0.8744/1.0695/0.8657 PASS net 20.030
  WI 1234     1.0181/0.9807/1.0489/0.8226 PASS net 19.839
  WI 20261020 1.0181/0.9784/1.0494/0.8231 PASS net 19.848
  WI 20261021 1.0181/0.9783/1.0488/0.8232 PASS net 19.837
  WI 20261022 1.0181/0.9814/1.0491/0.8232 PASS net 19.843
- t0_Tg identical across seeds (MI 1054.063, WI 815.657): stock 1.003 / 1.002 all seeds. Net above FIA 95 pct upper bound in all runs (MI 19.599, WI 19.466).
- Step 5 note: simulating the registry edit on a copy in out/sim was refused by the permission classifier (not retried); runbook carries structural post edit checks.
## Step 5 DONE: runbook ncasi_gates_20261015/s45/landis_miwi/RUN_promote_miwi_20261020.md (device copy landis-stage8-20261003/s45_20261020/), supersedes s40 RUN_promote_miwi_20261015.md. Registry not edited (md5 still 219a661a). TRACK COMPLETE 20 Oct 2026.
