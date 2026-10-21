#!/usr/bin/env python3
"""NCASI Phase 1, session 41: FVS mortality recalibration against FIA remeasured pairs (15 Oct 2026).

Extends fvsgate_run_20261015.py (job 15535345). run_pair below is that script's run_pair with two additions only:
  (1) the calibrated keyword block can carry recalibrated mortality keywords (modkw), and
  (2) a multi cycle mode for the 50 year sanity projection (event monitor BSDI and BSDIMAX, FVS_Summary SDI).
The single cycle path is byte for byte the same logic, which the reproduction gate checks.

Modes
  repro   calibrated arm and null knob arm on 40 pairs per state vs job 15535345 pair values
  split   deterministic md5 split of every state's pairs into fit and holdout halves (pair ids stay on Cardinal)
  grid    pre-registered grid on a stratified fit half subsample; aggregate metrics per setting and state
  score   default, old calibrated and recalibrated arms on all holdout pairs (pair rows stay on Cardinal)
  sanity  50 year projection, 200 holdout stands per variant, old calibrated vs recalibrated; aggregates only
Pre-registered plan: fvs_mortrecal_PLAN_20261015.md.
"""
import argparse, hashlib, itertools, json, os, shutil, sqlite3, subprocess, sys, tempfile, time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import numpy as np
import pandas as pd

LBAC_TO_MGHA = 0.00112085
W0 = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs/work")      # job 15535345 inputs, read only
S41 = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs")
W = S41 / "work"
CFG = {
    "ne": dict(states=["ME", "NH", "VT"], tree=Path("/fs/scratch/PUOM0008/crsfaaron/v1tag_20260811"),
               bin="/users/PUOM0008/crsfaaron/fvs-modern/bin-v1_20260906/FVSne"),
    "ls": dict(states=["MI", "WI", "MN"], tree=Path("/users/PUOM0008/crsfaaron/ncasi_fvsls/fm_frame"),
               bin="/users/PUOM0008/crsfaaron/fvs-modern/bin-v1_20260906/FVSls"),
}
IKDIR = "/users/PUOM0008/crsfaaron/fvs-modern/calibration/python"
IK_MD5 = "4804454a8aff48e948f659965fd597ee"
CLASS_EDGES = [0, 100, 200, 250, np.inf]
CLASS_LAB = ["c0_100", "c100_200", "c200_250", "c250p"]
SEED = 20261016
GRID = dict(kB=[1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0], PL=[55.0, 65.0, 75.0], PU=[85.0, 90.0, 95.0], kS=[1.0, 1.25, 1.5])


def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()


def half_of(pid):
    return "fit" if int(hashlib.md5(pid.encode()).hexdigest()[:8], 16) % 2 == 0 else "hold"


def modkw(cal, kB=1.0, PL=55.0, PU=85.0, kS=1.0):
    """Recalibrated mortality keywords inside the calibrated block. Growth keywords untouched."""
    out, put_mm = [], False
    for l in cal.split("\n"):
        if l.startswith("MORTMULT"):
            if not put_mm:
                out.append(f"{'MORTMULT':<10}{'':>10}{0:>10d}{kB:>10.4f}{0.0:>10.1f}{999.0:>10.1f}")
                put_mm = True
            if kB != 1.0:
                sp, m, d1, d2 = l[20:30], float(l[30:40]), l[40:50], l[50:60]
                l = f"{'MORTMULT':<10}{'':>10}{sp}{m * kB:>10.4f}{d1}{d2}"
        elif l.startswith("SDIMAX") and kS != 1.0:
            l = f"{l[:20]}{float(l[20:30]) * kS:>10.1f}{l[30:]}"
        out.append(l)
    if not put_mm:
        out.append(f"{'MORTMULT':<10}{'':>10}{0:>10d}{kB:>10.4f}{0.0:>10.1f}{999.0:>10.1f}")
    out.append(f"{'SDIMAX':<10}{'':>10}{'':>10}{'':>10}{'':>10}{PL:>10.1f}{PU:>10.1f}")
    return "\n".join(out)


