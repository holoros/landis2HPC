#!/usr/bin/env python3
"""NCASI s43 Track H: s41 FVS mortality recalibration refit on a plot level split (19 Oct 2026).
Imports the s41 script (copied unchanged, md5 769527f602ecd64ee9e8e34713d42865) and replaces only the half column:
plot key = Track D component root (PREV_PLT_CN chain, whitespace stripped); fit if int(md5(key)[:8],16) even.
Modes: repro (one s41 grid cell on the original pair split), splitsum, grid, score. Rule: RULE.md. Aggregates only
leave work/ (pair rows stay in work/)."""
import argparse, hashlib, itertools, os, sys, time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import numpy as np, pandas as pd
T = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/fvs_plotsplit")
sys.path.insert(0, str(T))
import fvsmr_run_20261015e as M
assert M.md5(T / "fvsmr_run_20261015e.py") == "769527f602ecd64ee9e8e34713d42865"
M.W = T / "work"   # never written by the functions used here; set defensively
S41 = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs")


def find(par, a):   # Track D, verbatim
    while par[a] != a:
        par[a] = par[par[a]]; a = par[a]
    return a


def plot_key(P):    # Track D fvsci_boot_20261019b.py plot_key(), verbatim
    t1 = P.t1_id.astype(str).str.strip().to_numpy(); t2 = P.pair_id.astype(str).str.strip().to_numpy()
    par = {}
    for a, b in zip(t1, t2):
        par.setdefault(a, a); par.setdefault(b, b)
        ra, rb = find(par, a), find(par, b)
        if ra != rb: par[rb] = ra
    return {b: find(par, b) for b in t2}


def half_plot(key):
    return "fit" if int(hashlib.md5(key.encode()).hexdigest()[:8], 16) % 2 == 0 else "hold"


def load_state_h(st, split):
    P, tg, coef = M.load_state(st)          # s41 half (pair split) already set
    PK = plot_key(P)
    P["pkey"] = [PK[p.strip()] for p in P.pair_id.astype(str)]
    if split == "plot":
        P["half"] = [half_plot(k) for k in P.pkey]
    return P, tg, coef


