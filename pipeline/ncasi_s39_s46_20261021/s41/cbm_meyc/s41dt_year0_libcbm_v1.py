"""s41 year 0 decomposition redone with libcbm's OWN volume to biomass routine
(libcbm.wrapper.volume_to_biomass, CBM3 and Extended modes) instead of the Python
Boudewyn chain used in s41_cbm_year0_decomp_v2.py and s41_conv_test_v1.py.
Registered FVS_FIAW_NEW configs, read only. Post hoc diagnostic.
(a) CBM side: for every inventory stand (libcbm init, as decomp v2) the stand's
    curve (gy row by ForestType x Ecoregion, linearly interpolated to annual ages,
    which s41 cbm_meyc v2 showed is what libcbm does) is converted by libcbm with
    the smoother ON (as in the runs); the row at the stand age gives Merch
    (stemwood, bark), Other (bark, branch, sapling, nonmerch, stump, top) and
    Foliage. Their sum is checked against the spinup pools.
(b) Chain on FIA volumes: each forest condition's net merchantable volume
    (VOLCFNET, m3/ha) converted pointwise by libcbm with the smoother OFF (a
    one-point conversion; pointwise behaviour verified by permutation), compared
    with FIA DRYBIO_AG. Groups not in the CBM classifier set map to FT 999, as v1.
Carbon -> dry biomass via the conversion_info carbon fractions (0.5).
Aggregates only (no plot ids). usage: python s41dt_year0_libcbm_v1.py OUTPREFIX"""
import os, sys, json, shutil, sqlite3
import numpy as np, pandas as pd
from libcbm.input.sit import sit_cbm_factory
from libcbm.model.cbm import cbm_simulator
from libcbm.wrapper.volume_to_biomass.volume_to_biomass_wrapper import VolumeToBiomassWrapper, MerchVolumeCurve
PRE = sys.argv[1]
S41 = "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm"
COND = pd.read_csv(f"{S41}/s41_fia_condtable_20261015_CARDINAL_ONLY.csv")
NSVB = pd.read_csv(f"{S41}/s41_fia_nsvb_components_20261015.csv")
OLDDEC = pd.read_csv("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm_meyc/dt/inputs/s41_year0_decomposition_20261015.csv")
OLDCONV = pd.read_csv(f"{S41}/s41_conv_test_on_fia_volumes_20261015.csv")
W = VolumeToBiomassWrapper()
EXT = ["MerchBark","MerchStemwood","OtherBark","OtherBranch","OtherSapling","OtherNonmerch","OtherStump","OtherTop"]
def topd(x): return x.to_pandas() if hasattr(x, "to_pandas") else x
def v2b(suid, sid, vols, db, smoother, mode):
    a = np.arange(1, len(vols) + 1, dtype=np.int32)
    r = W.volume_to_biomass(suid, [MerchVolumeCurve(int(sid), a, np.ascontiguousarray(vols, dtype=np.float64))], use_smoother=smoother, conversion_mode=mode, db_path=db)
    cf = r.attrs["conversion_info"]; assert all(abs(v - 0.5) < 1e-9 for k, v in cf.items() if "carbon_fraction" in k), cf
    o = pd.DataFrame({"merch": r.SWMerch + r.HWMerch, "other": r.SWOther + r.HWOther, "foliage": r.SWFoliage + r.HWFoliage}) / 0.5
    if mode == 1:
        for e in EXT: o[e] = (r["SW" + e] + r["HW" + e]) / 0.5
    return o