def run_pair(job):
    sys.path.insert(0, IKDIR)
    import inventory_keyfile as ik
    v = job["variant"]
    trees = pd.DataFrame(job["trees"])
    out = {"pair_id": job["pair_id"], "ok": False, "n_static": 0, "n_trees": len(trees)}
    ncyc = job.get("ncyc", 1)
    if len(trees) == 0:
        out.update(ok=True, fvs_surv=0.0, fvs_mort=0.0, fvs_B1=0.0, note="no_t1_trees")
        return out
    res = [ik.resolve_fvs_code(int(s), v, use_spctrn=True, other_fallback=True)[0] for s in trees["SPCD"]]
    trees["alpha"] = res
    static = trees[trees["alpha"].isna()]
    fv = trees[trees["alpha"].notna()].copy()
    out["n_static"] = len(static)
    fv["first"] = (fv["SPCD"] == job["sisp"]).astype(int)
    fv = fv.sort_values("first", ascending=False, kind="stable").reset_index(drop=True)
    fv["tree_num"] = np.arange(1, len(fv) + 1)
    cr_missing = set(fv.loc[fv["CR"].isna() | (fv["CR"] <= 0), "tree_num"])
    tdf = pd.DataFrame({"tree_count": fv["TPA_UNADJ"], "species": fv["SPCD"].astype(int), "diameter": fv["DIA"].clip(upper=99.9),
                        "ht": fv["HT"].fillna(0).clip(lower=0), "crratio": fv["CR"].fillna(50).where(fv["CR"] > 0, 50)})
    sdf = pd.DataFrame([job["stand"]])
    n = job["cycle"]
    if ncyc == 1:
        extra = ("NOTRIPLE\n" f"TIMEINT   {0:>10d}{n:>10d}\n" "TREELIST           0\n"
                 "DATABASE\nDSNOUT\nfvsout.db\nTREELIDB           2\nEND")
    else:
        extra = ("NOTRIPLE\n" f"TIMEINT   {0:>10d}{n:>10d}\n" "TREELIST           0\n"
                 "DATABASE\nDSNOUT\nfvsout.db\nTREELIDB           2\nSUMMARY\nCOMPUTDB\nEND\n"
                 "COMPUTE            0\nSDIB = BSDI\nSDIM = BSDIMAX\nEND")
    if job["cal_kw"]:
        extra += "\n" + job["cal_kw"]
    key = ik.make_inventory_keyfile(stand_df=sdf, tree_df=tdf, stand_id="P" + job["pair_id"][-12:], variant=v,
                                    inv_year=int(job["inv_year"]), num_cycles=ncyc, calibration_keywords=extra,
                                    use_spctrn=True, spctrn_other_fallback=True)
    lines = key.split("\n")
    i0 = next(i for i, l in enumerate(lines) if l.startswith("TREEDATA")) + 1
    for k in range(len(fv)):
        if (k + 1) in cr_missing:
            l = lines[i0 + k]
            lines[i0 + k] = l[:34] + " " + l[35:]
    key = "\n".join(lines)
    work = tempfile.mkdtemp(prefix="fm_", dir=job["scratch"])
    try:
        Path(work, "s.key").write_text(key)
        env = dict(os.environ); env.pop("FVS_GREGDG", None); env.pop("FVS_GREGHG", None)
        r = subprocess.run([job["bin"], "--keywordfile=s.key"], cwd=work, env=env, capture_output=True, timeout=300)
        db = Path(work, "fvsout.db")
        if not db.exists():
            out["note"] = f"no db rc={r.returncode}"; return out
        con = sqlite3.connect(str(db))
        tl = pd.read_sql("select Year, TreeId, TPA, DBH, Ht from FVS_TreeList", con)
        if ncyc > 1:
            tabs = set(pd.read_sql("select name from sqlite_master where type='table'", con)["name"])
            sm = pd.read_sql("select * from FVS_Summary", con) if "FVS_Summary" in tabs else pd.DataFrame()
            cp = pd.read_sql("select * from FVS_Compute", con) if "FVS_Compute" in tabs else pd.DataFrame()
        con.close()
        y0 = int(job["inv_year"])
        tl["tree_num"] = tl["TreeId"].astype(str).str[1:].astype(int)
        fv = fv.set_index("tree_num")
        co = job["coef"]
        keyc = [s if s in co else (-1 if s < 300 else -2) for s in fv["SPCD"].astype(int)]
        bb = np.array([co[k][0] for k in keyc]); cc = np.array([co[k][1] for k in keyc])
        b1 = fv["DRYBIO_AG"].values
        stat_b = float(np.sum(static["TPA_UNADJ"] * static["DRYBIO_AG"]))
        if ncyc == 1:
            y1 = y0 + n
            if set(tl["Year"]) != {y0, y1}:
                out["note"] = f"years {sorted(set(tl['Year']))}"; return out
            a = tl[tl["Year"] == y0].set_index("tree_num"); b = tl[tl["Year"] == y1].set_index("tree_num")
            if len(a) != len(fv) or len(b) != len(fv):
                out["note"] = f"records {len(a)} {len(b)} vs {len(fv)}"; return out
            D1, H1 = a.loc[fv.index, "DBH"].values, a.loc[fv.index, "Ht"].values
            D2, H2 = b.loc[fv.index, "DBH"].values, b.loc[fv.index, "Ht"].values
            T1, T2 = a.loc[fv.index, "TPA"].values, b.loc[fv.index, "TPA"].values
            b2 = b1 * np.exp(bb * (np.log(D2) - np.log(D1)) + cc * (np.log(H2) - np.log(H1)))
            out.update(ok=True, fvs_surv=float(np.sum(T2 * (b2 - b1))), fvs_mort=float(np.sum((T1 - T2) * b1)),
                       fvs_B1=float(np.sum(T1 * b1) + stat_b), fvs_B2=float(np.sum(T2 * b2) + stat_b),
                       tpa_start=float(T1.sum()), tpa_end=float(T2.sum()), note="")
            return out
        # multi cycle: AGB per year with the same per tree emulator ratio, anchored at year 0
        a = tl[tl["Year"] == y0].set_index("tree_num")
        if len(a) != len(fv):
            out["note"] = f"records y0 {len(a)} vs {len(fv)}"; return out
        D1, H1 = a.loc[fv.index, "DBH"].values, a.loc[fv.index, "Ht"].values
        traj = {}
        for yr, g in tl.groupby("Year"):
            g = g.set_index("tree_num").reindex(fv.index)
            T = g["TPA"].fillna(0).values
            D = g["DBH"].fillna(pd.Series(D1, index=fv.index)).values
            H = g["Ht"].fillna(pd.Series(H1, index=fv.index)).values
            bt = b1 * np.exp(bb * (np.log(np.maximum(D, 0.1)) - np.log(D1)) + cc * (np.log(np.maximum(H, 0.1)) - np.log(H1)))
            traj[int(yr) - y0] = float(np.sum(T * bt) + stat_b)
        sdi = {int(r.Year) - y0: float(r.SDI) for r in sm.itertuples()} if len(sm) and "SDI" in sm.columns else {}
        sdim = {int(r.Year) - y0: float(r.SDIM) for r in cp.itertuples()} if len(cp) and "SDIM" in cp.columns else {}
        sdib = {int(r.Year) - y0: float(r.SDIB) for r in cp.itertuples()} if len(cp) and "SDIB" in cp.columns else {}
        out.update(ok=True, traj=json.dumps(traj), sdi=json.dumps(sdi), sdim=json.dumps(sdim), sdib=json.dumps(sdib), note="")
        return out
    except Exception as e:  # recorded, never silent
        out["note"] = f"error {type(e).__name__}: {e}"[:200]; return out
    finally:
        shutil.rmtree(work, ignore_errors=True)


