#!/usr/bin/env python3
"""NCASI s43 Track H scorer: odd plot holdout. Point ratios exactly as s41 fvsmr_score_20261015.py (pair mean ratios,
frozen bands, PASS = point in band for all four quantities). Intervals: 2,000 plot (cluster) bootstrap resamples,
seed 20261019 (Track D cluster method). Outputs aggregates only."""
from pathlib import Path
import numpy as np, pandas as pd
G = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015"); W0 = G / "fvs/work"; T = G / "s43/fvs_plotsplit"
REF = pd.read_csv(G / "s41/fvs/fvs_mortrecal_holdout_results_20261015.csv")
K = 0.00112085; B = 2000; SEED = 20261019
VAR = {"ME": "NE", "NH": "NE", "VT": "NE", "MI": "LS", "WI": "LS", "MN": "LS"}
Q = ["gross", "mort", "net", "dense_gross"]
REFCOL = {"gross": "ratio_gross", "mort": "ratio_mort", "net": "ratio_net", "dense_gross": "ratio_dense_gross"}
BAND = {"gross": (0.85, 1.15), "mort": (0.85, 1.15), "net": (0.85, 1.15), "dense_gross": (0.80, 1.25)}
rng = np.random.default_rng(SEED); rows = []
for st in ["ME", "NH", "VT", "MI", "WI", "MN"]:
    P = pd.read_csv(W0 / f"pairs_{st}.csv", dtype={"pair_id": str})
    R = pd.read_csv(T / "work" / f"hold_pairs_{st}.csv", dtype={"pair_id": str, "pkey": str})
    for arm in R.arm.unique():
        x = R[R.arm == arm].merge(P, on="pair_id", how="left")
        nf = int((~x.ok).sum()); x = x[x.ok].copy().reset_index(drop=True)
        x["fvs_gg"] = x.fvs_surv / x.cycle * K; x["fvs_mort_r"] = x.fvs_mort / x.cycle * K; x["fvs_net"] = x.fvs_gg - x.fvs_mort_r
        A = x[["obs_gg", "obs_mort", "obs_net", "fvs_gg", "fvs_mort_r", "fvs_net"]].to_numpy(); dn = (x.B1_Mgha >= 200).to_numpy()
        def ratios(idx):
            m = A[idx].mean(0); d = dn[idx]
            md = A[idx][d].mean(0) if d.any() else np.full(6, np.nan)
            return np.array([m[3] / m[0], m[4] / m[1], m[5] / m[2], md[3] / md[0]])
        n = len(x); est = ratios(np.arange(n))
        codes, inv = np.unique(x.pkey.to_numpy(), return_inverse=True); nc = len(codes)
        members = [np.flatnonzero(inv == c) for c in range(nc)]
        bc = np.array([ratios(np.concatenate([members[c] for c in rng.integers(0, nc, nc)])) for _ in range(B)])
        ref = REF[(REF.state == st) & (REF.arm == arm)]
        for j, q in enumerate(Q):
            lo, hi = BAND[q]
            rows.append(dict(state=st, variant=VAR[st], arm=arm, quantity=q, pairs=n, plots=nc, fvs_failed=nf, dense_pairs=int(dn.sum()),
                             point=est[j], clus_lo=np.nanpercentile(bc[:, j], 2.5), clus_hi=np.nanpercentile(bc[:, j], 97.5),
                             clus_frac_in_band=float(np.mean((bc[:, j] >= lo) & (bc[:, j] <= hi))), band_lo=lo, band_hi=hi,
                             verdict="PASS" if lo <= est[j] <= hi else "FAIL",
                             s41_point=float(ref.iloc[0][REFCOL[q]]) if len(ref) else np.nan))
res = pd.DataFrame(rows)
res["s41_verdict"] = np.where(res.s41_point.isna(), "NA", np.where((res.s41_point >= res.band_lo) & (res.s41_point <= res.band_hi), "PASS", "FAIL"))
res.round(4).to_csv(T / "fvsps_holdout_results_20261019.csv", index=False)
allp = res.groupby(["state", "arm"]).apply(lambda d: pd.Series(dict(h_all="PASS" if (d.verdict == "PASS").all() else "FAIL",
       s41_all="NA" if (d.s41_verdict == "NA").any() else ("PASS" if (d.s41_verdict == "PASS").all() else "FAIL")))).reset_index()
allp.to_csv(T / "fvsps_holdout_verdicts_20261019.csv", index=False)
print(allp.to_string(index=False)); print("SCORE_DONE")
