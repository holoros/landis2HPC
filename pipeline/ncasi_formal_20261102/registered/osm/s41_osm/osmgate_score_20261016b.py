#!/usr/bin/env python3
"""NCASI Phase 1 OSM realism gate, Maine, step 2 of 2: reproduction check and scoring. Session 41, 16 Oct 2026.

Same scorer as fvsgate_score_20261015.py (pair means in Mg ha-1 yr-1, model / observed ratios on the same plots, 1,000
draw pair bootstrap with seed 20261015, gate pass bands 0.85 to 1.15 for gross, mortality and net and 0.80 to 1.25 for
gross above 200 Mg ha-1 at t1, bins 0-50-100-150-200-250-300-inf by t1 biomass). OSM gross = survivor growth + ingrowth,
because OSM adds ingrowth and FIA gross includes it. Stock is not scored: OSM starts from the FIA t1 tree list and its NSVB
biomass, so year 0 stock equals FIA by construction (checked here as osm_B1 / B1).

Reproduction check (before any scoring): the observed ME means over all gate pairs must equal the FVS gate's observed ME
means in fvs_gate_results_detail_20261015.csv (relative difference < 1e-12) with the same pair count; otherwise exit 2.
Writes only aggregates to /fs/scratch/.../s41/osm/: osm_gate_results_me_20261016.csv, osm_gate_bins_me_20261016.csv,
osm_gate_repro_me_20261016.csv, osm_gate_bgi_me_20261016.csv.
Sensitivity rows: pairs with observed BGI only, every OSM recruit counted as ingrowth whatever its size, and YPC 1 (annual).
"""
import sys
from pathlib import Path
import numpy as np
import pandas as pd

FW = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs")
O = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm")
K = 0.00112085
EV = (25.6128, 9.4943, 16.1185, 7002925)  # ME EVALIDator gross, mortality, net (Tg yr-1) and forest area (ha), plan amendment

P = pd.read_csv(FW / "work" / "pairs_ME.csv", dtype={"pair_id": str})
ref = pd.read_csv(FW / "fvs_gate_results_detail_20261015.csv")
ref = ref[(ref.state == "ME") & (ref.arm == "calibrated")].iloc[0]
mine = dict(pairs=len(P), obs_gross=P.obs_gg.mean(), obs_mort=P.obs_mort.mean(), obs_net=P.obs_net.mean(), obs_surv_only=P.obs_surv.mean())
rep = pd.DataFrame([dict(quantity=k, osm_scorer=v, fvs_gate=float(ref[k]), rel_diff=(v / float(ref[k]) - 1)) for k, v in mine.items()])
rep["pass"] = rep.rel_diff.abs() < 1e-12
rep.to_csv(O / "osm_gate_repro_me_20261016.csv", index=False)
print(rep.to_string(index=False))
if not rep["pass"].all():
    print("REPRODUCTION FAILED"); sys.exit(2)
print("REPRODUCTION PASSED")

def load(fname, ingr_col="osm_ingr"):
    R = pd.read_csv(O / "work" / fname, dtype={"pair_id": str})
    x = R.merge(P, on="pair_id", how="left", suffixes=("", "_p"))
    assert len(x) == len(P) == len(R), f"pair sets differ in {fname}"
    nf = int((~x.ok).sum()); x = x[x.ok].copy()
    for c in ["osm_surv", "osm_ingr", "osm_ingr_all", "osm_mort", "osm_mort_todie", "osm_B1"]:
        x[c] = x[c].fillna(0.0)
    x["osm_survr"] = x.osm_surv / x.cycle * K
    x["osm_ingrr"] = x[ingr_col] / x.cycle * K
    x["osm_gg"] = x.osm_survr + x.osm_ingrr
    x["osm_mort_r"] = x.osm_mort / x.cycle * K
    x["osm_net"] = x.osm_gg - x.osm_mort_r
    x["osm_B1_Mgha"] = x.osm_B1 * K
    return x, nf


x0, n_fail = load("osm_pairs_ME.csv")
# BGI coverage, aggregates only
bg = x0.groupby("bgi_src").agg(pairs=("pair_id", "size"), bgi_mean=("bgi", "mean"), bgi_min=("bgi", "min"), bgi_max=("bgi", "max")).reset_index()
bg.to_csv(O / "osm_gate_bgi_me_20261016.csv", index=False); print(bg.to_string(index=False))
variants = {"all_pairs": (x0, n_fail, np.ones(len(x0), bool)),
            "bgi_observed_only": (x0, n_fail, (x0.bgi_src != "median").to_numpy())}
xa, nfa = load("osm_pairs_ME.csv", "osm_ingr_all")
variants["all_recruits_as_ingrowth"] = (xa, nfa, np.ones(len(xa), bool))
if (O / "work" / "osm_pairs_ME_annual.csv").exists():
    xy, nfy = load("osm_pairs_ME_annual.csv")
    variants["annual_ypc1"] = (xy, nfy, np.ones(len(xy), bool))