def load_cal(variant):
    c = CFG[variant]
    sys.path.insert(0, str(c["tree"]))
    for m in [m for m in sys.modules if m == "config" or m.startswith("config.")]:
        sys.modules.pop(m)
    from config.config_loader import FvsConfigLoader
    cal = FvsConfigLoader(variant, version="calibrated", config_dir=str(c["tree"] / "config")).generate_keywords(include_comments=False)
    sys.path.pop(0)
    return cal


def load_state(st):
    P = pd.read_csv(W0 / f"pairs_{st}.csv", dtype={"pair_id": str, "t1_id": str})
    T = pd.read_csv(W0 / f"trees_{st}.csv", dtype={"pair_id": str, "tree_cn": str})
    co = pd.read_csv(W0 / "emul_coef_20261015.csv")
    coef = {int(r.SPCD): (r.b, r.c) for r in co[co.state == st].itertuples()}
    P["half"] = [half_of(p) for p in P.pair_id]
    # state level fill values, computed on the full state table exactly as job 15535345 did
    P["si_med"] = float(P.loc[P.SICOND_FVS > 0, "SICOND_FVS"].median()); P["age_med"] = float(P.loc[P.STDAGE > 0, "STDAGE"].median())
    P["cls"] = pd.cut(P.B1_Mgha, CLASS_EDGES, right=False, labels=CLASS_LAB).astype(str)
    return P, dict(tuple(T.groupby("pair_id"))), coef


