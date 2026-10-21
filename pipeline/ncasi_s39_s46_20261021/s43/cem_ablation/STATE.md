# s43 Track C (CEM ablation) STATE
## Step 1 (19 Oct ~07:00) setup
- engine_c = copy of s41/cem/engine_fix2 (R/, run_projection.R, .here, config+data symlinks to production, read only).
- Dry run: production R + cem_subject_id_fix_20261016.patch + cem_cycle_keys_and_age_option_20261016.patch == engine_fix2 except one extra line E:247 `mutate(d_CONDID = CONDID)` (s41 output only patch, not in either patch file). log: dryrun.log
- Guard added in engine_c only, E:365 (the T2->base copy loop; plan cited 357, probe 350-358; actual copy line is 365): CEM_NO_DONOR_SWAP=1 keeps subject pre_ value for conflicting columns; default off = original. Original saved as 06_projection_engine.R.engine_fix2_orig.
- md5: engine_c 02_cem_matching.R 866202996b71821b750f207198c7c4c8; 06_projection_engine.R 16f2e2ecb9dc524000ca022862a956f0 (engine_fix2 3aa24c74b22e0d4858a7e38876ac0fd3); run_projection.R 976d836b63d4241be840b422a14b26ac
- Scorers: cem_gate_score_s41d8.R 80f3e6be65b8d69488881459480dc99e (copied). cem_gate_score_s43c_reg.R 9892e61d762b9f30a167c45fc0b0d3d0 = s41d8 with I/O paths only (L72 engine dir absolute; L264-265 out dir CEM_OUT) because s41d8 writes into s41/cem/out.
- NETTED SCORER FROZEN before any run: cem_gate_score_s43c_netted.R md5 ed9aa46c4a290a0ffaadb6ed00e98739 (reg copy + state level residual sign: L177-184 version A, L219-223 version B; output suffix _s43netted).
- Drivers: run_ablation_s43c.slurm 0eca0c5d32d470f8b309c0c8c7248f9d; score_ablation_s43c.slurm 449c63a775ee8dd84a21c329ddcbce6f
- Recorded baseline: s41/cem/out/cem_gate_{ST}_f2gate_20261016e.csv (column ratio, version A).
## Next: submit baseline tasks 0-5, score, compare with recorded f2gate, then tasks 6-54.
- 19 Oct: baseline engine job 15671234 (tasks 0-5)
- baseline scoring job 15671252 (aftercorr)
- Baseline reproduced: s43c_baseline_repro.csv, max abs ratio diff 0.0025 (NH mort), stock identical. Arms: engine job 15674644 tasks 6-54, scoring job 15674645
## Step 3 (19 Oct) arms done
- Engine 15674644 (tasks 6-54) and scoring 15674645 all COMPLETED 0:0; 55 reg + 55 net score files.
- Tables: s43c_ablation_long.csv, s43c_ablation_ratio_wide.csv, s43c_ablation_delta_wide.csv, s43c_ablation_SUMMARY.md (mkmd_s43c.R), s43c_baseline_repro.csv.
- Baseline netted state residual (version A, Tg/yr): ME -5.84 NH -1.15 VT -1.61 MI -2.69 WI -1.43 MN -2.38 (logs/s43cemS_15671252_*.log): negative in all six, so netted gross = donor G only.
- Status: COMPLETE; downloads next.
- Downloaded SUMMARY.md, long.csv, baseline_repro.csv, STATE.md to local s43_20261019/ with s43c_cem_ prefix (cem_ablation subfolder could not be created by scp).
