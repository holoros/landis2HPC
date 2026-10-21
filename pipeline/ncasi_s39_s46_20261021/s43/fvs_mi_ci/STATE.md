# s43 Track D (fvs_mi_ci): bootstrap intervals for FVS-LS/NE mortality recal holdout ratios (19 Oct 2026)
No refit, no FVS runs. Inputs read-only: s41/fvs/work/hold_pairs_{ST}.csv (holdout score job 15553462), fvs/work/pairs_{ST}.csv, s41/fvs/fvs_mortrecal_holdout_results_20261015.csv (md5 055f993b). Input md5s in fvsci_bootb_15671224.log.
Script fvsci_boot_20261019b.py (job 15671224). Ratio of means as in s41 scorer. 2,000 resamples, seed 20261019 (separate generator streams for pair and cluster bootstrap). Percentile 95 pct intervals.
Cluster = plot remeasurement chain: union of t1 (PREV_PLT_CN) and t2 (pair_id) CNs over the full pair file; holdout pairs fall in fewer plots (MI 4,656 pairs in 3,499 plots, max 4 pairs per plot).
Reproduction: REPRO_OK, all 21 state x arm rows x 4 quantities within 0.0005 of s41 (fvsci_repro_check_20261019b.txt).
Run 1 (job 15671200, fvsci_boot_20261019.py, outputs *_20261019.csv) used t1_id as plot key, found no clusters (t1 unique per pair; pair_id has leading whitespace); superseded by run b.
Results: fvsci_boot_results_20261019b.csv (all arms), fvsci_cluster_diag_20261019b.csv. Verdicts are the s41 registered verdicts; intervals are context only.
Key: MI recal_state mortality 0.849, pair 0.813 to 0.888, cluster 0.810 to 0.886; 47.8 pct (pair) / 48.8 pct (cluster) of resamples inside 0.85 to 1.15. FAIL stands.
Split check (job 15671230, fvsci_split_plot_overlap_20261019.csv): split is by pair, not plot; holdout plots that also contribute a fit pair: ME 62.4, NH 54.7, VT 56.5, MI 39.6, WI 61.2, MN 65.6 pct. Holdout is not plot independent of the fit. md5(stripped pair_id) mod 2 did not reproduce the s41 split, so the hashed string differs in formatting; membership taken from hold_pairs files.
Next: none; downloads to device done if listed in report.
