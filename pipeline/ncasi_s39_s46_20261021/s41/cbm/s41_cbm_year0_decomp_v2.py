"""s41 CBM year 0 decomposition. For each state: (1) reproduce the s40 year 0
stock ratio from the existing v4 run outputs; (2) rerun libcbm initialisation
(spinup + 1 step) on a COPY of the FVS_FIAW_NEW adapted config and capture
per stand year 0 pools; (3) recompute the Boudewyn (2007) chain per stand from
the factor rows in the state AIDB to split Other into nonmerch stemwood,
sapling stemwood, bark and branches; (4) aggregate by forest type group.
Writes aggregates only."""
import os, sys, json, shutil, sqlite3, hashlib
import numpy as np, pandas as pd
from libcbm.input.sit import sit_cbm_factory
from libcbm.model.cbm import cbm_simulator
OUT = os.getcwd()
S40 = "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/rerun_v2_20261015"
AGP = ["SoftwoodMerch","SoftwoodFoliage","SoftwoodOther","HardwoodMerch","HardwoodFoliage","HardwoodOther"]
T = dict(ME=762.4297, MN=633.4494)
g = pd.read_csv("/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/gates/grm_realism_fourstate_20261006.csv")
g.columns = [c.lower() for c in g.columns]
for _, r in g.iterrows(): T[r["state"]] = float(r["stock_tg"])
def topd(x): return x.to_pandas() if hasattr(x, "to_pandas") else x
def factor_row(con, suid, sp_name):
    sp = con.execute("select s.id, s.genus_id, s.forest_type_id from species s join species_tr t on t.species_id=s.id and t.locale_id=1 where t.name=?", (sp_name,)).fetchone()
    sid, gid, ftid = sp
    for q, k, lvl in (("select vol_to_bio_factor_id from vol_to_bio_species where spatial_unit_id=? and species_id=?", sid, "species"),
                      ("select vol_to_bio_factor_id from vol_to_bio_genus where spatial_unit_id=? and genus_id=?", gid, "genus"),
                      ("select vol_to_bio_factor_id from vol_to_bio_forest_type where spatial_unit_id=? and forest_type_id=?", ftid, "forest_type")):
        r = con.execute(q, (suid, k)).fetchone()
        if r:
            f = pd.read_sql(f"select * from vol_to_bio_factor where id={r[0]}", con).iloc[0].to_dict()
            f["level"] = lvl; f["species_id"] = sid; f["forest_type_id"] = ftid
            return f
    raise KeyError(sp_name)
def boud(V, f):
    V = np.asarray(V, float); z = np.zeros_like(V)
    pos = V > 0; Vp = np.where(pos, V, 1.0)
    bm = f["a"] * Vp ** f["b"]
    nmf = np.minimum(f["k_nonmerch"] + f["a_nonmerch"] * bm ** f["b_nonmerch"], f["cap_nonmerch"])
    bnm = nmf * bm
    sf = np.minimum(f["k_sap"] + f["a_sap"] * bnm ** f["b_sap"], f["cap_sap"])
    bsnm = sf * bnm
    L = np.log(Vp + 5)
    ea = np.exp(f["a1"] + f["a2"] * Vp + f["a3"] * L); eb = np.exp(f["b1"] + f["b2"] * Vp + f["b3"] * L); ec = np.exp(f["c1"] + f["c2"] * Vp + f["c3"] * L)
    psw = 1 / (1 + ea + eb + ec); pbk = ea * psw; pbr = eb * psw; pfl = ec * psw
    lo = Vp < f["min_volume"]; hi = Vp > f["max_volume"]
    for arr, lk, hk in ((psw, "low_stemwood_prop", "high_stemwood_prop"), (pbk, "low_stembark_prop", "high_stembark_prop"),
                        (pbr, "low_branches_prop", "high_branches_prop"), (pfl, "low_foliage_prop", "high_foliage_prop")):
        arr[lo] = f[lk]; arr[hi] = f[hk]
    tot = bsnm / psw; bark = tot * pbk; br = tot * pbr; fol = tot * pfl
    mbark = bark * bm / bsnm
    d = dict(b_m=bm, b_nonmerch=bnm - bm, b_sap=bsnm - bnm, bark_merch=mbark, bark_other=bark - mbark, branch=br, foliage=fol,
             merch=bm + mbark, other=(bsnm - bm) + (bark - mbark) + br, nmf=nmf, sapf=sf, p_sw=psw)
    return {k: np.where(pos, v, 0.0) for k, v in d.items()}
