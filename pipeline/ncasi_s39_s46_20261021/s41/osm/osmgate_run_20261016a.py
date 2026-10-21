#!/usr/bin/env python3
"""NCASI Phase 1 OSM realism gate, Maine, step 1 of 2: one cycle OSM (Acadian variant) projection of the FVS gate pairs.
Session 41, 16 Oct 2026 (gate plan of 15 Oct 2026, thresholds frozen).

Inputs (read only, all on Cardinal):
  FVS gate pairs   /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs/work/pairs_ME.csv, trees_ME.csv (7,510 pairs)
  emulator         .../fvs/work/emul_coef_20261015.csv (ln DRYBIO_AG = a + b ln DIA + c ln HT, by SPCD or softwood/hardwood)
  species          ~/OSM/work/acadian_species_crosswalk.csv (FIA SPCD to OSM two letter code)
  BGI              ~/OSM/work/acd_full/acd_plt_cn_lookup_with_bgi_csi.csv, columns PLT_CN and BGI only (ME_BGI_V1.tif)
  OSM              ~/OSM/v2.26.1/OSMv2.26.1_Linux64/OSM.ConsoleApp, variant Acadian (banner 2.26.0)

Projection. One OSM stand per pair (SurveyID 1..N), Plots 1, Zone ME, Management None, PoorSite 0, BGI from the lookup
(keyed on the t1 PLT_CN, then the t2 PLT_CN; 0 is the raster nodata sentinel); pairs with no BGI get the median BGI of
the gate pairs that have one and are flagged bgi_src = median. Tree list = the FVS gate t1 trees: DBH cm = DIA x 2.54,
HT m = HT x 0.3048 (NULL when FIA HT is missing), Stems ha-1 = TPA_UNADJ x 2.47105, species by the crosswalk (fallback OS
for SPCD < 300, else OH, counted). Cycle n = max(1, round(REMPER)), the same expression the FVS gate used. OSM writes a
tree list at the START of each cycle only, so mode "cycle" runs YPC n, YEARS 2n and reads Cycle 0 and Cycle 1 (one n year
cycle); mode "annual" (sensitivity) runs YPC 1, YEARS n+1 and reads Cycle 0 and Cycle n. No treatment commands.

Components per pair (lb ac-1 over the cycle; the scorer divides by n and multiplies by 0.00112085):
  input tree k of a stand is OSM TreeID -k (checked: Cycle 0 DBH must equal the input DBH)
  survivor growth  sum Stems_end/2.47105 * (b2 - b1), b2 = b1 * exp(b (ln D_end - ln D_0) + c (ln H_end - ln H_0)),
                   b1 = the tree's own FIA NSVB DRYBIO_AG, D and H are OSM's own values (the FVS gate emulator route)
  mortality        sum (Stems_0 - Stems_end)/2.47105 * b1   (FIA definition: t1 biomass of trees that die)
  ingrowth         records present at the end but not at Cycle 0 (OSM recruits), DBH >= 2.54 cm (FIA 1.0 in threshold),
                   biomass exp(a + b ln DIA + c ln HT) from the same emulator fit, absolute, species by reverse crosswalk
  gross growth     survivor growth + ingrowth (FIA gross includes ingrowth); net = gross - mortality
Pairs with no t1 tree get zeros. Stands whose output fails a check are rerun alone once, then recorded as failed.
Writes /fs/scratch/.../s41/osm/work/osm_pairs_ME[_smoke][_annual].csv (PLT_CN keyed; stays on Cardinal).
"""
import argparse, csv, hashlib, math, os, shutil, sqlite3, subprocess, sys, tempfile
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import numpy as np
import pandas as pd

FW = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs/work")
OW = Path("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm/work")
HOME = Path("/users/PUOM0008/crsfaaron")
OSM = HOME / "OSM/v2.26.1/OSMv2.26.1_Linux64/OSM.ConsoleApp"
XW = HOME / "OSM/work/acadian_species_crosswalk.csv"
BGI = HOME / "OSM/work/acd_full/acd_plt_cn_lookup_with_bgi_csi.csv"
HA = 2.47105


def md5(p):
    return hashlib.md5(open(p, "rb").read()).hexdigest()


def load_xwalk():
    x = pd.read_csv(XW, dtype=str)
    cols = list(x.columns)
    spc = next((c for c in cols if c.upper() in ("SPCD", "FIA", "FIA_SPCD", "SPCD_FIA")), None)
    osm = next((c for c in cols if "OSM" in c.upper() and "CODE" in c.upper()), None) or \
        next((c for c in cols if c.upper() in ("OSM", "OSM_SP", "OSM_SPECIES", "SPECIES_OSM", "OSM_CODE", "SP")), None)
    if spc is None or osm is None:
        sys.exit(f"crosswalk columns not recognised: {cols}")
    x = x[[spc, osm]].dropna()
    x = x[x[spc].str.replace(".0", "", regex=False).str.isdigit()]
    fw = {int(float(s)): str(o).strip().upper() for s, o in zip(x[spc], x[osm]) if str(o).strip()}
    rev = {}
    for s, o in sorted(fw.items()):
        rev.setdefault(o, s)
    print(f"crosswalk {XW} md5 {md5(XW)} columns {cols}; using {spc} -> {osm}; {len(fw)} SPCD", flush=True)
    return fw, rev


