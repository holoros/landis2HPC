"""s45 Track L null test, part b. cbm_exn is fed the increments the registered CBM3 run used
(net convention, so as they are): per stand row, the CBM3 above ground biomass C curve of its
growth curve (libcbm CBM-CFS3 volume to biomass, smoother on, the registered volumes at the
registered age nodes, species and spatial unit), differenced by age. Spinup with the CBM3 spinup
settings and the inventory's historic and last pass types; 10 steps replaying the captured CBM3
stand splits, areas and disturbance types (sit ids mapped to db ids); increments chosen by the
CBM3 stand age each step. Writes run files in the registered format for the registered scorer.
usage: python L2b_exn_replay.py ST CAPDIR OUTDIR"""
import os, sys, json, sqlite3, hashlib
import numpy as np, pandas as pd
sys.path.insert(0, os.path.dirname(__file__))
import exn_common as E
from libcbm.input.sit import sit_cbm_factory
from libcbm.model.cbm_exn import cbm_exn_model
from libcbm.model.cbm_exn.cbm_exn_parameters import parameters_factory
from libcbm.wrapper.volume_to_biomass.volume_to_biomass_wrapper import VolumeToBiomassWrapper, MerchVolumeCurve

ST, CAP, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(os.path.join(OUT, "runs"), exist_ok=True)
DB = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
W = os.path.join(CAP, "work_copy")
S = E.spin_settings(ST); spu = S["spatial_unit_id"]
AG = ["SoftwoodMerch", "SoftwoodFoliage", "SoftwoodOther", "HardwoodMerch", "HardwoodFoliage", "HardwoodOther"]
sit = sit_cbm_factory.load_sit(os.path.join(W, "sit_config.json"), db_path=DB)
dmap = sit.default_disturbance_id_map
print("sit to db disturbance id map", dmap, sit.default_disturbance_name_map)
cfg = json.load(open(os.path.join(W, "sit_config.json")))["mapping_config"]
smap = {x["user_species"].replace(" ", ""): x["default_species"] for x in cfg["species"]["species_mapping"]}
con = sqlite3.connect(DB)
spid = {k: con.execute("select species_id from species_tr where name=? and locale_id=1", (v,)).fetchone()[0] for k, v in smap.items()}
con.close()
PX = parameters_factory(E.exn_dir(ST), None); swhw = PX.get_sw_hw_map()

# CBM3 biomass C curves per growth curve (classifier set)
gy = pd.read_csv(os.path.join(W, "growth_and_yield.csv")); ac = pd.read_csv(os.path.join(W, "age_classes.csv"))
vcols = [c for c in gy.columns if c.startswith("v") and c[1:].isdigit()]
nodes = np.cumsum(ac.iloc[:, 1].astype(int).values)[:len(vcols)].astype(np.int32)
v2b = VolumeToBiomassWrapper()
AMAX = int(nodes[-1])
curves = {}
for r in gy.itertuples(index=False):
    d = r._asdict(); key = (d["c1"], d["c2"], d["c3"])
    sid = spid[d["leading_species"].replace(" ", "")] if d["leading_species"].replace(" ", "") in spid else spid[d["c1"]]
    vol = np.array([d[c] for c in vcols], dtype=np.float64)
    b = v2b.volume_to_biomass(spu, [MerchVolumeCurve(int(sid), nodes, vol)], use_smoother=True, db_path=DB)
    b = b.set_index(b.Age.astype(int)).reindex(range(1, AMAX + 1))
    sh = swhw[int(sid)]; pre = "SW" if sh == 0 else "HW"
    B = np.vstack([np.zeros(3), b[[f"{pre}Merch", f"{pre}Foliage", f"{pre}Other"]].values])  # ages 0..AMAX, C
    B = np.maximum(B, 0.0)  # libcbm volume to biomass returns -1.1e-16 at one age of two VT curves; cbm_exn spinup rejects negative pools
    curves[key] = dict(sid=int(sid), sw_hw=sh, B=B, inc=np.diff(B, axis=0))  # inc[a-1] = B(a) - B(a-1)
print("curves", len(curves), "AMAX", AMAX)

snap = pd.read_csv(os.path.join(CAP, f"cap_snapshots_{ST}.csv")); steps = pd.read_csv(os.path.join(CAP, f"cap_steps_{ST}.csv"))
s0 = snap[snap.t == 0].sort_values("row").reset_index(drop=True)
keys = list(zip(s0.ForestType, s0.Ecoregion, s0.Owner))
n0 = len(s0)
def inc_for(keylist, ages):
    out = np.zeros((len(ages), 3))
    for i, (k, a) in enumerate(zip(keylist, ages)):
        if 1 <= a <= AMAX:
            out[i] = curves[k]["inc"][a - 1]
    return out

