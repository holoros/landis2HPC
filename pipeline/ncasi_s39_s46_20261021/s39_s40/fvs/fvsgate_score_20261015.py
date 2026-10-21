#!/usr/bin/env python3
"""NCASI Phase 1 FVS realism gate, step 3 of 3: scoring against the pre-registered plan (15 Oct 2026).

Per state and arm, over gate pairs where FVS ran: unweighted pair means (Mg ha-1 yr-1) of observed and FVS gross growth,
mortality and net growth; ratio FVS / observed (primary, same plots) with a 1,000 draw pair bootstrap 95 percent interval;
FVS / EVALIDator per hectare rate (secondary, state population, includes disturbed land); and the dense class ratio,
mean FVS gross growth / mean observed gross growth over pairs with t1 live AGB >= 200 Mg ha-1. Pass per the plan:
gross, mortality and net within 0.85 to 1.15, dense class within 0.80 to 1.25. Stock is not scored: FVS starts from the
FIA t1 tree list and its NSVB biomass, so the year 0 stock equals FIA by construction.
"""
from pathlib import Path
import numpy as np
import pandas as pd

W = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs/work")
O = W.parent
K = 0.00112085
# EVALIDator 2024 (Tg yr-1) and measured FIA forest area (ha), from the gate plan and its amendment
EV = {"NH": (8.253, 2.782, 5.470, 1910089), "VT": (7.609, 2.986, 4.623, 1792058), "MI": (31.774, 13.045, 18.729, 7790021),
      "WI": (29.041, 10.126, 18.914, 6723136), "ME": (25.6128, 9.4943, 16.1185, 7002925), "MN": (25.1058, 10.6370, 14.4688, 7076703)}
VAR = {"ME": "NE", "NH": "NE", "VT": "NE", "MI": "LS", "WI": "LS", "MN": "LS"}
rng = np.random.default_rng(20261015)
rows, bins = [], []
for st in ["ME", "NH", "VT", "MI", "WI", "MN"]:
    P = pd.read_csv(W / f"pairs_{st}.csv", dtype={"pair_id": str})
    R = pd.read_csv(W / f"fvs_pairs_{st}.csv", dtype={"pair_id": str})
    for arm in ["default", "calibrated"]:
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
        m = A.mean(0); ev = EV[st]; area = ev[3]
        ev_ha = [ev[0] * 1e6 / area, ev[1] * 1e6 / area, ev[2] * 1e6 / area]
        ok = [0.85 <= est[0] <= 1.15, 0.85 <= est[1] <= 1.15, 0.85 <= est[2] <= 1.15, 0.80 <= est[3] <= 1.25]
        rows.append(dict(state=st, variant=VAR[st], arm=arm, pairs=len(x), fvs_failed=n_fail, dense_pairs=int(dn.sum()),
                         mean_cycle_yr=round(x.cycle.mean(), 2), mean_remper_yr=round(x.REMPER.mean(), 2),
                         obs_gross=m[0], obs_mort=m[1], obs_net=m[2], obs_surv_only=m[6], fvs_gross=m[3], fvs_mort=m[4], fvs_net=m[5],
                         ratio_gross=est[0], ratio_gross_lo=lo[0], ratio_gross_hi=hi[0], ratio_mort=est[1], ratio_mort_lo=lo[1], ratio_mort_hi=hi[1],
                         ratio_net=est[2], ratio_net_lo=lo[2], ratio_net_hi=hi[2], ratio_dense_gross=est[3], ratio_dense_lo=lo[3], ratio_dense_hi=hi[3],
                         ratio_gross_vs_surv_only=m[3] / m[6],
                         evalid_gross_ha=ev_ha[0], evalid_mort_ha=ev_ha[1], evalid_net_ha=ev_ha[2],
                         fvs_to_evalid_gross=m[3] / ev_ha[0], fvs_to_evalid_mort=m[4] / ev_ha[1], fvs_to_evalid_net=m[5] / ev_ha[2],
                         obs_to_evalid_gross=m[0] / ev_ha[0], obs_to_evalid_mort=m[1] / ev_ha[1], obs_to_evalid_net=m[2] / ev_ha[2],
                         pass_gross=ok[0], pass_mort=ok[1], pass_net=ok[2], pass_dense=ok[3], pass_all=all(ok),
                         stock="not scored (FIA t1 by construction)"))
        x["bin"] = pd.cut(x.B1_Mgha, [0, 50, 100, 150, 200, 250, 300, np.inf], right=False)
        b = x.groupby("bin", observed=True).agg(pairs=("pair_id", "size"), obs_gross=("obs_gg", "mean"), fvs_gross=("fvs_gg", "mean"),
                                                 obs_mort=("obs_mort", "mean"), fvs_mort=("fvs_mort_r", "mean")).reset_index()
        b["bin"] = b["bin"].astype(str); b["state"] = st; b["arm"] = arm; b["ratio_gross"] = b.fvs_gross / b.obs_gross
        bins.append(b)
res = pd.DataFrame(rows)
res.to_csv(O / "fvs_gate_results_detail_20261015.csv", index=False)
pd.concat(bins).to_csv(O / "fvs_gate_bins_20261015.csv", index=False)
short = res[["state", "variant", "arm", "pairs", "ratio_gross", "ratio_mort", "ratio_net", "ratio_dense_gross",
             "pass_gross", "pass_mort", "pass_net", "pass_dense", "pass_all", "obs_gross", "obs_mort", "obs_net",
             "fvs_gross", "fvs_mort", "fvs_net", "fvs_to_evalid_gross", "fvs_to_evalid_mort", "fvs_to_evalid_net"]]
short.round(3).to_csv(O / "fvs_gate_results_20261015.csv", index=False)
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 40)
print(short.round(3).to_string(index=False))
print(res[["state", "arm", "ratio_gross_lo", "ratio_gross_hi", "ratio_mort_lo", "ratio_mort_hi", "ratio_net_lo", "ratio_net_hi",
           "ratio_dense_lo", "ratio_dense_hi", "ratio_gross_vs_surv_only", "obs_to_evalid_gross", "obs_to_evalid_mort", "obs_to_evalid_net",
           "fvs_failed", "dense_pairs", "mean_cycle_yr", "mean_remper_yr"]].round(3).to_string(index=False))
print("SCORE_DONE")