def osmc_text(db, ss, tl, n, mode, sids):
    ypc, years = (n, 2 * n) if mode == "cycle" else (1, n + 1)
    return "\n".join(["SIMULATION", f" YEARS {years}", f" YPC {ypc}", "", f'INPUTS.SOURCE "{db}"', "", "OUTPUTS",
                      " Messages FALSE", " StandSummary.ConsoleOn FALSE", f' StandSummary.FilePath "{ss}"',
                      f' TreeList.FilePath "{tl}"', "", "SIMULATION.Scenario BASE"] + [f"SIMULATE {s}" for s in sids]) + "\n"


def run_chunk(job):
    """job: dict(n, mode, stands=[dict(sid, pair_id, bgi, trees=[(sp, dbh_cm, ht_m|None, stems, b1, spcd)])], coef, rev, scratch)"""
    n, mode = job["n"], job["mode"]
    endc = 1 if mode == "cycle" else n
    work = tempfile.mkdtemp(prefix="og_", dir=job["scratch"])
    out = []
    try:
        db = Path(work, "in.sqlite"); con = sqlite3.connect(str(db)); cur = con.cursor()
        cur.execute("CREATE TABLE OSM_StandList (SurveyID INT, Plots INT, Zone TEXT, Management TEXT, BGI INT, PoorSite SMALLINT)")
        cur.execute("CREATE TABLE OSM_TreeList (SurveyID INT, Species TEXT, DBH REAL, HT REAL, Stems REAL)")
        for s in job["stands"]:
            cur.execute("INSERT INTO OSM_StandList VALUES (?,?,?,?,?,?)", (s["sid"], 1, "ME", "None", int(s["bgi"]), 0))
            for t in s["trees"]:
                cur.execute("INSERT INTO OSM_TreeList VALUES (?,?,?,?,?)", (s["sid"], t[0], t[1], t[2], t[3]))
        cur.execute("CREATE INDEX ix ON OSM_TreeList(SurveyID)"); con.commit(); con.close()
        ss, tl, oc = Path(work, "ss.csv"), Path(work, "tl.csv"), Path(work, "run.osmc")
        oc.write_text(osmc_text(db, ss, tl, n, mode, [s["sid"] for s in job["stands"]]))
        r = subprocess.run([str(OSM), "Acadian", str(oc)], cwd=work, capture_output=True, text=True, timeout=3600)
        rc = r.returncode
        rows, bad = {}, 0
        if tl.exists():
            with open(tl, newline="") as fh:
                rd = csv.reader(fh); hdr = next(rd); H = {h: i for i, h in enumerate(hdr)}; L = len(hdr)
                for row in rd:
                    if len(row) != L:
                        bad += 1; continue
                    try:
                        sid = int(row[H["SurveyID"]]); cyc = int(row[H["Cycle"]])
                        if cyc not in (0, endc):
                            continue
                        rows.setdefault(sid, []).append((cyc, int(float(row[H["TreeID"]])), row[H["Species"]],
                                                         float(row[H["DBH"]]), float(row[H["HT"]]), float(row[H["Stems"]]),
                                                         float(row[H["ToDie"]])))
                    except (ValueError, KeyError):
                        bad += 1
        co, rev = job["coef"], job["rev"]
        for s in job["stands"]:
            o = dict(sid=s["sid"], pair_id=s["pair_id"], ok=False, rc=rc, bad_lines=bad, note="")
            R = rows.get(s["sid"])
            if not R:
                o["note"] = f"no tree rows rc={rc}"; out.append(o); continue
            T = s["trees"]; k = len(T)
            c0 = {tid: v for (cy, tid, *v) in R if cy == 0}
            c1 = {tid: v for (cy, tid, *v) in R if cy == endc}
            inp0 = {tid: v for tid, v in c0.items() if tid < 0}
            if len(inp0) != k or set(inp0) != set(range(-k, 0)):
                o["note"] = f"cycle0 input records {len(inp0)} vs {k}"; out.append(o); continue
            if not c1:
                o["note"] = "no end cycle rows"; out.append(o); continue
            dmis = max(abs(inp0[-(i + 1)][1] - T[i][1]) for i in range(k))
            if dmis > 0.01:
                o["note"] = f"cycle0 DBH mismatch {dmis:.3f}"; out.append(o); continue
            surv = mort = todie = B1 = B2 = 0.0; srel = 0.0
            for i, t in enumerate(T):
                tid = -(i + 1); sp, D0, H0, S0, TD = inp0[tid]
                b1, spcd = t[4], t[5]
                kk = spcd if spcd in co else (-1 if spcd < 300 else -2); bb, cc = co[kk][1], co[kk][2]
                srel = max(srel, abs(S0 - t[3]) / t[3])
                B1 += S0 / HA * b1; todie += TD / HA * b1
                if tid in c1:
                    _, D1, H1, S1, _ = c1[tid]
                    b2 = b1 * math.exp(bb * (math.log(D1) - math.log(D0)) + cc * (math.log(max(H1, 0.1)) - math.log(max(H0, 0.1))))
                    surv += S1 / HA * (b2 - b1); mort += (S0 - S1) / HA * b1; B2 += S1 / HA * b2
                else:
                    mort += S0 / HA * b1
            ingr = 0.0; n_ing = n_small = 0; st_ing = 0.0
            for tid, (sp, D1, H1, S1, _) in c1.items():
                if tid in c0:
                    continue
                if D1 < 2.54:
                    n_small += 1; continue
                spcd = rev.get(sp.upper(), 100 if sp.upper() in SOFT else 300)
                kk = spcd if spcd in co else (-1 if spcd < 300 else -2); a, bb, cc = co[kk]
                bi = math.exp(a + bb * math.log(D1 / 2.54) + cc * math.log(max(H1, 0.1) / 0.3048))
                ingr += S1 / HA * bi; n_ing += 1; st_ing += S1; B2 += S1 / HA * bi
            o.update(ok=True, n_trees=k, osm_surv=surv, osm_ingr=ingr, osm_mort=mort, osm_mort_todie=todie, osm_B1=B1,
                     osm_B2=B2, n_ingr_rec=n_ing, n_ingr_below_1in=n_small, ingr_stems_ha=st_ing, stems0_relerr=srel,
                     ingr_new_ids=len([t for t in c1 if t not in c0]), n_end_input=len([t for t in c1 if t < 0]))
            out.append(o)
    except Exception as e:  # recorded, never silent
        for s in job["stands"]:
            out.append(dict(sid=s["sid"], pair_id=s["pair_id"], ok=False, note=f"error {type(e).__name__}: {e}"[:200]))
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return out


