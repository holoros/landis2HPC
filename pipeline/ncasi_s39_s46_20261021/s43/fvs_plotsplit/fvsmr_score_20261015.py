#!/usr/bin/env python3
"""NCASI Phase 1, session 41: holdout scoring of default, old calibrated and recalibrated FVS arms (15 Oct 2026).

Copy of fvsgate_score_20261015.py (job 15535345 scorer): same pair mean ratios, same 1,000 draw pair bootstrap
(seed 20261015), same frozen bands (gross, mortality, net 0.85 to 1.15; gross on pairs with t1 AGB >= 200 Mg/ha 0.80
to 1.25), same seven AGB bins. Changes: reads s41 holdout pair files, loops over every arm present, adds the bin
mortality ratio column. Outputs are state, arm and bin aggregates only.
"""
from pathlib import Path
import numpy as np
import pandas as pd

W0 = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs/work")
O = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs")
W = O / "work"
K = 0.00112085
VAR = {"ME": "NE", "NH": "NE", "VT": "NE", "MI": "LS", "WI": "LS", "MN": "LS"}
rng = np.random.default_rng(20261015)
rows, bins = [], []
for st in ["ME", "NH", "VT", "MI", "WI", "MN"]:
    P = pd.read_csv(W0 / f"pairs_{st}.csv", dtype={"pair_id": str})
    R = pd.read_csv(W / f"hold_pairs_{st}.csv", dtype={"pair_id": str})
    for arm in R.arm.unique():
        x = R[R.arm == arm].merge(P, on="pair_id", how="left")
        n_fail = int((~x.ok).sum()); x = x[x.ok].copy()
        x["fvs_gg"] = x.fvs_surv / x.cycle * K; x["fvs_mort_r"] = x.fvs_mort / x.cycle * K
        x["fvs_net"] = x.fvs_gg - x.fvs_mort_r
        dense = x.B1_Mgha >= 200
        A = x[["obs_gg", "obs_mort", "obs_net", "fvs_gg", "fvs_mort_r", "fvs_net", "obs_surv"]].to_numpy()
        dn = dense.to_numpy()
        def ratios(idx):
            m = A[idx].mean(0); md = A[idx][dn[idx]].mean(0) if dn[idx].any() else np.full(A.shape[1], np.nan)
            return np.array([m[3] / m[0], m[4] / m[1], m[5] / m[2], md[3] / md[0]])
        est = ratios(np.arange(len(x)))
        bs = np.array([ratios(rng.integers(0, len(x), len(x))) for _ in range(1000)])
        lo, hi = np.nanpercentile(bs, 2.5, 0), np.nanpercentile(bs, 97.5, 0)
        m = A.mean(0)
        ok = [0.85 <= est[0] <= 1.15, 0.85 <= est[1] <= 1.15, 0.85 <= est[2] <= 1.15, 0.80 <= est[3] <= 1.25]
        rows.append(dict(state=st, variant=VAR[st], arm=arm, pairs=len(x), fvs_failed=n_fail, dense_pairs=int(dn.sum()),
                         obs_gross=m[0], obs_mort=m[1], obs_net=m[2], fvs_gross=m[3], fvs_mort=m[4], fvs_net=m[5],
                         ratio_gross=est[0], ratio_gross_lo=lo[0], ratio_gross_hi=hi[0], ratio_mort=est[1], ratio_mort_lo=lo[1], ratio_mort_hi=hi[1],
                         ratio_net=est[2], ratio_net_lo=lo[2], ratio_net_hi=hi[2], ratio_dense_gross=est[3], ratio_dense_lo=lo[3], ratio_dense_hi=hi[3],
                         pass_gross=ok[0], pass_mort=ok[1], pass_net=ok[2], pass_dense=ok[3], pass_all=all(ok)))
        x["bin"] = pd.cut(x.B1_Mgha, [0, 50, 100, 150, 200, 250, 300, np.inf], right=False)
        b = x.groupby("bin", observed=True).agg(pairs=("pair_id", "size"), obs_gross=("obs_gg", "mean"), fvs_gross=("fvs_gg", "mean"),
                                                 obs_mort=("obs_mort", "mean"), fvs_mort=("fvs_mort_r", "mean")).reset_index()
        b["bin"] = b["bin"].astype(str).str.replace(",", " to"); b["state"] = st; b["arm"] = arm
        b["ratio_gross"] = b.fvs_gross / b.obs_gross; b["ratio_mort"] = b.fvs_mort / b.obs_mort
        bins.append(b)
res = pd.DataFrame(rows)
res.round(4).to_csv(O / "fvs_mortrecal_holdout_results_20261015.csv", index=False)
pd.concat(bins).round(4).to_csv(O / "fvs_mortrecal_holdout_bins_20261015.csv", index=False)
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 40)
print(res[["state", "arm", "pairs", "ratio_gross", "ratio_mort", "ratio_net", "ratio_dense_gross", "pass_gross", "pass_mort",
           "pass_net", "pass_dense", "pass_all"]].round(3).to_string(index=False))
print(res[["state", "arm", "ratio_gross_lo", "ratio_gross_hi", "ratio_mort_lo", "ratio_mort_hi", "ratio_net_lo", "ratio_net_hi",
           "ratio_dense_lo", "ratio_dense_hi", "fvs_failed", "dense_pairs"]].round(3).to_string(index=False))
print("SCORE_DONE")
