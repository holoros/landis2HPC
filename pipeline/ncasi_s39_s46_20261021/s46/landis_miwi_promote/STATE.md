# s46 MI/WI LANDIS promotion (20 October 2026)
Runbook: s45/landis_miwi/RUN_promote_miwi_20261020.md md5 a87c4104a36037cdf3992748b9e602ad (verified)
Decision: Aaron chose to promote MI and WI (answer to s45 decision).

## Step 1 pre edit checks: PASS
MI table b8752e12bf80bacdfb319f5808b8c225, WI table 46aa9ec78d3b5b8d6e445ad2c8968fc5, PARAMS_ACTIVE.csv 219a661aa74ab284b3253b43290e8f82
PARAMS_ACTIVE_PREV_20261020b.csv did not exist before this session.
- Step 2 backup PARAMS_ACTIVE_PREV_20261020b.csv md5 219a661a...: PASS
- Step 3 edits applied (DEC=Aaron 2026-10-20)
## Step 4 post edit checks: ALL PASS
diff: exactly MI _20260929 and WI _20261007 rows to superseded, two new promoted rows appended
wc 10; no bad field counts; 9 OK md5 lines, no FAIL; tables unchanged b8752e12 / 46aa9ec7; promoted count 5
New registry md5 f6203836354812d67057d72c87885e1b
## Step 5 smoke (registry driven, seed 1234)
- scripts: smoke_miwi_s46.sh de9570f7 (s45 confirm copy; table path and md5 from promoted registry row, track root s46), score_miwi_s46.R 649d9229 (s45 scorer copy, TK only), grid_smoke_s46.csv, smoke_s46.slurm, score_s46.slurm
- smoke array 15729059 (MI, WI seed 1234) SUBMITTED
- scorer 15729067 TAG smoke1234 (afterok 15729059) SUBMITTED
## Step 5 DONE: smoke PASS
- 15729059 both tasks LANDIS_EXIT=0 complete=1 (registry md5 f6203836 read at run start, promoted row md5 = s40 md5)
- scorer 15729067 TAG smoke1234: REPRODUCTION GATE PASS, complete 2 of 2; out/behav_gate_runs_smoke1234.csv, out/raw_runs_smoke1234.csv
- MI 0.993/0.877/1.069/0.866 PASS, stock 1.003; WI 1.018/0.981/1.049/0.823 PASS, stock 1.002
- every scored field and raw field string identical to s45 repro1234; rasters TotalBiomass-0, -10, anpp-5 and run inputs md5 identical to s45 (checked 10 of 10)
- registry left in place (no restore needed), md5 f6203836354812d67057d72c87885e1b. SESSION 46 PROMOTION COMPLETE.
