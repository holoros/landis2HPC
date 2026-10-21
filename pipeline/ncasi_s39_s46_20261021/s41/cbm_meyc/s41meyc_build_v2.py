"""s41 cbm_meyc build v2 (supersedes v1). NEW CURVE CONFIGURATION (MEYC2), not a
gate change; the registered FVS_FIAW_NEW config is read only and COPIED.

Why v2. v1 inverted the AGB curves to merchantable volume only at the cell's
10 yr age class nodes. libcbm interpolates volume linearly between nodes and the
Boudewyn chain is nonlinear (and for several factor rows non monotone across
the min/max volume proportion switch), so integer ages between nodes missed the
target by up to 21 percent (WRPH, OAK ages 61 to 67) and the 2 percent round trip
check failed for 6 of 9 types. v2 gives the configuration ANNUAL age classes
(AGEID0 size 0, then 200 classes of size 1, v0..v200 at ages 0..200), so every
integer age is a node, and iterates libcbm round trips at every age.

The inventory used 10 yr age classes (using_age_class=True). It is expanded to
explicit integer ages exactly as libcbm expand_age_class_inventory does (AGEIDk,
k>=1, -> ages 10k-9..10k, area/10 each; AGEID0 -> age 0), so stand ages and
areas are identical to what libcbm builds from the original config.

Two configs are written:
  adapted_ME_CTRL_annual: OLD FVS volume curves linearly interpolated to annual
    nodes + expanded inventory. A control: its 10 yr run must reproduce the
    registered baseline, isolating the age class reconfiguration.
  adapted_ME_MEYC2: Maine FIA AGB yield curves v1.0.0 (Zenodo
    10.5281/zenodo.23406410), statewide (section ALL) MEAN per type group,
    DRYBIO_AG basis, matched to CBM Merch+Other (foliage excluded).
Classifier mapping as v1 (Ecoregion classifier is EPA L3, not FIA sections, so
statewide curves): FT100, FT160 -> WRPH; FT120, FT380 -> SF; FT400, FT500 -> OAK;
FT700 -> EAC; FT800 -> MBB; FT900 -> AB; FT999 keeps its (interpolated) old curve.
usage: python s41meyc_build_v2.py OUTDIR"""
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
AMAX = 200
for p in (SRC + "/growth_and_yield.csv", SRC + "/inventory.csv", SRC + "/age_classes.csv", DB, CUR):
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

# ---- old config pieces
gy0 = pd.read_csv(os.path.join(SRC, "growth_and_yield.csv"))
vcols0 = [c for c in gy0.columns if c.startswith("v") and c[1:].isdigit()]
ac0 = pd.read_csv(os.path.join(SRC, "age_classes.csv")); sizes = ac0.iloc[:, 1].astype(int).values
nodes0 = np.cumsum(sizes)[:len(vcols0)]
assert nodes0[0] == 0 and nodes0[-1] == AMAX and np.all(sizes[1:] == 10), nodes0
ages = np.arange(AMAX + 1)
keyc = [c for c in gy0.columns if c not in vcols0]
vcols = [f"v{i}" for i in ages]
gyA = gy0[keyc].copy()
VA = np.vstack([np.interp(ages, nodes0, r) for r in gy0[vcols0].values.astype(float)])
gyA = pd.concat([gyA, pd.DataFrame(VA, columns=vcols, index=gyA.index)], axis=1)
acA = pd.DataFrame({ac0.columns[0]: ["AGEID0"] + [f"AGE{i}" for i in range(1, AMAX + 1)], ac0.columns[1]: [0] + [1] * AMAX})

inv0 = pd.read_csv(os.path.join(SRC, "inventory.csv"))
assert inv0.using_age_class.astype(str).str.lower().eq("true").all()
st = {f"AGEID{k}": (0 if k == 0 else 10 * k - 9) for k in range(len(sizes))}
rows = []
for r in inv0.itertuples(index=False):
    d = r._asdict(); k = int(str(d["age"]).replace("AGEID", ""))
    if k == 0:
        d.update(using_age_class=False, age=0); rows.append(d)
    else:
        for a in range(10 * k - 9, 10 * k + 1):
            e = dict(d); e.update(using_age_class=False, age=a, area=d["area"] / 10.0); rows.append(e)
invA = pd.DataFrame(rows)[inv0.columns]
print(f"inventory: rows {len(inv0)} -> {len(invA)}; area {inv0.area.sum():.4f} -> {invA.area.sum():.4f}; max age {invA.age.max()}")
assert abs(inv0.area.sum() - invA.area.sum()) < 1e-6 * inv0.area.sum()

def make_cfg(dst, gy):
    shutil.copytree(SRC, dst)
    gy.to_csv(os.path.join(dst, "growth_and_yield.csv"), index=False)
    acA.to_csv(os.path.join(dst, "age_classes.csv"), index=False)
    invA.to_csv(os.path.join(dst, "inventory.csv"), index=False)

def gy_with(Vd):
    gy = gyA.copy()
    for ft, v in Vd.items():
        m = gy.c1 == ft
        gy.loc[m, vcols] = np.tile(v, (int(m.sum()), 1))
    return gy

# control config: old curves, annual nodes
make_cfg(os.path.join(OUT, "adapted_ME_CTRL_annual"), gyA)

