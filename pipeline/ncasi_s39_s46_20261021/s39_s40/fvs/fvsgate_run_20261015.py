#!/usr/bin/env python3
"""NCASI Phase 1 FVS realism gate, step 2 of 3: one cycle FVS projection of FIA remeasured pairs. 15 Oct 2026.

Reads work/pairs_<ST>.csv, work/trees_<ST>.csv and work/emul_coef_20261015.csv written by fvsgate_pairs_20261015.R.
For every gate pair: the t1 live tree list (DIA >= 1 in, NSVB DRYBIO_AG present) goes into FVS through the project's
own keyfile builder (calibration/python/inventory_keyfile.py, make_inventory_keyfile, SPCTRN aware with other slot
fallback, the same call the 7 Sep frame resolved runners make), with NUMCYCLE 1, TIMEINT = round(REMPER) (minimum 1),
NOTRIPLE, no harvest, no regeneration keywords, and a database tree list at the start and end of the cycle. Two arms:
default and calibrated (FvsConfigLoader(variant, "calibrated").generate_keywords(), as in the 7 Sep runners).

Biomass. Each FVS record keeps its tree's own FIA NSVB DRYBIO_AG at t1 (b1). The end of cycle biomass is
b1 * f(D2, H2) / f(D1, H1), f = exp(a + b ln D + c ln H) fitted to NSVB DRYBIO_AG by species (n >= 50) or by softwood /
hardwood within the state; D and H are FVS's own start and end values. The R step validates this ratio on observed
survivors against the NSVB DRYBIO_AG FIA reports at t2.
FVS components per pair (lb ac-1 over the cycle, divided by the cycle length, x 0.00112085 to Mg ha-1 yr-1):
  survivor growth  sum TPA_end * (b2 - b1)
  mortality        sum (TPA_start - TPA_end) * b1     (FIA definition: t1 biomass of trees that die)
  gross growth     survivor growth (FVS NE and LS add no ingrowth without regeneration keywords)
  net growth       gross growth - mortality
Pairs with no qualifying t1 tree get FVS components of zero. Tree records whose SPCD the builder cannot resolve are
held static (b2 = b1, no mortality) and counted.
"""
import argparse, json, os, shutil, sqlite3, subprocess, sys, tempfile, hashlib
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import numpy as np
import pandas as pd

LBAC_TO_MGHA = 0.00112085
W = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs/work")
CFG = {
    "ne": dict(states=["ME", "NH", "VT"], tree=Path("/fs/scratch/PUOM0008/crsfaaron/v1tag_20260811"),
               bin="/users/PUOM0008/crsfaaron/fvs-modern/bin-v1_20260906/FVSne"),
    "ls": dict(states=["MI", "WI", "MN"], tree=Path("/users/PUOM0008/crsfaaron/ncasi_fvsls/fm_frame"),
               bin="/users/PUOM0008/crsfaaron/fvs-modern/bin-v1_20260906/FVSls"),
}
IKDIR = "/users/PUOM0008/crsfaaron/fvs-modern/calibration/python"
IK_MD5 = "4804454a8aff48e948f659965fd597ee"


def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()


