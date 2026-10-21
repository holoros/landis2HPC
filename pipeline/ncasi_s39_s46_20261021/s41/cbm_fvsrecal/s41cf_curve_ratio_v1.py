"""s41 cbm_fvsrecal: curve volume at the CBM inventory ages against FIA 2024 net merchantable volume
(session 41 ratio method, the r_vol column of s41_cbm_year0_decomp_v2.py): libcbm initialisation (spinup and
one step) on a COPY of an adapted FVS_FIAW_NEW config, each stand's curve volume interpolated at its age,
area weighted sum over FIA VOLCFNET from s41_fia_nsvb_components_20261015.csv (public DataMart, EVALID ST2401).
Aggregates only.  usage: python s41cf_curve_ratio_v1.py OUTCSV LABEL ADAPTED_ROOT_PATTERN(with {ST}) WORKDIR"""
import os, sys, shutil
import numpy as np, pandas as pd
from libcbm.input.sit import sit_cbm_factory
from libcbm.model.cbm import cbm_simulator
out, lab, pat, wd = sys.argv[1:5]
FIA = pd.read_csv("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cbm/s41_fia_nsvb_components_20261015.csv")
def topd(x): return x.to_pandas() if hasattr(x, "to_pandas") else x
rows = []
for ST in ["ME", "NH", "VT", "MI", "WI", "MN"]:
    src = pat.format(ST=ST)
    DB = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
    work = os.path.join(wd, f"{lab}_{ST}_year0")
    if os.path.exists(work): shutil.rmtree(work)
    shutil.copytree(src, work)
    sit = sit_cbm_factory.load_sit(os.path.join(work, "sit_config.json"), db_path=DB)
    classifiers, inventory = sit_cbm_factory.initialize_inventory(sit)
    cap = {}
    def rep(t, v):
        if t == 0:
            cap["area"] = topd(v.inventory)["area"].values.copy(); cap["age"] = topd(v.state)["age"].values.copy(); cap["cls"] = topd(v.classifiers).copy()
    with sit_cbm_factory.initialize_cbm(sit) as cbm:
        cbm_simulator.simulate(cbm, n_steps=1, classifiers=classifiers, inventory=inventory, reporting_func=rep)
    area, age, cls = cap["area"], cap["age"], cap["cls"]
    inv_map = {c: {i: n for n, i in vals.items()} for c, vals in sit.classifier_value_ids.items()}
    ft = cls["ForestType"].map(inv_map["ForestType"]).values; eco = cls["Ecoregion"].map(inv_map["Ecoregion"]).values
    ac = pd.read_csv(os.path.join(work, "age_classes.csv")); sizes = ac.iloc[:, 1].astype(float).values
    ages = np.cumsum(sizes)
    if sizes[0] != 0: ages = np.concatenate([[0.0], ages])
    gy = pd.read_csv(os.path.join(work, "growth_and_yield.csv"))
    vcols = [c for c in gy.columns if c.startswith("v") and c[1:].isdigit()]; ages = ages[:len(vcols)]
    vol = np.zeros(len(age))
    for i, (f_, e_) in enumerate(zip(ft, eco)):
        r = gy[(gy.c1 == f_) & (gy.c2 == e_)]
        vol[i] = np.interp(age[i], ages, r[vcols].iloc[0].values.astype(float)) if len(r) else np.nan
    d = pd.DataFrame({"ft": ft, "area": area, "age": age, "vol": vol})
    d["vt"] = d.vol * d.area; d["at"] = d.age * d.area
    g = d.groupby("ft").agg(area_Mha=("area", "sum"), vol_Mm3=("vt", "sum"), at=("at", "sum")).reset_index()
    g.loc[len(g)] = ["ALL", d.area.sum(), d.vt.sum(), d["at"].sum()]
    g["area_Mha"] /= 1e6; g["vol_Mm3"] /= 1e6; g["mean_age"] = g["at"] / 1e6 / g.area_Mha; g = g.drop(columns="at")
    f = FIA[FIA.state == ST].copy(); f["ft"] = np.where(f.TYPGRPCD == -1, "ALL", "FT" + f.TYPGRPCD.astype(str))
    g = g.merge(f[["ft", "volcfnet_Mm3"]], on="ft", how="left")
    g["curve_over_fia_volcfnet"] = g.vol_Mm3 / g.volcfnet_Mm3; g["state"] = ST; g["curves"] = lab
    g["n_nan_stands"] = int(np.isnan(vol).sum())
    rows.append(g); print(ST, lab, g[g.ft == "ALL"].round(4).to_dict("records"), flush=True)
R = pd.concat(rows); R.to_csv(out, index=False)
