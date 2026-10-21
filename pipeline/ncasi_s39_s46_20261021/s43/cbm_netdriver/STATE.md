# s43 Track B (cbm_netdriver) STATE
Scope: Track B up to but NOT including the CBM gate run (PI decision 1 option 1). Stress alts only #1 mixed model, #2 stratum-mean vs class split.
## Step 1 DONE: fit + holdout + LOSO + curves + realism (job 15671288; probe job 15671271)
- script scripts/01_fit_netdriver.R md5 ab3f4ec5f22988d5336bcaebd68102ea; R/4.5.2 (R/4.4.0 module absent); seed 20261019
- inputs: ME ~/maine_agb_yc_20261015/out_b/me_intervals_DATA.csv; NHVT ~/nhvt_agb_yc_20261016/out/me_intervals_DATA.csv; MI/WI/MN ~/lakes_agb_yc_20261016/out_{ST}/yc_intervals_DATA.csv (md5 in logs/fit_15671288.out)
- outputs out/fit/: tb_params_{evenhalf,allplots}, tb_holdout_state_class, tb_holdout_type_class, tb_loso, tb_curves_0_300, tb_realism_type, tb_realism_order, tb_fia_type_quantiles, tb_data_counts
- results: holdout state x class pass 23/30; realism B*<p99 passes only NH/VT AB (30/32 fail); LS oak c at lower bound (no equilibrium); ME EAC b at bound 0.99; NHVT OAK nls failed (singular)
- TM2020 pixel data present: /fs/scratch/PUOM0008/crsfaaron/TREEMAP_restore/TM2020/TreeMap2020_CONUS.tif + .vat.dbf (fields not yet checked)
## Next: v2 fit with NHVT oak fallback; pseudo-age inventory; round trip (copy of s42fy_build_v1.py); mixed model alt.
## Step 1b DONE: fit_v2 (job 15683257) scripts/01b_fit_netdriver.R md5 bb6d5ef0935e62827d056d462c9cea39 -> out/fit_v2 (PRIMARY). NHVT OAK state-effect nls failed -> pooled NH+VT oak without state effect (deviation). Holdout 24/30.
## Step 2 RUNNING: TM2020 pixel counts by state polygon (job 15683581) scripts/03_tm_pixels.py md5 545255a6d5ac5a06fd6752689976c424 -> out/px_RESTRICTED (stays on Cardinal; Value keys)
   pixel biomass IS on Cardinal (VAT DRYBIO_L tons/acre). R 4.5.2 has no terra/sf; python libcbm env has rasterio.
## Step 3 queued: scripts/04_pseudoage.R md5 144bb1b1acf1e219593869366a05b3b5 (run after px) -> out/pseudo
## Step 4 RUNNING: round trip (job 15683651) scripts/s43nd_build_v1.py md5 e1a96a171275e5ded8fdafab30ce08b0 (copy of s42fy_build_v1.py md5 5ff8da961491eabdb5bb61799c1fc2e8, curve source swapped) -> out/rt/{ST}
## DONE 19 Oct: px job 15683581; pseudo-age 04b (md5 5e9cccaa22d6f107471a3937a64383fb, job 15683770; first try 15683691 failed on by=); round trip job 15683651 (6 states rc=0); eval scripts/06_roundtrip_eval.R md5 8c79690e7c833ad97465308ac96a1f3a run on login node -> out/rt_eval; stress1 job 15683690 -> out/stress1_mixed.
## Summary: out/s43_trackB_cbm_netdriver_SUMMARY_20261019.md. Next (deferred): write pseudo-age inventory into libcbm inventory.csv; young-age round trip fix; gate run after amendment.