def run_pair(job):
    sys.path.insert(0, IKDIR)
    import inventory_keyfile as ik
    v = job["variant"]
    trees = pd.DataFrame(job["trees"])
    out = {"pair_id": job["pair_id"], "ok": False, "n_static": 0, "n_trees": len(trees)}
    if len(trees) == 0:
        out.update(ok=True, fvs_surv=0.0, fvs_mort=0.0, fvs_B1=0.0, note="no_t1_trees")
        return out
    res = [ik.resolve_fvs_code(int(s), v, use_spctrn=True, other_fallback=True)[0] for s in trees["SPCD"]]
    trees["alpha"] = res
    static = trees[trees["alpha"].isna()]
    fv = trees[trees["alpha"].notna()].copy()
    out["n_static"] = len(static)
    # site species first, so SITECODE (first record's species) names the FIA site species when it is on the plot
    fv["first"] = (fv["SPCD"] == job["sisp"]).astype(int)
    fv = fv.sort_values("first", ascending=False, kind="stable").reset_index(drop=True)
    fv["tree_num"] = np.arange(1, len(fv) + 1)
    cr_missing = set(fv.loc[fv["CR"].isna() | (fv["CR"] <= 0), "tree_num"])
    tdf = pd.DataFrame({"tree_count": fv["TPA_UNADJ"], "species": fv["SPCD"].astype(int), "diameter": fv["DIA"].clip(upper=99.9),
                        "ht": fv["HT"].fillna(0).clip(lower=0), "crratio": fv["CR"].fillna(50).where(fv["CR"] > 0, 50)})
    sdf = pd.DataFrame([job["stand"]])
    n = job["cycle"]
    extra = ("NOTRIPLE\n" f"TIMEINT   {0:>10d}{n:>10d}\n" "TREELIST           0\n"
             "DATABASE\nDSNOUT\nfvsout.db\nTREELIDB           2\nEND")
    if job["cal_kw"]:
        extra += "\n" + job["cal_kw"]
    key = ik.make_inventory_keyfile(stand_df=sdf, tree_df=tdf, stand_id="P" + job["pair_id"][-12:], variant=v,
                                    inv_year=int(job["inv_year"]), num_cycles=1, calibration_keywords=extra,
                                    use_spctrn=True, spctrn_other_fallback=True)
    lines = key.split("\n")
    i0 = next(i for i, l in enumerate(lines) if l.startswith("TREEDATA")) + 1
    for k in range(len(fv)):
        if (k + 1) in cr_missing:
            l = lines[i0 + k]
            lines[i0 + k] = l[:34] + " " + l[35:]
    key = "\n".join(lines)
    work = tempfile.mkdtemp(prefix="fg_", dir=job["scratch"])
    try:
        Path(work, "s.key").write_text(key)
        env = dict(os.environ); env.pop("FVS_GREGDG", None); env.pop("FVS_GREGHG", None)
        r = subprocess.run([job["bin"], "--keywordfile=s.key"], cwd=work, env=env, capture_output=True, timeout=120)
        db = Path(work, "fvsout.db")
        if not db.exists():
            out["note"] = f"no db rc={r.returncode}"; return out
        con = sqlite3.connect(str(db))
        tl = pd.read_sql("select Year, TreeId, TPA, DBH, Ht from FVS_TreeList", con); con.close()
        y0, y1 = int(job["inv_year"]), int(job["inv_year"]) + n
        if set(tl["Year"]) != {y0, y1}:
            out["note"] = f"years {sorted(set(tl['Year']))}"; return out
        tl["tree_num"] = tl["TreeId"].astype(str).str[1:].astype(int)
        a = tl[tl["Year"] == y0].set_index("tree_num"); b = tl[tl["Year"] == y1].set_index("tree_num")
        if len(a) != len(fv) or len(b) != len(fv):
            out["note"] = f"records {len(a)} {len(b)} vs {len(fv)}"; return out
        fv = fv.set_index("tree_num")
        co = job["coef"]
        keyc = [s if s in co else (-1 if s < 300 else -2) for s in fv["SPCD"].astype(int)]
        bb = np.array([co[k][0] for k in keyc]); cc = np.array([co[k][1] for k in keyc])
        D1, H1 = a.loc[fv.index, "DBH"].values, a.loc[fv.index, "Ht"].values
        D2, H2 = b.loc[fv.index, "DBH"].values, b.loc[fv.index, "Ht"].values
        T1, T2 = a.loc[fv.index, "TPA"].values, b.loc[fv.index, "TPA"].values
        b1 = fv["DRYBIO_AG"].values
        b2 = b1 * np.exp(bb * (np.log(D2) - np.log(D1)) + cc * (np.log(H2) - np.log(H1)))
        out.update(ok=True, fvs_surv=float(np.sum(T2 * (b2 - b1))), fvs_mort=float(np.sum((T1 - T2) * b1)),
                   fvs_B1=float(np.sum(T1 * b1) + np.sum(static["TPA_UNADJ"] * static["DRYBIO_AG"])),
                   fvs_B2=float(np.sum(T2 * b2) + np.sum(static["TPA_UNADJ"] * static["DRYBIO_AG"])),
                   tpa_start=float(T1.sum()), tpa_end=float(T2.sum()), note="")
        return out
    except Exception as e:  # recorded, never silent
        out["note"] = f"error {type(e).__name__}: {e}"[:200]; return out
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", required=True, choices=["ne", "ls"])
    ap.add_argument("--workers", type=int, default=46)
    ap.add_argument("--limit", type=int, default=0, help="pairs per state for a smoke test; 0 = all")
    ap.add_argument("--scratch", default=os.environ.get("TMPDIR", "/tmp"))
    a = ap.parse_args()
    c = CFG[a.variant]
    assert md5(Path(IKDIR, "inventory_keyfile.py")) == IK_MD5, "inventory_keyfile.py md5 changed"
    sys.path.insert(0, str(c["tree"]))
    from config.config_loader import FvsConfigLoader
    cal = FvsConfigLoader(a.variant, version="calibrated", config_dir=str(c["tree"] / "config")).generate_keywords(include_comments=False)
    jf = c["tree"] / "config" / "calibrated" / f"{a.variant}.json"
    print(f"variant {a.variant}; binary {c['bin']} md5 {md5(c['bin'])}; {jf} {jf.stat().st_size} bytes md5 {md5(jf)}; "
          f"calibration date {json.loads(jf.read_text()).get('calibration', {}).get('date')}; keyword block md5 "
          f"{hashlib.md5(cal.encode()).hexdigest()} lines {len(cal.splitlines())}; inventory_keyfile md5 {IK_MD5}", flush=True)
    co = pd.read_csv(W / "emul_coef_20261015.csv")
    for st in c["states"]:
        P = pd.read_csv(W / f"pairs_{st}.csv", dtype={"pair_id": str, "t1_id": str})
        T = pd.read_csv(W / f"trees_{st}.csv", dtype={"pair_id": str, "tree_cn": str})
        if a.limit:
            P = P.sample(n=min(a.limit, len(P)), random_state=20261015)
        coef = {int(r.SPCD): (r.b, r.c) for r in co[co.state == st].itertuples()}
        si_med = float(P.loc[P.SICOND_FVS > 0, "SICOND_FVS"].median()); age_med = float(P.loc[P.STDAGE > 0, "STDAGE"].median())
        tg = dict(tuple(T.groupby("pair_id")))
        jobs = []
        for arm, kw in (("default", ""), ("calibrated", cal)):
            for r in P.itertuples():
                si = r.SICOND_FVS if (pd.notna(r.SICOND_FVS) and r.SICOND_FVS > 0) else si_med
                age = r.STDAGE if (pd.notna(r.STDAGE) and r.STDAGE > 0) else age_med
                stand = dict(site_index=float(si), age=float(age), aspect=float(r.ASPECT if pd.notna(r.ASPECT) else 0),
                             slope=float(r.SLOPE if pd.notna(r.SLOPE) else 5), elevft=float(r.ELEV if pd.notna(r.ELEV) else 1000),
                             forest_type=int(r.FORTYPCD) if pd.notna(r.FORTYPCD) else None)
                if stand["forest_type"] is None:
                    stand.pop("forest_type")
                tr = tg.get(r.pair_id)
                jobs.append(dict(variant=a.variant, pair_id=r.pair_id, arm=arm, cal_kw=kw, bin=c["bin"], scratch=a.scratch,
                                 inv_year=int(r.INVYR1), cycle=max(1, int(round(r.REMPER))), stand=stand,
                                 sisp=int(r.SISP_FVS) if pd.notna(r.SISP_FVS) else -9, coef=coef,
                                 trees=(tr[["SPCD", "DIA", "HT", "CR", "TPA_UNADJ", "DRYBIO_AG"]].to_dict("records") if tr is not None else [])))
        with ProcessPoolExecutor(a.workers) as ex:
            res = list(ex.map(run_pair, jobs, chunksize=8))
        R = pd.DataFrame(res); R["arm"] = [j["arm"] for j in jobs]; R["cycle"] = [j["cycle"] for j in jobs]
        R["state"] = st
        R.to_csv(W / f"fvs_pairs_{st}{'_smoke' if a.limit else ''}.csv", index=False)
        print(st, "pairs", len(P), "runs", len(R), "ok", int(R.ok.sum()), "static trees", int(R.n_static.sum()),
              "notes", R.loc[~R.ok, "note"].value_counts().head(5).to_dict(), flush=True)
    print("RUN_DONE", flush=True)


if __name__ == "__main__":
    main()