rep_rows, ft_rows, fac_rows = [], [], []
for ST in sys.argv[1:] or ["ME","NH","VT","MI","WI","MN"]:
    # (1) reproduction from s40 v4 outputs
    P = pd.read_csv(f"{S40}/runs/pools_{ST}_FVS_FIAW_NEW_noharv_10yr.csv").set_index("timestep")
    ag0 = P.loc[0, AGP].sum() / 0.5 / 1e6
    v4 = pd.read_csv(f"{S40}/cbm_gate_results_v4_20261015.csv").set_index(["state","variant"]).loc[(ST,"noharv")]
    # (2) year 0 per stand
    src = f"/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{ST}/adapted_FVS_FIAW_NEW"
    DB = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
    work = os.path.join(OUT, "work", f"{ST}_year0")
    if os.path.exists(work): shutil.rmtree(work)
    shutil.copytree(src, work)
    sit = sit_cbm_factory.load_sit(os.path.join(work, "sit_config.json"), db_path=DB)
    classifiers, inventory = sit_cbm_factory.initialize_inventory(sit)
    cap = {}
    def rep(t, v):
        if t == 0:
            cap["pools"] = topd(v.pools).copy(); cap["area"] = topd(v.inventory)["area"].values.copy()
            cap["age"] = topd(v.state)["age"].values.copy(); cap["cls"] = topd(v.classifiers).copy()
    with sit_cbm_factory.initialize_cbm(sit) as cbm:
        cbm_simulator.simulate(cbm, n_steps=1, classifiers=classifiers, inventory=inventory, reporting_func=rep)
    pools, area, age, cls = cap["pools"], cap["area"], cap["age"], cap["cls"]
    inv_map = {}
    for cname, vals in sit.classifier_value_ids.items():
        inv_map[cname] = {i: n for n, i in vals.items()}
    ft = cls["ForestType"].map(inv_map["ForestType"]).values
    eco = cls["Ecoregion"].map(inv_map["Ecoregion"]).values
    # curve volume at stand age
    ac = pd.read_csv(os.path.join(work, "age_classes.csv"))
    sizes = ac.iloc[:, 1].astype(float).values
    ages = np.cumsum(sizes)
    if sizes[0] != 0: ages = np.concatenate([[0.0], ages])
    print(ST, "age_classes", ac.to_dict("list"), flush=True)
    gy = pd.read_csv(os.path.join(work, "growth_and_yield.csv"))
    vcols = [c for c in gy.columns if c.startswith("v") and c[1:].isdigit()]
    ages = ages[:len(vcols)]
    vol = np.zeros(len(age))
    for i, (f_, e_) in enumerate(zip(ft, eco)):
        r = gy[(gy.c1 == f_) & (gy.c2 == e_)]
        vol[i] = np.interp(age[i], ages, r[vcols].iloc[0].values.astype(float)) if len(r) else np.nan
    # (3) Boudewyn per stand
    cfg = json.load(open(os.path.join(work, "sit_config.json")))["mapping_config"]
    smap = {x["user_species"].replace(" ", ""): x["default_species"] for x in cfg["species"]["species_mapping"]}
    con = sqlite3.connect(DB)
    suid = con.execute("""select su.id from spatial_unit su join admin_boundary_tr a on a.admin_boundary_id=su.admin_boundary_id and a.locale_id=1
                          join eco_boundary_tr e on e.eco_boundary_id=su.eco_boundary_id and e.locale_id=1 where a.name=? and e.name=?""",
                       (cfg["spatial_units"]["admin_boundary"], cfg["spatial_units"]["eco_boundary"])).fetchone()[0]
    fac = {k: factor_row(con, suid, v) for k, v in smap.items()}
    for k, f in fac.items():
        fac_rows.append(dict(state=ST, ft=k, species=smap[k], level=f["level"], factor_id=f["id"], a=f["a"], b=f["b"],
                             k_nonmerch=f["k_nonmerch"], a_nonmerch=f["a_nonmerch"], b_nonmerch=f["b_nonmerch"], cap_nonmerch=f["cap_nonmerch"],
                             k_sap=f["k_sap"], a_sap=f["a_sap"], b_sap=f["b_sap"], cap_sap=f["cap_sap"], forest_type_id=f["forest_type_id"]))
    con.close()
    comp = {k: np.zeros(len(age)) for k in ["b_m","b_nonmerch","b_sap","bark_merch","bark_other","branch","foliage","merch","other","nmf","sapf","p_sw"]}
    for k in set(ft):
        idx = np.where(ft == k)[0]
        b = boud(vol[idx], fac[k])
        for c in comp: comp[c][idx] = b[c]
    d = pd.DataFrame({"ft": ft, "area": area, "age": age, "vol": vol,
                      "cbm_merch": (pools["SoftwoodMerch"] + pools["HardwoodMerch"]).values / 0.5,
                      "cbm_foliage": (pools["SoftwoodFoliage"] + pools["HardwoodFoliage"]).values / 0.5,
                      "cbm_other": (pools["SoftwoodOther"] + pools["HardwoodOther"]).values / 0.5})
    for c in comp: d["bw_" + c] = comp[c]
    wcols = [c for c in d.columns if c.startswith("cbm_") or (c.startswith("bw_") and c not in ("bw_nmf","bw_sapf","bw_p_sw"))] + ["vol"]
    for c in wcols: d[c + "_tot"] = d[c] * d["area"]
    agg = d.groupby("ft")[[c + "_tot" for c in wcols] + ["area"]].sum()
    agg.loc["ALL"] = agg.sum()
    agg = agg / 1e6  # Mg -> Tg, m3 -> Mm3, ha -> Mha
    agg = agg.rename(columns={"area": "area_Mha"}); agg.columns = [c.replace("_tot", "") for c in agg.columns]
    agg["state"] = ST; ft_rows.append(agg.reset_index())
    tot = agg.loc["ALL"]
    rep_rows.append(dict(state=ST, fia_stock_Tg=T[ST], s40_v4_model_stock_Tg=v4["model_stock_Tg"], s40_v4_ratio_stock=v4["ratio_stock"],
                         s41_from_s40_pools_Tg=ag0, s41_ratio_from_s40_pools=ag0 / T[ST],
                         s41_rerun_year0_Tg=tot["cbm_merch"] + tot["cbm_foliage"] + tot["cbm_other"],
                         s41_rerun_ratio=(tot["cbm_merch"] + tot["cbm_foliage"] + tot["cbm_other"]) / T[ST],
                         s41_rerun_woody_ratio=(tot["cbm_merch"] + tot["cbm_other"]) / T[ST],
                         boudewyn_recalc_over_libcbm_merch=tot["bw_merch"] / tot["cbm_merch"],
                         boudewyn_recalc_over_libcbm_other=tot["bw_other"] / tot["cbm_other"],
                         boudewyn_recalc_over_libcbm_foliage=tot["bw_foliage"] / tot["cbm_foliage"],
                         area_Mha=tot["area_Mha"]))
    print(ST, rep_rows[-1], flush=True)
R = pd.DataFrame(rep_rows); F = pd.concat(ft_rows); FA = pd.DataFrame(fac_rows)
tag = "_".join(sys.argv[1:]) if sys.argv[1:] else "all"
R.to_csv(f"s41_cbm_year0_repro_{tag}_20261015.csv", index=False)
F.to_csv(f"s41_cbm_year0_byft_{tag}_20261015.csv", index=False)
FA.to_csv(f"s41_cbm_factor_rows_{tag}_20261015.csv", index=False)
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 40)
print(R.round(4).to_string()); print(F.round(3).to_string()); print(FA.round(4).to_string())