SOFT = {"BF", "BS", "EH", "JP", "NS", "RS", "WC", "WP", "WS", "TL", "PR", "OS", "SP", "RP", "SC", "AF", "BP", "SW", "HE"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--mode", default="cycle", choices=["cycle", "annual"])
    ap.add_argument("--workers", type=int, default=40)
    ap.add_argument("--chunk", type=int, default=150)
    ap.add_argument("--scratch", default=os.environ.get("TMPDIR", "/tmp"))
    a = ap.parse_args()
    OW.mkdir(parents=True, exist_ok=True)
    print(f"OSM {OSM} md5 {md5(OSM)}; mode {a.mode}; limit {a.limit}", flush=True)
    fw, rev = load_xwalk()
    co_all = pd.read_csv(FW / "emul_coef_20261015.csv")
    co = {int(r.SPCD): (r.a, r.b, r.c) for r in co_all[co_all.state == "ME"].itertuples()}
    P = pd.read_csv(FW / "pairs_ME.csv", dtype={"pair_id": str, "t1_id": str})
    T = pd.read_csv(FW / "trees_ME.csv", dtype={"pair_id": str, "tree_cn": str})
    print(f"pairs {len(P)} trees {len(T)}; pairs md5 {md5(FW / 'pairs_ME.csv')} trees md5 {md5(FW / 'trees_ME.csv')}", flush=True)
    # BGI, PLT_CN keyed; only the two needed columns are read
    L = pd.read_csv(BGI, usecols=["PLT_CN", "BGI"], dtype={"PLT_CN": str})
    L["PLT_CN"] = L["PLT_CN"].str.replace(r"\.0+$", "", regex=True)
    L = L[pd.to_numeric(L.BGI, errors="coerce").fillna(0) > 0].drop_duplicates("PLT_CN")
    bmap = dict(zip(L.PLT_CN, pd.to_numeric(L.BGI).astype(int)))
    P["bgi_t1"] = P.t1_id.map(bmap); P["bgi_t2"] = P.pair_id.map(bmap)
    P["bgi"] = P.bgi_t1.fillna(P.bgi_t2)
    P["bgi_src"] = np.where(P.bgi_t1.notna(), "t1", np.where(P.bgi_t2.notna(), "t2", "median"))
    med = float(P.bgi.median())
    print(f"BGI lookup {BGI} md5 {md5(BGI)}: {len(bmap)} plots with BGI > 0; gate pairs matched on t1 {int(P.bgi_t1.notna().sum())}, "
          f"on t2 only {int((P.bgi_t1.isna() & P.bgi_t2.notna()).sum())}, none {int(P.bgi.isna().sum())}; "
          f"gate pair BGI median {med:.0f} mean {P.bgi.mean():.1f} p25 {P.bgi.quantile(.25):.0f} p75 {P.bgi.quantile(.75):.0f}", flush=True)
    P["bgi"] = P.bgi.fillna(round(med)).round().astype(int)
    if a.limit:
        P = P.sample(n=min(a.limit, len(P)), random_state=20261015)
    P = P.reset_index(drop=True); P["sid"] = np.arange(1, len(P) + 1)
    P["cycle"] = [max(1, int(round(r))) for r in P.REMPER]
    tg = dict(tuple(T.groupby("pair_id")))
    n_fb = n_htna = 0; stands = {}
    for r in P.itertuples():
        tr = tg.get(r.pair_id)
        if tr is None or len(tr) == 0:
            continue
        lst = []
        for t in tr.itertuples():
            sp = fw.get(int(t.SPCD))
            if sp is None:
                sp = "OS" if t.SPCD < 300 else "OH"; n_fb += 1
            ht = float(t.HT) * 0.3048 if pd.notna(t.HT) and t.HT > 0 else None
            n_htna += ht is None
            lst.append((sp, float(t.DIA) * 2.54, ht, float(t.TPA_UNADJ) * HA, float(t.DRYBIO_AG), int(t.SPCD)))
        stands[r.sid] = dict(sid=int(r.sid), pair_id=r.pair_id, bgi=int(r.bgi), trees=lst, n=r.cycle)
    print(f"stands with trees {len(stands)} of {len(P)}; crosswalk fallback trees {n_fb}; trees with no FIA HT {n_htna}; "
          f"cycle lengths {P.cycle.value_counts().sort_index().to_dict()}", flush=True)
    jobs = []
    for n in sorted(set(s["n"] for s in stands.values())):
        ss = [s for s in stands.values() if s["n"] == n]
        for i in range(0, len(ss), a.chunk):
            jobs.append(dict(n=n, mode=a.mode, stands=ss[i:i + a.chunk], coef=co, rev=rev, scratch=a.scratch))
    with ProcessPoolExecutor(a.workers) as ex:
        res = [o for chunk in ex.map(run_chunk, jobs) for o in chunk]
    bad = [o["sid"] for o in res if not o["ok"]]
    print(f"first pass: {len(res)} stands, failed {len(bad)}; notes {pd.Series([o['note'] for o in res if not o['ok']]).value_counts().head(5).to_dict()}", flush=True)
    if bad:
        rj = [dict(n=stands[s]["n"], mode=a.mode, stands=[stands[s]], coef=co, rev=rev, scratch=a.scratch) for s in bad]
        with ProcessPoolExecutor(a.workers) as ex:
            rr = {o["sid"]: o for chunk in ex.map(run_chunk, rj) for o in chunk}
        res = [rr.get(o["sid"], o) if not o["ok"] else o for o in res]
        print(f"after single stand rerun: failed {sum(not o['ok'] for o in res)}", flush=True)
    R = pd.DataFrame(res)
    R = P[["pair_id", "sid", "cycle", "REMPER", "bgi", "bgi_src"]].merge(R.drop(columns=["pair_id"]), on="sid", how="left")
    none = R.ok.isna()
    R.loc[none, ["ok", "note", "osm_surv", "osm_ingr", "osm_mort", "osm_mort_todie", "osm_B1", "osm_B2"]] = [True, "no_t1_trees", 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    R["ok"] = R.ok.astype(bool); R["mode"] = a.mode
    f = OW / f"osm_pairs_ME{'_smoke' if a.limit else ''}{'_annual' if a.mode == 'annual' else ''}.csv"
    R.to_csv(f, index=False)
    K = 0.00112085
    x = R[R.ok]
    print(f"wrote {f}: pairs {len(R)} ok {int(R.ok.sum())} no_t1_trees {int(none.sum())} bgi_src {R.bgi_src.value_counts().to_dict()}", flush=True)
    print("means Mg ha-1 yr-1: surv {:.4f} ingr {:.4f} mort {:.4f} mort_todie {:.4f}; ingrowth records {} below 1 in {}; max stems0 rel err {:.2e}".format(
        (x.osm_surv / x.cycle * K).mean(), (x.osm_ingr / x.cycle * K).mean(), (x.osm_mort / x.cycle * K).mean(),
        (x.osm_mort_todie / x.cycle * K).mean(), int(x.n_ingr_rec.fillna(0).sum()), int(x.n_ingr_below_1in.fillna(0).sum()),
        x.stems0_relerr.max()), flush=True)
    print("RUN_DONE", flush=True)


if __name__ == "__main__":
    main()