rng = np.random.default_rng(20261015)
rows, bins = [], []
for name, (xv, nfv, sel) in variants.items():
    x = xv[sel].copy()
    dense = (x.B1_Mgha >= 200).to_numpy()
    A = x[["obs_gg", "obs_mort", "obs_net", "osm_gg", "osm_mort_r", "osm_net", "obs_surv", "osm_survr", "obs_ingr", "osm_ingrr"]].to_numpy()

    def ratios(idx):
        m = A[idx].mean(0); d = dense[idx]
        md = A[idx][d].mean(0) if d.any() else np.full(A.shape[1], np.nan)
        return np.array([m[3] / m[0], m[4] / m[1], m[5] / m[2], md[3] / md[0], m[7] / m[6], m[9] / m[8]])

    est = ratios(np.arange(len(x)))
    bs = np.array([ratios(rng.integers(0, len(x), len(x))) for _ in range(1000)])
    lo, hi = np.nanpercentile(bs, 2.5, 0), np.nanpercentile(bs, 97.5, 0)
    m = A.mean(0); evh = [EV[i] * 1e6 / EV[3] for i in range(3)]
    ok = [0.85 <= est[0] <= 1.15, 0.85 <= est[1] <= 1.15, 0.85 <= est[2] <= 1.15, 0.80 <= est[3] <= 1.25]
    rows.append(dict(state="ME", model="OSM Acadian 2.26.0", subset=name, pairs=len(x), osm_failed=nfv,
                     dense_pairs=int(dense.sum()), mean_cycle_yr=x.cycle.mean(), mean_remper_yr=x.REMPER.mean(),
                     obs_gross=m[0], obs_mort=m[1], obs_net=m[2], obs_surv=m[6], obs_ingr=m[8],
                     osm_gross=m[3], osm_mort=m[4], osm_net=m[5], osm_surv=m[7], osm_ingr=m[9],
                     ratio_gross=est[0], ratio_gross_lo=lo[0], ratio_gross_hi=hi[0], ratio_mort=est[1], ratio_mort_lo=lo[1], ratio_mort_hi=hi[1],
                     ratio_net=est[2], ratio_net_lo=lo[2], ratio_net_hi=hi[2], ratio_dense_gross=est[3], ratio_dense_lo=lo[3], ratio_dense_hi=hi[3],
                     ratio_surv=est[4], ratio_surv_lo=lo[4], ratio_surv_hi=hi[4], ratio_ingr=est[5], ratio_ingr_lo=lo[5], ratio_ingr_hi=hi[5],
                     mort_todie_check=(x.osm_mort_todie / x.cycle * K).mean() / m[4] if m[4] > 0 else np.nan,
                     stock_ratio_osm_to_fia=x.osm_B1_Mgha.sum() / x.B1_Mgha.sum(),
                     evalid_gross_ha=evh[0], evalid_mort_ha=evh[1], evalid_net_ha=evh[2],
                     osm_to_evalid_gross=m[3] / evh[0], osm_to_evalid_mort=m[4] / evh[1], osm_to_evalid_net=m[5] / evh[2],
                     pass_gross=ok[0], pass_mort=ok[1], pass_net=ok[2], pass_dense=ok[3], pass_all=all(ok),
                     stock="not scored (FIA t1 by construction)"))
    x["bin"] = pd.cut(x.B1_Mgha, [0, 50, 100, 150, 200, 250, 300, np.inf], right=False)
    b = x.groupby("bin", observed=True).agg(pairs=("pair_id", "size"), obs_gross=("obs_gg", "mean"), osm_gross=("osm_gg", "mean"),
                                             obs_surv=("obs_surv", "mean"), osm_surv=("osm_survr", "mean"), obs_ingr=("obs_ingr", "mean"),
                                             osm_ingr=("osm_ingrr", "mean"), obs_mort=("obs_mort", "mean"), osm_mort=("osm_mort_r", "mean"),
                                             obs_net=("obs_net", "mean"), osm_net=("osm_net", "mean")).reset_index()
    b["bin"] = b["bin"].astype(str); b["subset"] = name
    for q in ["gross", "surv", "ingr", "mort", "net"]:
        b[f"ratio_{q}"] = b[f"osm_{q}"] / b[f"obs_{q}"]
    bins.append(b)
res = pd.DataFrame(rows)
res.to_csv(O / "osm_gate_results_me_20261016.csv", index=False)
pd.concat(bins).to_csv(O / "osm_gate_bins_me_20261016.csv", index=False)
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 60)
print(res.T.to_string())
print(pd.concat(bins).round(3).to_string(index=False))
print("SCORE_DONE")
