# s43 Track J (cbm_richards) STATE
Plan: /mnt/user-data/outputs/ncasi/2026-10-19_ncasi-january-tracks_PLAN.md Track J. Source: s43/cbm_netdriver (read only; copies in src_copy/).
## Step 0 DONE: copied cbm_netdriver scripts to src_copy/ (md5 01b bb6d5ef0..., 04b 5e9cccaa..., s43nd_build_v1.py e1a96a17..., 06 8c79690e...).
## Step 1 DONE: fit job 15691734 (v1, theta to lower bound, r unidentified) superseded by 15691744 (failed: HR append commented out by patch) and 15692084 (PRIMARY). scripts/01J_fit_richards.R md5 6dc5fad97d9c99d41266d3be94f5e3c9; parametrised k=r*theta. -> out/fit_p90, fit_p95, fit_p99; out/tbJ_A_B0_by_state_type_DATA.csv
## Step 2 DONE: pseudo-age job 15692099 scripts/04J_pseudoage.R md5 7bf2310307a4c6798cae913ad4a63ec8 -> out/pseudo_{p90,p95,p99,s43free}; out/tbJ_pixel_coverage_DATA.csv
## Step 3 DONE: round trip job 15692107 scripts/s43nd_build_v1.py (unchanged copy, md5 e1a96a17...; curve file swapped by argv) -> out/rt_{p90,p95,p99}/{ST}; 18/18 rc=0
## Step 4 RUNNING: eval + floor test job 15692222 scripts/07J_rt_eval_floor.py md5 fd2d4a2fd11254857c9547eb4fa87c92 -> out/tbJ_*.csv
## dbg/: debug job 15691891 (fitJ on ME SF only; no outputs used)
## Step 4 DONE: eval+floor job 15692222 (07J); job 15692275 accidentally re-ran 07J (identical outputs); 08J smoother attribution job 15692295 (md5 d329b314...); 09J summary job 15692337 (md5 278a8c7d...).
## RESULTS (aggregates in out/tbJ_*.csv): holdout s43 classes pass p90 13/30, p95 16/30, p99 12/30 (s43free 24/30); dense bins 0/18, 0/18, 3/18 (s43free 8/18, MI WRPH missing). theta at lower bound (Gompertz limit) 30/34, 25/34, 24/34. Monotone 34/34 all. Order (A vs FIA mean) identical 6/6, 4/6, 1/6 (near construction); B100 2/6, 1/6, 1/6.
## Round trip strata pass occupied 7/52, 6/52, 6/52 (s43free 7/52 with ft-level occupancy). Young (1-20) failure share of young area 0.649/0.676/0.637 (s43free 0.786); of total area 0.097/0.100/0.078 (0.125).
## Floor test: min_volume floor explains 0-4% of failing young area (rejected). Pass 1 (pre-correction) young failures 100% attributable to libcbm CBM3 smoother; pass 0 failures: correction passes move young volumes off target (py chain misses target in 95-100%).
## No gate run. Nothing promoted. Track complete.
