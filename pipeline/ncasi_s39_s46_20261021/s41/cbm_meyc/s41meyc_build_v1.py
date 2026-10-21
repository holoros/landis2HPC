"""s41 cbm_meyc: build a NEW CURVE CONFIGURATION (MEYC) for the Maine CBM-CFS3
(libcbm) run. Growth input = Maine FIA AGB yield curves v1.0.0 (Zenodo
10.5281/zenodo.23406410), statewide (section ALL) MEAN curve per forest type
group, DRYBIO_AG basis (no foliage). Not a gate change; the registered
FVS_FIAW_NEW cell is read only (its adapted config is COPIED).

Route (a): libcbm's SIT/CBM3 path grows stands from merchantable volume curves
through the Boudewyn chain of the state AIDB, so each AGB curve is inverted to
merchantable volume per CBM forest type with the SAME factor row the cell uses
(species mapping unchanged), solving woody(V) = AGB_mean(age) where woody =
total stemwood + bark + branches (CBM Merch + Other, foliage excluded, matching
DRYBIO_AG). Then a libcbm round trip: probe stands at every integer age 1..200
per type are initialised by libcbm (spinup) and their year 0 Merch+Other is
compared with the input curve; node volumes are corrected multiplicatively
(at most 4 libcbm passes) until node error < 0.2 percent.

Classifier mapping. The cell's Ecoregion classifier is EPA Level III (58, 59,
82), not FIA ecological sections, so every ecoregion row takes the statewide
type curve. FT100 and FT160 -> WRPH; FT120 and FT380 -> SF; FT400 and FT500 ->
OAK; FT700 -> EAC; FT800 -> MBB; FT900 -> AB. FT999 (nonstocked) has no AGB
group and keeps its original curve.
usage: python s41meyc_build_v1.py OUTDIR"""
import os, sys, json, shutil, sqlite3, hashlib
import numpy as np, pandas as pd
from libcbm.input.sit import sit_cbm_factory
from libcbm.model.cbm import cbm_simulator

OUT = sys.argv[1]
SRC = "/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_ME/adapted_FVS_FIAW_NEW"
DB = "/users/PUOM0008/crsfaaron/cbm_states/states/ME/data/processed/cbm_defaults_ME.db"
CUR = "/users/PUOM0008/crsfaaron/maine_agb_yc_20261015/zenodo_upload/data/final_curves_capped_DATA.csv"
FTMAP = {"FT100": "WRPH", "FT120": "SF", "FT160": "WRPH", "FT380": "SF", "FT400": "OAK",
         "FT500": "OAK", "FT700": "EAC", "FT800": "MBB", "FT900": "AB"}
WOODY = ["SoftwoodMerch", "SoftwoodOther", "HardwoodMerch", "HardwoodOther"]
FOL = ["SoftwoodFoliage", "HardwoodFoliage"]
for p in (SRC + "/growth_and_yield.csv", DB, CUR):
    print("md5", p, hashlib.md5(open(p, "rb").read()).hexdigest())
os.makedirs(OUT, exist_ok=False)

def topd(x): return x.to_pandas() if hasattr(x, "to_pandas") else x

def factor_row(con, suid, sp_name):
    sid, gid, ftid = con.execute("select s.id, s.genus_id, s.forest_type_id from species s join species_tr t on t.species_id=s.id and t.locale_id=1 where t.name=?", (sp_name,)).fetchone()
    for q, k, lvl in (("select vol_to_bio_factor_id from vol_to_bio_species where spatial_unit_id=? and species_id=?", sid, "species"),
                      ("select vol_to_bio_factor_id from vol_to_bio_genus where spatial_unit_id=? and genus_id=?", gid, "genus"),
                      ("select vol_to_bio_factor_id from vol_to_bio_forest_type where spatial_unit_id=? and forest_type_id=?", ftid, "forest_type")):
        r = con.execute(q, (suid, k)).fetchone()
        if r:
            f = pd.read_sql(f"select * from vol_to_bio_factor where id={r[0]}", con).iloc[0].to_dict(); f["level"] = lvl
            return f
    raise KeyError(sp_name)