# spinup inputs
par = pd.DataFrame({"age": s0.inv_age.astype(int).values, "area": s0.area.values, "delay": s0.inv_delay.astype(int).values,
                    "return_interval": S["return_interval"], "min_rotations": S["min_rotations"], "max_rotations": S["max_rotations"],
                    "spatial_unit_id": s0.inv_spatial_unit.astype(int).values,
                    "species": [curves[k]["sid"] for k in keys], "sw_hw": [curves[k]["sw_hw"] for k in keys],
                    "mean_annual_temperature": S["historic_mean_temperature"],
                    "historical_disturbance_type": [dmap[int(x)] for x in s0.inv_historical_disturbance_type],
                    "last_pass_disturbance_type": [dmap[int(x)] for x in s0.inv_last_pass_disturbance_type]})
assert (par.spatial_unit_id == spu).all()
inc_rows = []
for i, k in enumerate(keys):
    I = curves[k]["inc"]
    inc_rows.append(pd.DataFrame({"row_idx": i, "age": np.arange(1, AMAX + 1), "merch_inc": I[:, 0], "foliage_inc": I[:, 1], "other_inc": I[:, 2]}))
incs = pd.concat(inc_rows, ignore_index=True)

def agg(t, v, recs, frecs):
    pools = v["pools"]; area = v["state"]["area"].values; sh = v["state"]["sw_hw"].values
    r = {}
    for p in pools.columns:
        r[p] = float((pools[p].values * area).sum())
    for nm, ex in (("Merch", "Merch"), ("Foliage", "Foliage"), ("Other", "Other"), ("CoarseRoots", "CoarseRoots"), ("FineRoots", "FineRoots")):
        r["Softwood" + nm] = float((pools[ex].values * area * (sh == 0)).sum()); r["Hardwood" + nm] = float((pools[ex].values * area * (sh == 1)).sum())
    r["timestep"] = t; r["total_area_ha"] = float(area.sum()); recs.append(r)
    fl = v["flux"]; f = {c: float((fl[c].values * area).sum()) for c in fl.columns}
    f["DisturbanceSoftProduction"] = float((fl["DisturbanceProduction"].values * area * (sh == 0)).sum())
    f["DisturbanceHardProduction"] = float((fl["DisturbanceProduction"].values * area * (sh == 1)).sum())
    f["timestep"] = t; frecs.append(f)

def rowcheck(t, v, snapt):
    sh = v["state"]["sw_hw"].values; P = v["pools"]
    ex_ag = P["Merch"].values + P["Foliage"].values + P["Other"].values
    cb = snapt.sort_values("row")[AG].sum(axis=1).values
    return dict(t=t, n=len(cb), max_abs_C=float(np.abs(ex_ag - cb).max()), max_rel=float((np.abs(ex_ag - cb) / np.maximum(cb, 1e-9)).max()),
                area_w_rel=float((np.abs(ex_ag - cb) * v["state"]["area"].values).sum() / (cb * v["state"]["area"].values).sum()))

recs, frecs, chk = [], [], []
with cbm_exn_model.initialize(config_path=E.exn_dir(ST)) as m:
    v = m.spinup({"parameters": par, "increments": incs})
    for k in list(v.keys()):
        v[k] = v[k].reset_index(drop=True)
    v["parameters"]["mean_annual_temperature"] = S["mean_annual_temperature"]
    agg(0, v, recs, frecs); chk.append(rowcheck(0, v, s0))
    print("t0 row check", chk[-1], flush=True)
    rk = list(keys)
    for t in range(1, 11):
        st = steps[steps.t == t].sort_values("row").reset_index(drop=True)
        nrow = len(v["pools"])
        new = st[st.row >= nrow]
        if len(new):
            assert (new.row.values == np.arange(nrow, nrow + len(new))).all()
            for k in v.keys():
                v[k] = pd.concat([v[k], v[k].iloc[new.parent.values]], ignore_index=True)
            rk = rk + [rk[p] for p in new.parent.values]
        assert len(v["pools"]) == len(st)
        v["state"]["area"] = st.area_pre.values
        se = snap[snap.t == t].sort_values("row").reset_index(drop=True)
        ages = se.age_end.astype(int).values
        I = inc_for(rk, ages)
        dist = np.array([dmap[int(x)] if x > 0 else 0 for x in st.disturbance_type.values])
        v["parameters"]["mean_annual_temperature"] = S["mean_annual_temperature"]
        v = E.step(m, v, I[:, 0], I[:, 1], I[:, 2], dist)
        agg(t, v, recs, frecs); chk.append(rowcheck(t, v, se))
        print(f"t{t} rows {len(st)} disturbed {(dist > 0).sum()} row check", chk[-1], flush=True)
P = pd.DataFrame(recs); F = pd.DataFrame(frecs)
P.to_csv(os.path.join(OUT, "runs", f"pools_{ST}_FVS_FIAW_NEW_noharv_10yr.csv"), index=False)
F.to_csv(os.path.join(OUT, "runs", f"flux_{ST}_FVS_FIAW_NEW_noharv_10yr.csv"), index=False)
pd.DataFrame(chk).assign(state=ST).to_csv(os.path.join(OUT, f"L2b_rowcheck_{ST}.csv"), index=False)
print("done replay", ST)
