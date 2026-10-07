# RUN.md, ncasi_s36_20261006 (6 Oct 2026, host ifm-kershaw, R version 4.5.1 (2025-06-13) -- "Great Square Root")

Aaron approved decisions 1 and 2 on 6 Oct 2026.

1. DRYBIO patch applied (patch_drybio_tons_20261001.py, md5 84abe265a3db) to scripts_20260929/build_initial_communities_v3_fb.R and tools/build_initial_communities{,_v2,_v3}.R, tools/_blockA.R; backups *_PREV_20261001. Patched v3_fb md5 cc9c01cc.
2. Stage three rebuilt for NH VT MI WI into states/<ST>/inputs/rebuild_20261006/initial_communities/ (rebuild_ic_20261006.sh); gates gate_rebuild_20261006.R all pass (R4 amended, v1 kept).
3. Anchored to EVALIDator 2024 stock in state only (anchor_ic_fourstate_fb_20261006.R, md5 b37c3fe42a89); gates pass; table anchor_fourstate_fb_20261006.tsv.
4. NOT DONE: promotion of rebuild_20261006/initial_communities to inputs/initial_communities (refused by the session permission classifier). Command for Aaron: for s in NH VT MI WI; do I=~/landis2_fb/states/$s/inputs; mv -n $I/initial_communities $I/initial_communities_PREV_20261006 && mv -n $I/rebuild_20261006/initial_communities $I/initial_communities && rmdir $I/rebuild_20261006; done
5. grm/: EVALIDator queries and realism comparison (grm_realism_20261006.R, md5 c2540f2d).

GitHub: not pushed; token absent on firebreather. Zenodo: not applicable, intermediate model inputs and diagnostics.

Input md5s: TreeMap2022_CONUS_Tree_Table.csv 29af436d7e32