def boud(V, f):  # identical to s41_cbm_year0_decomp_v2 / s41_conv_test_v1
    V = np.atleast_1d(np.asarray(V, float)); pos = V > 0; Vp = np.where(pos, V, 1.0)
    bm = f["a"] * Vp ** f["b"]
    bnm = np.minimum(f["k_nonmerch"] + f["a_nonmerch"] * bm ** f["b_nonmerch"], f["cap_nonmerch"]) * bm
    bsnm = np.minimum(f["k_sap"] + f["a_sap"] * bnm ** f["b_sap"], f["cap_sap"]) * bnm
    L = np.log(Vp + 5)
    ea = np.exp(f["a1"] + f["a2"] * Vp + f["a3"] * L); eb = np.exp(f["b1"] + f["b2"] * Vp + f["b3"] * L); ec = np.exp(f["c1"] + f["c2"] * Vp + f["c3"] * L)
    psw = 1 / (1 + ea + eb + ec); pbk = ea * psw; pbr = eb * psw; pfl = ec * psw
    lo = Vp < f["min_volume"]; hi = Vp > f["max_volume"]
    for arr, lk, hk in ((psw, "low_stemwood_prop", "high_stemwood_prop"), (pbk, "low_stembark_prop", "high_stembark_prop"),
                        (pbr, "low_branches_prop", "high_branches_prop"), (pfl, "low_foliage_prop", "high_foliage_prop")):
        arr[lo] = f[lk]; arr[hi] = f[hk]
    tot = bsnm / psw
    return np.where(pos, bsnm + tot * pbk + tot * pbr, 0.0), np.where(pos, tot * pfl, 0.0)

def invert(T, f, vmax=5000.0):
    if T <= 0: return 0.0
    lo, hi = 0.0, vmax
    assert boud(hi, f)[0][0] > T, "target above chain range"
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if boud(mid, f)[0][0] < T: lo = mid
        else: hi = mid
    return 0.5 * (lo + hi)

# curves: statewide MEAN, annual
cv = pd.read_csv(CUR)
cv = cv[cv.section == "ALL"][["ftg", "age", "AGB_mean", "extrapolated", "capped", "age_q99", "cap"]].copy()
cv["age"] = cv.age.astype(int)
curve = {g: d.set_index("age").AGB_mean for g, d in cv.groupby("ftg")}

cfg = json.load(open(os.path.join(SRC, "sit_config.json")))["mapping_config"]
smap = {x["user_species"].replace(" ", ""): x["default_species"] for x in cfg["species"]["species_mapping"]}
con = sqlite3.connect(DB)
suid = con.execute("""select su.id from spatial_unit su join admin_boundary_tr a on a.admin_boundary_id=su.admin_boundary_id and a.locale_id=1
   join eco_boundary_tr e on e.eco_boundary_id=su.eco_boundary_id and e.locale_id=1 where a.name=? and e.name=?""",
   (cfg["spatial_units"]["admin_boundary"], cfg["spatial_units"]["eco_boundary"])).fetchone()[0]
fac = {k: factor_row(con, suid, smap[k]) for k in FTMAP}
con.close()

gy0 = pd.read_csv(os.path.join(SRC, "growth_and_yield.csv"))
vcols = [c for c in gy0.columns if c.startswith("v") and c[1:].isdigit()]
ac = pd.read_csv(os.path.join(SRC, "age_classes.csv")); sizes = ac.iloc[:, 1].astype(float).values
nodes = np.cumsum(sizes).astype(int)[:len(vcols)]  # 0,10,...,200
print("node ages", nodes.tolist())

# monotonicity of the chain and pure inversion
mono, Vn = [], {}
for ft, g in FTMAP.items():
    grid = np.linspace(0.5, 3000, 6000); w = boud(grid, fac[ft])[0]
    mono.append(dict(ft=ft, group=g, species=smap[ft], factor_level=fac[ft]["level"], factor_id=int(fac[ft]["id"]),
                     chain_monotone=bool(np.all(np.diff(w) >= -1e-9))))
    Vn[ft] = np.array([invert(float(curve[g].loc[a]), fac[ft]) for a in nodes])
M = pd.DataFrame(mono); print(M.to_string())

work = os.path.join(OUT, "probe")
def write_gy(path, Vd):
    gy = gy0.copy()
    for ft, v in Vd.items():
        gy.loc[gy.c1 == ft, vcols] = np.tile(v, ((gy.c1 == ft).sum(), 1))
    gy.to_csv(path, index=False)
    return gy

