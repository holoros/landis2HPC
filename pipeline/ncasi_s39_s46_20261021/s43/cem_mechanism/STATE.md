# Track I STATE\n- Mon Oct 19 09:37:58 PM EDT 2026 created folder
- job 15691862 (h1a agent split, 14 states) submitted
- 15691862 done: agent split reconciles to s41 mort_tot (rel diff 0, out/h1a_agent_check_*.csv). h1b_score_s43i.R md5 cb99a61379f779c24be5b6bccefb9759 submitted
- H1 job 15691880 done; out/h1_all_c00base_s43i.csv; tool mort reproduces s43 reg c00base exactly. ratio Md/DL ME .439 inconcl, MI 1.410, MN 1.489, NH 1.002, VT 1.193, WI 1.910 supported. H2 job 15691894 done
- early window engine job 15692287 (engine_i = engine_c copy, md5 identical; --baseline_year 2010; e00base e03nodist e04nosdi e08alloff)
- early scoring job 15692317 (aftercorr 15692287); scorers cem_gate_score_s43i_early_{reg,netted}.R = s43c scorers with eval 2019 and TGT = FIA same estimator (2024 check: fia_same equals EVALIDator to 1e-4 Tg)
52b898b61dceb782e8ea9135db5a539f  cem_gate_score_s43i_early_netted.R
9e705f6a0cd8d2bbb4055d8558fe5b05  cem_gate_score_s43i_early_reg.R
7e12608b08295014b0b48294be337935  h1a_agent_split_s43i.R
cb99a61379f779c24be5b6bccefb9759  h1b_score_s43i.R
2a92b8ecf9a5e63c9a696caf667cfac3  h2_sdimax_pairs_s43i.R
e7ea1866cda2921a3e7e2dfb8f599b90  sum_h1_s43i.R
7f83957c99a8a6463f0e980765de1529  h1a_s43i.slurm
ad5438434e5ffcc23a7e8fb7eda6d6ce  h1b_s43i.slurm
6d93b5e0b90d3035d95cb81fc9f175e3  h2_s43i.slurm
6e191600c01f75ad839a456ccf28572a  run_early_s43i.slurm
e79358dc4802f6dcd3bd7915fda95cad  score_early_s43i.slurm
- early engine 15692287 (24 tasks) and scoring 15692317 (24 tasks) COMPLETED. Summary: sum_early_s43i.R -> out/early_ratios_long_s43i.csv, out/early_replication_long_s43i.csv, out/early_replication_verdict_s43i.csv, out/sum_early_s43i.log
- Replication (mortality ratio change vs base, same sign and within 0.10 of gate, >=5/6): registered nodist 6/6 YES, nosdi 6/6 YES, alloff 1/6 NO; netted nodist 4/6 NO, nosdi 5/6 YES, alloff 1/6 NO.
- H2 job 15691894: out/h2_sdimax_pairs_s43i.csv; share gaining among RD>1: ME .873 NH .785 VT .787 MI .758 WI .866 MN .786 -> supported all six.
- Seeds: engine cfg$seed default as s43c ablation; scorer set.seed(20261016+statecode) as registered. No configuration adopted. Track I complete.