def make_jobs(variant, P, tg, coef, arms, scratch, ncyc=1, cycle_len=None):
    c = CFG[variant]
    si_med = float(P.si_med.iloc[0]); age_med = float(P.age_med.iloc[0])
    jobs = []
    for arm, kw in arms:
        for r in P.itertuples():
            si = r.SICOND_FVS if (pd.notna(r.SICOND_FVS) and r.SICOND_FVS > 0) else si_med
            age = r.STDAGE if (pd.notna(r.STDAGE) and r.STDAGE > 0) else age_med
            stand = dict(site_index=float(si), age=float(age), aspect=float(r.ASPECT if pd.notna(r.ASPECT) else 0),
                         slope=float(r.SLOPE if pd.notna(r.SLOPE) else 5), elevft=float(r.ELEV if pd.notna(r.ELEV) else 1000),
                         forest_type=int(r.FORTYPCD) if pd.notna(r.FORTYPCD) else None)
            if stand["forest_type"] is None:
                stand.pop("forest_type")
            tr = tg.get(r.pair_id)
            jobs.append(dict(variant=variant, pair_id=r.pair_id, arm=arm, cal_kw=kw, bin=c["bin"], scratch=scratch,
                             inv_year=int(r.INVYR1), cycle=(cycle_len if cycle_len else max(1, int(round(r.REMPER)))), stand=stand,
                             sisp=int(r.SISP_FVS) if pd.notna(r.SISP_FVS) else -9, coef=coef, ncyc=ncyc,
                             trees=(tr[["SPCD", "DIA", "HT", "CR", "TPA_UNADJ", "DRYBIO_AG"]].to_dict("records") if tr is not None else [])))
    return jobs