def subsample(P, cap):   # s41 grid mode logic, verbatim
    F = P[P.half == "fit"]
    frac = min(1.0, cap / len(F))
    return F.groupby("cls", group_keys=False).apply(lambda g: g.sample(frac=frac, random_state=M.SEED)) if frac < 1 else F


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", required=True, choices=["repro", "splitsum", "grid", "score"])
    ap.add_argument("--variant", choices=["ne", "ls"])
    ap.add_argument("--grid", type=int, default=1, choices=[1, 2, 3])
    ap.add_argument("--workers", type=int, default=46)
    ap.add_argument("--cap", type=int, default=1500)
    ap.add_argument("--scratch", default=os.environ.get("TMPDIR", "/tmp"))
    a = ap.parse_args()
    assert M.md5(Path(M.IKDIR, "inventory_keyfile.py")) == M.IK_MD5
    assert not [k for k in os.environ if k.startswith("FVS_MORT")]
    t0 = time.time()
    if a.mode == "splitsum":
        rows = []
        for st in ["ME", "NH", "VT", "MI", "WI", "MN"]:
            P, _, _ = load_state_h(st, "pair")
            P["hp"] = [half_plot(k) for k in P.pkey]
            span_pair = P.groupby("pkey").half.nunique(); span_plot = P.groupby("pkey").hp.nunique()
            leak = P.pkey.map(span_pair > 1)
            rows.append(dict(state=st, pairs=len(P), plots=P.pkey.nunique(), t1_missing=int(P.t1_id.isna().sum()),
                             max_pairs_per_plot=int(P.pkey.value_counts().max()),
                             pair_fit=int((P.half == "fit").sum()), pair_hold=int((P.half == "hold").sum()),
                             pair_hold_share_plot_in_fit=float(leak[P.half == "hold"].mean()),
                             plot_fit_pairs=int((P.hp == "fit").sum()), plot_hold_pairs=int((P.hp == "hold").sum()),
                             plot_fit_plots=int(P[P.hp == "fit"].pkey.nunique()), plot_hold_plots=int(P[P.hp == "hold"].pkey.nunique()),
                             plot_split_plots_spanning=int((span_plot > 1).sum()),
                             hold_pairs_same_half_both_splits=int(((P.half == "hold") & (P.hp == "hold")).sum())))
        df = pd.DataFrame(rows); df.to_csv(T / "fvsps_split_summary_20261019.csv", index=False)
        print(df.to_string(index=False)); print("SPLITSUM_DONE"); return
    variants = [a.variant] if a.variant else ["ne", "ls"]
    for v in variants:
        c = M.CFG[v]; cal = M.load_cal(v)
        print(f"variant {v}; binary md5 {M.md5(c['bin'])}; cal block md5 {hashlib.md5(cal.encode()).hexdigest()}", flush=True)
        with ProcessPoolExecutor(a.workers) as ex:
            if a.mode in ("repro", "grid"):
                split = "pair" if a.mode == "repro" else "plot"
                data = {}
                for st in c["states"]:
                    P, tg, coef = load_state_h(st, split)
                    S = subsample(P, a.cap); data[st] = (S, tg, coef)
                    print(st, split, "fit", int((P.half == "fit").sum()), "subsample", len(S), S.cls.value_counts().to_dict(), flush=True)
                if a.mode == "repro":
                    settings = [(1.0, 55.0, 95.0, 1.3, 0.01)]; gtag = "repro"
                else:
                    GG = {1: M.GRID, 2: M.GRID2, 3: M.GRID3}[a.grid]; gtag = f"grid{a.grid}"
                    settings = list(itertools.product(GG["kB"], GG["PL"], GG["PU"], GG["kS"], GG.get("fa", [0.0])))
                out = T / f"fvsps_{gtag}_{v}_20261019.csv"; rows = []
                for i, (kB, PL, PU, kS, fa) in enumerate(settings):
                    kw = M.modkw(cal, kB, PL, PU, kS)
                    for st in c["states"]:
                        S, tg, coef = data[st]
                        jobs = M.make_jobs(v, S, tg, coef, [("recal", kw, fa)], a.scratch)
                        R = pd.DataFrame(list(ex.map(M.run_pair, jobs, chunksize=8))); R["cycle"] = [j["cycle"] for j in jobs]
                        o = M.agg_metrics(R, S); o.update(variant=v, state=st, kB=kB, PL=PL, PU=PU, kS=kS, fa=fa)
                        rows.append(o)
                    if i % 12 == 0:
                        print(f"setting {i + 1}/{len(settings)} t={time.time() - t0:.0f}s", flush=True)
                        pd.DataFrame(rows).to_csv(out, index=False)
                pd.DataFrame(rows).to_csv(out, index=False)
                if a.mode == "repro":
                    ref = pd.read_csv(S41 / f"fvs_mortrecal_grid3_{v}_20261015.csv")
                    new = pd.DataFrame(rows); worst = 0.0
                    for r in new.itertuples():
                        m = ref[(ref.state == r.state) & np.isclose(ref.kB, r.kB) & np.isclose(ref.PL, r.PL) & np.isclose(ref.PU, r.PU)
                                & np.isclose(ref.kS, r.kS) & np.isclose(ref.fa, r.fa)]
                        assert len(m) == 1, f"ref rows {len(m)}"
                        for col in [k for k in new.columns if k not in ("variant", "state") and pd.api.types.is_numeric_dtype(new[k])]:
                            x, y = float(getattr(r, col)), float(m.iloc[0][col])
                            d = 0.0 if (np.isnan(x) and np.isnan(y)) else abs(x - y) / max(abs(y), 1e-12)
                            worst = max(worst, d)
                    print(f"REPRO max relative difference vs s41 grid3 row {worst:.3e}")
                    print("REPRO_GATE_PASS" if worst <= 1e-6 else "REPRO_GATE_FAIL", flush=True)
            elif a.mode == "score":
                ch = pd.read_csv(T / "fvsps_chosen_20261019.csv")
                for st in c["states"]:
                    P, tg, coef = load_state_h(st, "plot")
                    H = P[P.half == "hold"]
                    arms = [("default", ""), ("calibrated", cal)]
                    for r in ch[(ch.variant == v) & ((ch.scope == "variant") | (ch.state == st))].itertuples():
                        arms.append((f"recal_{r.scope}", M.modkw(cal, r.kB, r.PL, r.PU, r.kS), float(r.fa)))
                    jobs = M.make_jobs(v, H, tg, coef, arms, a.scratch)
                    R = pd.DataFrame(list(ex.map(M.run_pair, jobs, chunksize=8)))
                    R["arm"] = [j["arm"] for j in jobs]; R["cycle"] = [j["cycle"] for j in jobs]; R["state"] = st
                    R = R.merge(H[["pair_id", "pkey"]], on="pair_id", how="left")
                    R.to_csv(T / "work" / f"hold_pairs_{st}.csv", index=False)   # pair rows, stay on Cardinal
                    print(st, "holdout pairs", len(H), "runs", len(R), "ok", int(R.ok.sum()), "arms", [x[0] for x in arms], flush=True)
    print(f"MODE_DONE {a.mode} t={time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()