def libcbm_roundtrip(Vd):
    if os.path.exists(work): shutil.rmtree(work)
    shutil.copytree(SRC, work)
    write_gy(os.path.join(work, "growth_and_yield.csv"), Vd)
    ev = pd.read_csv(os.path.join(work, "disturbance_events.csv")); ev["disturbance_year"] = 9999
    ev.to_csv(os.path.join(work, "disturbance_events.csv"), index=False)
    inv = pd.read_csv(os.path.join(work, "inventory.csv"))
    rows = [dict(c1=ft, c2="ECO58", c3="OWN0", using_age_class=False, age=a, area=1.0, delay=0, landclass=0,
                 historic_disturbance="DISTNAT", last_pass_disturbance="DISTNAT") for ft in FTMAP for a in range(1, 201)]
    pd.DataFrame(rows)[inv.columns].to_csv(os.path.join(work, "inventory.csv"), index=False)
    sit = sit_cbm_factory.load_sit(os.path.join(work, "sit_config.json"), db_path=DB)
    classifiers, inventory = sit_cbm_factory.initialize_inventory(sit)
    cap = {}
    def rep(t, v):
        if t == 0:
            cap["p"] = topd(v.pools).copy(); cap["age"] = topd(v.state)["age"].values.copy(); cap["cls"] = topd(v.classifiers).copy()
    with sit_cbm_factory.initialize_cbm(sit) as cbm:
        cbm_simulator.simulate(cbm, n_steps=1, classifiers=classifiers, inventory=inventory, reporting_func=rep)
    inv_map = {n: {i: s for s, i in vals.items()} for n, vals in sit.classifier_value_ids.items()}
    d = pd.DataFrame({"ft": cap["cls"]["ForestType"].map(inv_map["ForestType"]).values, "age": cap["age"].astype(int),
                      "cbm_woody": cap["p"][WOODY].sum(axis=1).values / 0.5, "cbm_foliage": cap["p"][FOL].sum(axis=1).values / 0.5})
    d["group"] = d.ft.map(FTMAP)
    d["target"] = [float(curve[g].loc[a]) for g, a in zip(d.group, d.age)]
    d["ratio"] = d.cbm_woody / d.target
    return d

passes = []
for it in range(1, 5):
    d = libcbm_roundtrip(Vn); d["pass"] = it; passes.append(d)
    nd = d[d.age.isin(nodes[1:])]
    err = (nd.ratio - 1).abs().max()
    w = d[(d.age >= 20) & (d.age <= 150)]
    print(f"pass {it}: max node err {err:.5f}; ages 20-150 all integer: max |ratio-1| {(w.ratio-1).abs().max():.5f}", flush=True)
    if it == 1:
        # python chain on node volumes vs libcbm (checks the chain implementation)
        chk = []
        for ft in FTMAP:
            wpy = boud(Vn[ft][1:], fac[ft])[0]; wl = nd[nd.ft == ft].set_index("age").loc[nodes[1:], "cbm_woody"].values
            chk.append(np.max(np.abs(wl / wpy - 1)))
        print("libcbm vs python chain at nodes, max rel diff per ft:", dict(zip(FTMAP, np.round(chk, 5))), flush=True)
    if err < 0.002: break
    for ft in FTMAP:
        r = nd[nd.ft == ft].set_index("age").loc[nodes[1:], "ratio"].values
        Vn[ft][1:] = Vn[ft][1:] / np.where(r > 0, r, 1.0)

R = pd.concat(passes)
R.to_csv(os.path.join(OUT, "s41meyc_roundtrip_all_passes_20261016.csv"), index=False)
fin = passes[-1]; w = fin[(fin.age >= 20) & (fin.age <= 150)]
S = w.groupby(["ft", "group"]).agg(min_ratio=("ratio", "min"), max_ratio=("ratio", "max"),
     max_abs_err_pct=("ratio", lambda x: 100 * (x - 1).abs().max())).reset_index()
S["at_nodes_max_abs_err_pct"] = [100 * (fin[(fin.ft == ft) & fin.age.isin(nodes[(nodes >= 20) & (nodes <= 150)])].ratio - 1).abs().max() for ft in S.ft]
S["pass_2pct"] = S.max_abs_err_pct <= 2.0
S["libcbm_passes"] = int(fin["pass"].iloc[0])
S = S.merge(M, on=["ft", "group"])
S.to_csv(os.path.join(OUT, "s41meyc_roundtrip_summary_20261016.csv"), index=False)
print(S.round(4).to_string())

# final config
cdir = os.path.join(OUT, "adapted_ME_MEYC")
shutil.copytree(SRC, cdir)
gy = write_gy(os.path.join(cdir, "growth_and_yield.csv"), Vn)
gy.drop_duplicates("c1").to_csv(os.path.join(OUT, "s41meyc_gy_volume_new_20261016.csv"), index=False)
# old vs new curve comparison per type at nodes (old woody by python chain; new by libcbm round trip)
cmp = []
for ft, g in FTMAP.items():
    vold = gy0[gy0.c1 == ft][vcols].iloc[0].values.astype(float)
    wold = boud(vold, fac[ft])[0]
    for i, a in enumerate(nodes):
        cmp.append(dict(ft=ft, group=g, age=int(a), vol_old_m3ha=vold[i], vol_new_m3ha=Vn[ft][i], woody_old_Mgha=wold[i],
                        agb_mean_new_Mgha=float(curve[g].loc[a]), extrapolated_new=bool(cv[(cv.ftg == g) & (cv.age == a)].extrapolated.iloc[0])))
pd.DataFrame(cmp).to_csv(os.path.join(OUT, "s41meyc_curves_old_vs_new_20261016.csv"), index=False)
shutil.rmtree(work)
print("md5 new gy", hashlib.md5(open(os.path.join(cdir, "growth_and_yield.csv"), "rb").read()).hexdigest())
print("done build")