work = os.path.join(OUT, "probe")
def libcbm_roundtrip(gy, target_curve):
    if os.path.exists(work): shutil.rmtree(work)
    make_cfg(work, gy)
    ev = pd.read_csv(os.path.join(work, "disturbance_events.csv")); ev["disturbance_year"] = 9999
    ev.to_csv(os.path.join(work, "disturbance_events.csv"), index=False)
    pr = [dict(c1=ft, c2="ECO58", c3="OWN0", using_age_class=False, age=a, area=1.0, delay=0, landclass=0,
               historic_disturbance="DISTNAT", last_pass_disturbance="DISTNAT") for ft in FTMAP for a in range(1, AMAX + 1)]
    pd.DataFrame(pr)[inv0.columns].to_csv(os.path.join(work, "inventory.csv"), index=False)
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
    d["target"] = [target_curve(ft, a) for ft, a in zip(d.ft, d.age)]
    d["ratio"] = d.cbm_woody / d.target
    return d

# control round trip: libcbm woody vs python chain on the interpolated old volumes (chain check)
def old_py(ft, a):
    return float(boud(gyA[gyA.c1 == ft][vcols].iloc[0].values[a], fac[ft])[0][0])
dc = libcbm_roundtrip(gyA, old_py); dc["config"] = "CTRL_old_curves"
w = dc[(dc.age >= 20) & (dc.age <= 150)]
print("CTRL: libcbm woody / python chain, ages 20-150, per ft max |r-1|:", w.groupby("ft").ratio.apply(lambda x: round(float((x - 1).abs().max()), 5)).to_dict(), flush=True)

# MEYC2: invert at every integer age, then libcbm correction passes
Vn = {ft: np.array([invert(float(curve[g].loc[a]), fac[ft]) for a in ages]) for ft, g in FTMAP.items()}
tgt = lambda ft, a: float(curve[FTMAP[ft]].loc[a])
passes, best = [], None
for it in range(1, 9):
    d = libcbm_roundtrip(gy_with(Vn), tgt); d["pass"] = it; passes.append(d)
    w = d[(d.age >= 20) & (d.age <= 150)]
    err = float((w.ratio - 1).abs().max())
    print(f"pass {it}: ages 20-150 max |ratio-1| {err:.5f}; per ft " + str(w.groupby("ft").ratio.apply(lambda x: round(float((x - 1).abs().max()), 4)).to_dict()), flush=True)
    if best is None or err < best[0]:
        best = (err, it, {k: v.copy() for k, v in Vn.items()})
    if err < 0.002: break
    for ft in FTMAP:
        x = d[d.ft == ft].set_index("age").reindex(range(1, AMAX + 1))
        r = np.clip(np.where(x.ratio.values > 0, x.ratio.values, 1.0), 0.5, 2.0)
        Vn[ft][1:] = Vn[ft][1:] / r
err, bit, Vn = best
print(f"using pass {bit} (ages 20-150 max err {err:.5f})")
R = pd.concat(passes)
R.to_csv(os.path.join(OUT, "s41meyc2_roundtrip_all_passes_20261016.csv"), index=False)
fin = R[R["pass"] == bit]; w = fin[(fin.age >= 20) & (fin.age <= 150)]
S = w.groupby(["ft", "group"]).agg(min_ratio=("ratio", "min"), max_ratio=("ratio", "max"),
     max_abs_err_pct=("ratio", lambda x: 100 * (x - 1).abs().max()),
     mean_abs_err_pct=("ratio", lambda x: 100 * (x - 1).abs().mean())).reset_index()
S["n_ages_over_2pct"] = w.assign(o=(w.ratio - 1).abs() > 0.02).groupby("ft").o.sum().reindex(S.ft).values
S["pass_2pct"] = S.max_abs_err_pct <= 2.0
S["libcbm_pass_used"] = bit
S["species"] = S.ft.map(smap); S["factor_id"] = S.ft.map(lambda f: int(fac[f]["id"]))
S.to_csv(os.path.join(OUT, "s41meyc2_roundtrip_summary_20261016.csv"), index=False)
print(S.round(4).to_string())

gy = gy_with(Vn)
make_cfg(os.path.join(OUT, "adapted_ME_MEYC2"), gy)
cmp = []
for ft, g in FTMAP.items():
    for a in range(0, AMAX + 1, 10):
        cmp.append(dict(ft=ft, group=g, age=int(a), vol_old_m3ha=float(gyA[gyA.c1 == ft][f"v{a}"].iloc[0]), vol_new_m3ha=float(Vn[ft][a]),
                        woody_old_py_Mgha=old_py(ft, a) if a > 0 else 0.0, agb_mean_new_Mgha=float(curve[g].loc[a]),
                        extrapolated_new=bool(cv[(cv.ftg == g) & (cv.age == a)].extrapolated.iloc[0])))
pd.DataFrame(cmp).to_csv(os.path.join(OUT, "s41meyc2_curves_old_vs_new_20261016.csv"), index=False)
shutil.rmtree(work)
for c in ("adapted_ME_CTRL_annual", "adapted_ME_MEYC2"):
    print("md5 gy", c, hashlib.md5(open(os.path.join(OUT, c, "growth_and_yield.csv"), "rb").read()).hexdigest())
print("done build v2")