def agg_metrics(R, P):
    """Pair mean rates (Mg/ha/yr) and gate ratios for one state and one setting; aggregates only."""
    x = R.merge(P[["pair_id", "obs_gg", "obs_mort", "obs_net", "B1_Mgha", "cls"]], on="pair_id", how="left")
    nf = int((~x.ok).sum()); x = x[x.ok].copy()
    x["fvs_gg"] = x.fvs_surv / x.cycle * LBAC_TO_MGHA; x["fvs_mr"] = x.fvs_mort / x.cycle * LBAC_TO_MGHA
    x["fvs_net"] = x.fvs_gg - x.fvs_mr
    d = x.B1_Mgha >= 200
    o = dict(pairs=len(x), failed=nf, obs_gross=x.obs_gg.mean(), obs_mort=x.obs_mort.mean(), obs_net=x.obs_net.mean(),
             fvs_gross=x.fvs_gg.mean(), fvs_mort=x.fvs_mr.mean(), fvs_net=x.fvs_net.mean(),
             r_gross=x.fvs_gg.mean() / x.obs_gg.mean(), r_mort=x.fvs_mr.mean() / x.obs_mort.mean(),
             r_net=x.fvs_net.mean() / x.obs_net.mean(), r_dense=x.fvs_gg[d].mean() / x.obs_gg[d].mean(), dense_pairs=int(d.sum()))
    for c in CLASS_LAB:
        s = x.cls == c
        o[f"n_{c}"] = int(s.sum()); o[f"obsm_{c}"] = x.obs_mort[s].mean(); o[f"fvsm_{c}"] = x.fvs_mr[s].mean()
        o[f"rm_{c}"] = o[f"fvsm_{c}"] / o[f"obsm_{c}"] if s.any() else np.nan
    return o


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", required=True, choices=["repro", "split", "grid", "score", "sanity"])
    ap.add_argument("--variant", choices=["ne", "ls"])
    ap.add_argument("--workers", type=int, default=46)
    ap.add_argument("--cap", type=int, default=1500)
    ap.add_argument("--chosen", default=str(S41 / "fvs_mortrecal_chosen_20261015.csv"))
    ap.add_argument("--scratch", default=os.environ.get("TMPDIR", "/tmp"))
    a = ap.parse_args()
    W.mkdir(parents=True, exist_ok=True)
    assert md5(Path(IKDIR, "inventory_keyfile.py")) == IK_MD5, "inventory_keyfile.py md5 changed"
    bad = [k for k in os.environ if k.startswith("FVS_MORT")]
    assert not bad, f"FVS_MORT env set: {bad}"
    t0 = time.time()

    if a.mode == "split":
        rows = []
        for st in ["ME", "NH", "VT", "MI", "WI", "MN"]:
            P, _, _ = load_state(st)
            P[["pair_id", "half", "cls"]].to_csv(W / f"split_{st}.csv", index=False)
            for (h, c), g in P.groupby(["half", "cls"]):
                rows.append(dict(state=st, half=h, cls=c, pairs=len(g), mean_obs_mort=g.obs_mort.mean(), mean_B1=g.B1_Mgha.mean()))
        pd.DataFrame(rows).to_csv(S41 / "fvs_mortrecal_split_20261015.csv", index=False)
        print(pd.DataFrame(rows).to_string(index=False)); print("SPLIT_DONE", flush=True); return

    variants = [a.variant] if a.variant else ["ne", "ls"]
    for v in variants:
        c = CFG[v]
        cal = load_cal(v)
        print(f"variant {v}; binary md5 {md5(c['bin'])}; cal block md5 {hashlib.md5(cal.encode()).hexdigest()} lines {len(cal.splitlines())}", flush=True)
        with ProcessPoolExecutor(a.workers) as ex:
            if a.mode == "repro":
                rows = []
                for st in c["states"]:
                    P, tg, coef = load_state(st)
                    S = P.sample(n=40, random_state=SEED)
                    old = pd.read_csv(W0 / f"fvs_pairs_{st}.csv", dtype={"pair_id": str})
                    old = old[(old.arm == "calibrated") & old.pair_id.isin(S.pair_id)].set_index("pair_id")
                    jobs = make_jobs(v, S, tg, coef, [("calibrated", cal), ("nullknob", modkw(cal))], a.scratch)
                    R = pd.DataFrame(list(ex.map(run_pair, jobs, chunksize=4))); R["arm"] = [j["arm"] for j in jobs]
                    for arm in ["calibrated", "nullknob"]:
                        x = R[R.arm == arm].set_index("pair_id").loc[old.index]
                        md = 0.0
                        for col in ["fvs_surv", "fvs_mort", "fvs_B1", "fvs_B2", "tpa_start", "tpa_end"]:
                            o, n_ = old[col].astype(float).values, x[col].astype(float).values
                            rel = np.nanmax(np.abs(o - n_) / np.maximum(np.abs(o), 1e-9)) if len(o) else 0.0
                            md = max(md, float(np.nan_to_num(rel, nan=0.0)))
                            if np.isnan(o).sum() != np.isnan(n_).sum():
                                md = np.inf
                        rows.append(dict(variant=v, state=st, arm=arm, pairs=len(x), ok=int(x.ok.sum()), max_rel_diff=md, pass_=md <= 1e-6))
                    print(st, "repro", rows[-2:], flush=True)
                # sanity mode smoke: 3 stands, 2 cycles, compute and summary tables
                P, tg, coef = load_state(c["states"][0])
                jobs = make_jobs(v, P.sample(n=3, random_state=SEED), tg, coef, [("calibrated", cal)], a.scratch, ncyc=2, cycle_len=10)
                for r in ex.map(run_pair, jobs):
                    print("sanity smoke", r.get("ok"), r.get("note"), r.get("traj"), r.get("sdi"), r.get("sdim"), r.get("sdib"), flush=True)
                df = pd.DataFrame(rows)
                p = S41 / "fvs_mortrecal_repro_20261015.csv"
                df.to_csv(p, mode="a", header=not p.exists(), index=False)
                print(df.to_string(index=False), flush=True)

            elif a.mode == "grid":
                data = {}
                for st in c["states"]:
                    P, tg, coef = load_state(st)
                    F = P[P.half == "fit"]
                    frac = min(1.0, a.cap / len(F))
                    S = F.groupby("cls", group_keys=False).apply(lambda g: g.sample(frac=frac, random_state=SEED)) if frac < 1 else F
                    data[st] = (S, tg, coef)
                    print(st, "fit", len(F), "subsample", len(S), S.cls.value_counts().to_dict(), flush=True)
                rows = []
                settings = list(itertools.product(GRID["kB"], GRID["PL"], GRID["PU"], GRID["kS"]))
                for i, (kB, PL, PU, kS) in enumerate(settings):
                    kw = modkw(cal, kB, PL, PU, kS)
                    for st in c["states"]:
                        S, tg, coef = data[st]
                        jobs = make_jobs(v, S, tg, coef, [("recal", kw)], a.scratch)
                        R = pd.DataFrame(list(ex.map(run_pair, jobs, chunksize=8))); R["cycle"] = [j["cycle"] for j in jobs]
                        o = agg_metrics(R, S); o.update(variant=v, state=st, kB=kB, PL=PL, PU=PU, kS=kS)
                        rows.append(o)
                    if i % 12 == 0:
                        print(f"setting {i + 1}/{len(settings)} {kB} {PL} {PU} {kS} t={time.time() - t0:.0f}s", rows[-1]["r_mort"], flush=True)
                        pd.DataFrame(rows).to_csv(S41 / f"fvs_mortrecal_grid_{v}_20261015.csv", index=False)
                pd.DataFrame(rows).to_csv(S41 / f"fvs_mortrecal_grid_{v}_20261015.csv", index=False)

            elif a.mode == "score":
                ch = pd.read_csv(a.chosen)
                for st in c["states"]:
                    P, tg, coef = load_state(st)
                    H = P[P.half == "hold"]
                    arms = [("default", ""), ("calibrated", cal)]
                    for r in ch[(ch.variant == v) & ((ch.scope == "variant") | (ch.state == st))].itertuples():
                        arms.append((f"recal_{r.scope}", modkw(cal, r.kB, r.PL, r.PU, r.kS)))
                    jobs = make_jobs(v, H, tg, coef, arms, a.scratch)
                    R = pd.DataFrame(list(ex.map(run_pair, jobs, chunksize=8)))
                    R["arm"] = [j["arm"] for j in jobs]; R["cycle"] = [j["cycle"] for j in jobs]; R["state"] = st
                    R.to_csv(W / f"hold_pairs_{st}.csv", index=False)
                    print(st, "holdout pairs", len(H), "runs", len(R), "ok", int(R.ok.sum()), "arms", [x[0] for x in arms],
                          f"t={time.time() - t0:.0f}s", flush=True)

            elif a.mode == "sanity":
                ch = pd.read_csv(a.chosen)
                r = ch[(ch.variant == v) & (ch.scope == "variant")].iloc[0]
                new = modkw(cal, r.kB, r.PL, r.PU, r.kS)
                parts = []
                for st in c["states"]:
                    P, tg, coef = load_state(st)
                    parts.append((st, P[P.half == "hold"], tg, coef))
                allH = pd.concat([p[1] for p in parts])
                pick = allH.groupby("cls", group_keys=False).apply(lambda g: g.sample(n=min(50, len(g)), random_state=SEED))
                rows = []
                for st, H, tg, coef in parts:
                    S = H[H.pair_id.isin(pick.pair_id)]
                    if not len(S):
                        continue
                    jobs = make_jobs(v, S, tg, coef, [("calibrated", cal), ("recal_variant", new)], a.scratch, ncyc=5, cycle_len=10)
                    R = pd.DataFrame(list(ex.map(run_pair, jobs, chunksize=2))); R["arm"] = [j["arm"] for j in jobs]
                    R = R.merge(S[["pair_id", "cls"]], on="pair_id")
                    for q in R.itertuples():
                        if not q.ok or not isinstance(q.traj, str):
                            rows.append(dict(state=st, arm=q.arm, cls=q.cls, ok=False)); continue
                        tj = {int(k): val for k, val in json.loads(q.traj).items()}
                        sd = {int(k): val for k, val in json.loads(q.sdi).items()}
                        sm = {int(k): val for k, val in json.loads(q.sdim).items()}
                        sb = {int(k): val for k, val in json.loads(q.sdib).items()}
                        rr = dict(state=st, arm=q.arm, cls=q.cls, ok=True)
                        for y in range(0, 51, 10):
                            rr[f"agb_{y}"] = tj.get(y, np.nan) * LBAC_TO_MGHA
                            m = sm.get(y, sm.get(40, np.nan))
                            rr[f"sdi_{y}"] = sd.get(y, np.nan); rr[f"sdim_{y}"] = m
                            rr[f"rsdi_{y}"] = sd.get(y, np.nan) / m if m and m > 0 else np.nan
                        rr["max_rsdi"] = np.nanmax([rr[f"rsdi_{y}"] for y in range(0, 51, 10)])
                        rr["max_rsdi_em"] = np.nanmax([sb[y] / sm[y] for y in sb if y in sm and sm[y] > 0]) if sb else np.nan
                        ag = [rr[f"agb_{y}"] for y in range(0, 51, 10)]
                        rr["peak_agb"] = np.nanmax(ag); rr["drop_from_peak"] = 1 - ag[-1] / rr["peak_agb"] if rr["peak_agb"] > 0 else np.nan
                        rows.append(rr)
                    print(st, "sanity stands", len(S), f"t={time.time() - t0:.0f}s", flush=True)
                D = pd.DataFrame(rows)
                D.to_csv(W / f"sanity_stands_{v}.csv", index=False)   # stand rows, no ids, stays on Cardinal
                g = D[D.ok].groupby("arm")
                agg = g[[f"agb_{y}" for y in range(0, 51, 10)] + [f"rsdi_{y}" for y in range(0, 51, 10)] + ["max_rsdi", "max_rsdi_em", "drop_from_peak"]].mean()
                agg["stands"] = g.size(); agg["failed"] = D[~D.ok].groupby("arm").size().reindex(agg.index).fillna(0)
                agg["max_of_max_rsdi"] = g["max_rsdi"].max(); agg["share_rsdi_gt1"] = g["max_rsdi"].apply(lambda s: (s > 1).mean())
                agg["n_crash_gt50pct"] = g["drop_from_peak"].apply(lambda s: int((s > 0.5).sum()))
                agg["max_drop_from_peak"] = g["drop_from_peak"].max()
                agg["late_growth_pct_yr"] = 100 * ((agg["agb_50"] / agg["agb_40"]) ** 0.1 - 1)
                agg["early_growth_pct_yr"] = 100 * ((agg["agb_10"] / agg["agb_0"]) ** 0.1 - 1)
                agg.insert(0, "variant", v)
                p = S41 / "fvs_mortrecal_sanity_20261015.csv"
                agg.reset_index().to_csv(p, mode="a", header=not p.exists(), index=False)
                bycls = D[D.ok].groupby(["arm", "cls"])[[f"agb_{y}" for y in range(0, 51, 10)] + ["max_rsdi"]].mean().reset_index()
                bycls.insert(0, "variant", v)
                p2 = S41 / "fvs_mortrecal_sanity_bycls_20261015.csv"
                bycls.to_csv(p2, mode="a", header=not p2.exists(), index=False)
                print(agg.round(3).T.to_string(), flush=True)
    print(f"MODE_DONE {a.mode} t={time.time() - t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()
