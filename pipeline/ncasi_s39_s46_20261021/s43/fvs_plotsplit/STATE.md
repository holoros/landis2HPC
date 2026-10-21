# Track H (fvs_plotsplit) state
- Step 1 done 21:25 EDT: RULE.md written (md5 in RULE.md.md5) before any fit; s41 PLAN/AMEND md5s inside it.
- Inputs copied (INPUT_MD5.txt): s41 run script e, select R c, score py, Track D boot script; pairs/trees md5.
- Driver fvsps_run_20261019.py (imports s41 script unchanged; swaps half column to plot split).
- Job 15691402: splitsum + repro (one s41 grid3 NE cell kB1 PL55 PU95 kS1.3 fa0.01 on original pair split). Pending.
- Next: if REPRO_GATE_PASS, submit 6 grid jobs (grid1/2/3 x ne/ls), then select, score, plot bootstrap.
- Job 15691402 DONE: splitsum -> fvsps_split_summary_20261019.csv (0 plots span halves under plot split; s41 pair split
  holdout share whose plot also in fit 0.44-0.67). REPRO_GATE_PASS (max rel diff 2.1e-16 vs s41 grid3 NE row; binary md5
  d764e677..., cal md5 71f62152... match s41 log).
- Grid jobs submitted: g1 ne 15691545, g1 ls 15691546, g2 ne 15691547, g2 ls 15691548, g3 ne 15691549, g3 ls 15691550.
- Score job 15691582 (afterok on all grids): select (fvsps_select_20261019.R) -> score mode -> fvsps_score_20261019.py.
- Next: check fvsps_score_15691582.log; read fvsps_holdout_results_20261019.csv and verdicts.
