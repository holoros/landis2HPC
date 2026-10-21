"""s45 Track L null test, part a. Reruns the registered CBM3 noharv run from a COPY of its
registered work directory (B/cbm/rerun_v2_20261015/work/{ST}_FVS_FIAW_NEW_noharv, events already
moved), with the same libcbm calls as cbm_gate_run_v2_20261015.py, and captures per step and stand
row what cbm_exn needs to replay the same run: t0 rows and spinup inputs, ages, areas, disturbance
types and stand splits. Writes run files in the registered format and compares them with the
registered files (the capture run must reproduce the registered run).
usage: python L2a_capture_cbm3.py ST OUTDIR"""
import os, sys, shutil, hashlib
import numpy as np, pandas as pd
from libcbm.input.sit import sit_cbm_factory
from libcbm.model.cbm import cbm_simulator

ST, OUT = sys.argv[1], sys.argv[2]
REG = "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/rerun_v2_20261015"
DB = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
AG = ["SoftwoodMerch", "SoftwoodFoliage", "SoftwoodOther", "HardwoodMerch", "HardwoodFoliage", "HardwoodOther"]
os.makedirs(OUT, exist_ok=True)
work = os.path.join(OUT, "work_copy")
if os.path.exists(work): shutil.rmtree(work)
shutil.copytree(os.path.join(REG, "work", f"{ST}_FVS_FIAW_NEW_noharv"), work)
for f in sorted(os.listdir(work)):
    print("md5", f, hashlib.md5(open(os.path.join(work, f), "rb").read()).hexdigest())
print("db", hashlib.md5(open(DB, "rb").read()).hexdigest())
def topd(x): return x.to_pandas() if hasattr(x, "to_pandas") else x

sit = sit_cbm_factory.load_sit(os.path.join(work, "sit_config.json"), db_path=DB)
classifiers, inventory = sit_cbm_factory.initialize_inventory(sit)
inv_map = {n: {i: s for s, i in vals.items()} for n, vals in sit.classifier_value_ids.items()}
cnames = list(sit.classifier_value_ids.keys())
recs, frecs, snaps, steps = [], [], [], []

def rep(t, cbm_vars):
    pools = topd(cbm_vars.pools); inv = topd(cbm_vars.inventory); flux = topd(cbm_vars.flux); state = topd(cbm_vars.state)
    area = inv["area"].values
    pn = pools.select_dtypes(include=["number"]).columns
    r = pools[pn].multiply(area, axis=0).sum(axis=0).to_dict(); r["timestep"] = t; r["total_area_ha"] = float(area.sum()); recs.append(r)
    fn = flux.select_dtypes(include=["number"]).columns
    f = flux[fn].multiply(area, axis=0).sum(axis=0).to_dict(); f["timestep"] = t; frecs.append(f)
    cl = topd(cbm_vars.classifiers)
    s = pd.DataFrame({"t": t, "row": np.arange(len(area)), "age_end": state["age"].values, "area": area})
    for c in cnames:
        s[c] = cl[c].map(inv_map[c]).values
    for p in AG:
        s[p] = pools[p].values
    if t == 0:
        for c in inv.columns:
            if c not in s.columns and c != "area":
                s["inv_" + c] = inv[c].values
    snaps.append(s)

def pre(t, cbm_vars):
    pb = topd(cbm_vars.pools); cb = topd(cbm_vars.classifiers); ab = topd(cbm_vars.state)["age"].values.copy()
    nb = len(pb)
    keyb = np.column_stack([pb.select_dtypes(include=["number"]).values, cb.values.astype(float), ab.astype(float)])
    lut = {}
    for i in range(nb):
        lut.setdefault(keyb[i].tobytes(), []).append(i)
    cbm_vars = rb.pre_dynamics_func(t, cbm_vars)
    pa = topd(cbm_vars.pools); ca = topd(cbm_vars.classifiers); aa = topd(cbm_vars.state)["age"].values
    na = len(pa)
    keya = np.column_stack([pa.select_dtypes(include=["number"]).values, ca.values.astype(float), aa.astype(float)])
    assert np.array_equal(keya[:nb], keyb), "existing rows changed by pre dynamics"
    parent = np.full(na, -1)
    for j in range(nb, na):
        c = lut.get(keya[j].tobytes())
        assert c, f"no parent found for split row {j}"
        parent[j] = c[0]
    par = topd(cbm_vars.parameters)
    st = pd.DataFrame({"t": t, "row": np.arange(na), "parent": parent, "disturbance_type": par["disturbance_type"].values,
                       "reset_age": par["reset_age"].values if "reset_age" in par.columns else np.nan,
                       "area_pre": topd(cbm_vars.inventory)["area"].values, "age_start": aa})
    steps.append(st)
    return cbm_vars

with sit_cbm_factory.initialize_cbm(sit) as cbm:
    rb = sit_cbm_factory.create_sit_rule_based_processor(sit, cbm)
    cbm_simulator.simulate(cbm, n_steps=10, classifiers=classifiers, inventory=inventory, reporting_func=rep, pre_dynamics_func=pre)
o = os.path.join(OUT, "runs"); os.makedirs(o, exist_ok=True)
P = pd.DataFrame(recs); F = pd.DataFrame(frecs)
P.to_csv(f"{o}/pools_{ST}_FVS_FIAW_NEW_noharv_10yr.csv", index=False); F.to_csv(f"{o}/flux_{ST}_FVS_FIAW_NEW_noharv_10yr.csv", index=False)
pd.concat(snaps).to_csv(os.path.join(OUT, f"cap_snapshots_{ST}.csv"), index=False)
S = pd.concat(steps); S.to_csv(os.path.join(OUT, f"cap_steps_{ST}.csv"), index=False)
print("rows per step:", S.groupby("t").row.size().to_dict())
print("split rows per step:", S[S.parent >= 0].groupby("t").row.size().to_dict())
print("disturbed rows per step and type:", S[S.disturbance_type > 0].groupby(["t", "disturbance_type"]).row.size().to_dict())
print("reset_age values:", S.reset_age.value_counts(dropna=False).to_dict())
for k, X in (("pools", P), ("flux", F)):
    R = pd.read_csv(f"{REG}/runs/{k}_{ST}_FVS_FIAW_NEW_noharv_10yr.csv")
    cols = [c for c in R.columns if c in X.columns and c != "timestep"]
    d = (X[cols].values - R[cols].values); rel = np.abs(d) / np.maximum(np.abs(R[cols].values), 1e-9)
    print(f"REPRO {k}: max abs diff {np.abs(d).max():.3e}, max rel {rel.max():.3e}, columns {len(cols)}, missing {set(R.columns) - set(X.columns)}")
print("done capture", ST)