rows_all, rows_grp, perm = [], [], []
for ST in ["ME","NH","VT","MI","WI","MN"]:
    src = f"/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{ST}/adapted_FVS_FIAW_NEW"
    DB = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
    work = os.path.join(os.getcwd(), "work", f"{ST}_y0"); shutil.rmtree(work, ignore_errors=True); shutil.copytree(src, work)
    sit = sit_cbm_factory.load_sit(os.path.join(work, "sit_config.json"), db_path=DB)
    classifiers, inventory = sit_cbm_factory.initialize_inventory(sit)
    cap = {}
    def rep(t, v):
        if t == 0:
            cap["p"] = topd(v.pools).copy(); cap["area"] = topd(v.inventory)["area"].values.copy()
            cap["age"] = topd(v.state)["age"].values.copy(); cap["cls"] = topd(v.classifiers).copy()
    with sit_cbm_factory.initialize_cbm(sit) as cbm:
        cbm_simulator.simulate(cbm, n_steps=1, classifiers=classifiers, inventory=inventory, reporting_func=rep)
    inv_map = {n: {i: s for s, i in vals.items()} for n, vals in sit.classifier_value_ids.items()}
    ft = cap["cls"]["ForestType"].map(inv_map["ForestType"]).values; eco = cap["cls"]["Ecoregion"].map(inv_map["Ecoregion"]).values
    age = cap["age"].astype(int); area = cap["area"]; p = cap["p"]
    cfg = json.load(open(os.path.join(work, "sit_config.json")))["mapping_config"]
    smap = {x["user_species"].replace(" ", ""): x["default_species"] for x in cfg["species"]["species_mapping"]}
    con = sqlite3.connect(DB)
    suid = con.execute("""select su.id from spatial_unit su join admin_boundary_tr a on a.admin_boundary_id=su.admin_boundary_id and a.locale_id=1
        join eco_boundary_tr e on e.eco_boundary_id=su.eco_boundary_id and e.locale_id=1 where a.name=? and e.name=?""",
        (cfg["spatial_units"]["admin_boundary"], cfg["spatial_units"]["eco_boundary"])).fetchone()[0]
    sid = {k: con.execute("select species_id from species_tr where name=? and locale_id=1", (v,)).fetchone()[0] for k, v in smap.items()}
    con.close()
    ac = pd.read_csv(os.path.join(work, "age_classes.csv")); sizes = ac.iloc[:, 1].astype(int).values; nodes = np.cumsum(sizes)
    gy = pd.read_csv(os.path.join(work, "growth_and_yield.csv")); vcols = [c for c in gy.columns if c.startswith("v") and c[1:].isdigit()]
    nodes = nodes[:len(vcols)]; amax = int(max(nodes[-1], age.max()))
    comp = pd.DataFrame(0.0, index=range(len(age)), columns=["merch","other","foliage"] + EXT); vol = np.zeros(len(age))
    for (f_, e_), idx in pd.DataFrame({"f": ft, "e": eco}).groupby(["f","e"]).groups.items():
        r = gy[(gy.c1 == f_) & (gy.c2 == e_)]
        va = np.interp(np.arange(1, amax + 1), nodes, r[vcols].iloc[0].values.astype(float))
        o = v2b(suid, sid[f_], va, DB, True, 1)
        idx = np.asarray(list(idx)); a = age[idx]; ok = a >= 1
        comp.loc[idx[ok], :] = o.iloc[a[ok] - 1][comp.columns].values
        vol[idx] = np.where(ok, va[np.clip(a - 1, 0, None)], 0.0)
    d = comp.copy(); d["ft"] = ft; d["area"] = area; d["vol"] = vol
    d["pool_merch"] = (p.SoftwoodMerch + p.HardwoodMerch).values / 0.5; d["pool_other"] = (p.SoftwoodOther + p.HardwoodOther).values / 0.5
    d["pool_fol"] = (p.SoftwoodFoliage + p.HardwoodFoliage).values / 0.5
    num = [c for c in d.columns if c not in ("ft", "area")]
    for c in num: d[c] = d[c] * d.area / 1e6  # Tg, Mm3
    G = d.groupby("ft")[num + ["area"]].sum(); G.loc["ALL"] = G.sum()
    # (b) chain on FIA volumes, libcbm pointwise, smoother off
    C = COND[COND.state == ST].copy(); codes = {int(k[2:]): k for k in smap}
    C["ftk"] = C.TYPGRPCD.map(lambda x: codes.get(int(x), "FT999"))
    C["lw"] = 0.0; C["lf"] = 0.0
    for k, idx in C.groupby("ftk").groups.items():
        v = C.loc[idx, "vnet_m3ha"].values.astype(float); o = v2b(suid, sid[k], np.maximum(v, 0), DB, False, 0)
        C.loc[idx, "lw"] = np.where(v > 0, (o.merch + o.other).values, 0.0); C.loc[idx, "lf"] = np.where(v > 0, o.foliage.values, 0.0)
        if len(v) > 5 and k in ("FT120", "FT800"):
            pr = np.random.default_rng(1).permutation(len(v)); o2 = v2b(suid, sid[k], np.maximum(v[pr], 0), DB, False, 0)
            perm.append(dict(state=ST, ft=k, n=len(v), pointwise_ok=bool(np.allclose((o2.merch + o2.other).values, (o.merch + o.other).values[pr]))))
    for c in ["lw", "lf", "ag_tha", "fol_tha", "vnet_m3ha"]: C[c + "_T"] = C[c] * C.area_ha / 1e6
    CG = C.groupby("ftk")[["lw_T","lf_T","ag_tha_T","fol_tha_T","vnet_m3ha_T","area_ha"]].sum(); CG.loc["ALL"] = CG.sum()
    N = NSVB[NSVB.state == ST].copy(); N["ftk"] = N.TYPGRPCD.map(lambda x: "ALL" if x == -1 else codes.get(int(x), "FT999"))
    N = N.groupby("ftk").sum(numeric_only=True)
    oc = OLDCONV[OLDCONV.state == ST].copy(); oc["ftk"] = oc.group.map(lambda x: "ALL" if x == "ALL" else f"FT{int(x)}"); oc = oc.set_index("ftk")
    od = OLDDEC[OLDDEC.state == ST].set_index("ft")
    for k in G.index:
        g_ = G.loc[k]
        if k not in N.index: continue
        n = N.loc[k]; woody = g_.pool_merch + g_.pool_other
        row = dict(state=ST, ft=k, area_Mha=g_.area / 1e6, fia_AG_Tg=n.fia_AG_Tg,
                   v2b_over_pools_merch=g_.merch / g_.pool_merch if g_.pool_merch else np.nan,
                   v2b_over_pools_other=g_.other / g_.pool_other if g_.pool_other else np.nan,
                   v2b_over_pools_fol=g_.foliage / g_.pool_fol if g_.pool_fol else np.nan,
                   ratio_stock_registered=(woody + g_.pool_fol) / n.fia_AG_Tg, r_woody=woody / n.fia_AG_Tg,
                   r_vol=g_.vol / n.volcfnet_Mm3 if n.volcfnet_Mm3 else np.nan,
                   r_merch_pool=g_.merch / n.merch_Tg, r_merchwood=g_.MerchStemwood / n.merch_wood_Tg, r_other_pool=g_.other / n.other_Tg,
                   r_branch=g_.OtherBranch / n.branch_all_Tg, r_bark=(g_.MerchBark + g_.OtherBark) / n.bark_all_Tg, r_fol=g_.foliage / n.foliage_Tg,
                   cbm_branch_share_of_other=g_.OtherBranch / g_.other, fia_branch_share_of_other=n.other_branch_big_Tg / n.other_Tg,
                   cbm_other_over_merch=g_.other / g_.merch, cbm_Tg_merch=g_.merch, cbm_Tg_other=g_.other, cbm_Tg_fol=g_.foliage)
        for e in EXT: row["cbm_Tg_" + e] = g_[e]
        row["r_conv"] = row["r_woody"] / row["r_vol"] if row["r_vol"] else np.nan
        if k in CG.index:
            cg = CG.loc[k]; row["chain_on_fia_vol_libcbm"] = cg.lw_T / cg.ag_tha_T if cg.ag_tha_T else np.nan
            row["chain_fol_on_fia_vol_libcbm"] = cg.lf_T / cg.fol_tha_T if cg.fol_tha_T else np.nan
        row["chain_on_fia_vol_python_s41"] = oc.loc[k, "ratio_woody"] if k in oc.index else np.nan
        for c in ["r_woody","r_vol","r_conv","r_merchwood","r_branch","r_bark","r_fol"]:
            row[c + "_python_s41"] = od.loc[k, c] if (k in od.index and c in od.columns) else np.nan
        (rows_all if k == "ALL" else rows_grp).append(row)
    print(ST, {k: round(v, 4) for k, v in rows_all[-1].items() if isinstance(v, float)}, flush=True)
A = pd.DataFrame(rows_all); B = pd.DataFrame(rows_grp)
A.to_csv(f"{PRE}_state_20261016.csv", index=False); B.to_csv(f"{PRE}_group_20261016.csv", index=False); pd.DataFrame(perm).to_csv(f"{PRE}_pointwise_check_20261016.csv", index=False)
pd.set_option("display.width", 300); pd.set_option("display.max_columns", 60)
print(A[["state","v2b_over_pools_merch","v2b_over_pools_other","v2b_over_pools_fol","ratio_stock_registered","r_woody","r_woody_python_s41","r_vol","r_conv",
         "chain_on_fia_vol_libcbm","chain_on_fia_vol_python_s41","r_merch_pool","r_merchwood","r_merchwood_python_s41","r_other_pool","r_branch","r_branch_python_s41",
         "r_bark","r_bark_python_s41","r_fol","cbm_branch_share_of_other","fia_branch_share_of_other"]].round(3).to_string())
print(pd.DataFrame(perm).to_string())
