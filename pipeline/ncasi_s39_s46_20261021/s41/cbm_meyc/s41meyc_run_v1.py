"""s41 cbm_meyc run: the s40 cbm_gate_run_v2_20261015.py noharv arm, unchanged in
logic, with --src pointing at an adapted config directory (here the MEYC new
curve configuration built by s41meyc_build_v1.py). Harvest types are removed by
name exactly as in s40; natural disturbance events kept. Output files keep the
s40 layout and the FVS_FIAW_NEW label in their names ONLY so the unmodified v4
scorer can read them; they are written under this run's own outdir and are a
new curve configuration, not the registered cell. Adds runs/agearea_*.csv:
year 0 area by forest type and 10 yr age bin (aggregate).
usage: python s41meyc_run_v1.py ST outdir --src DIR [--years N]"""
import argparse, os, shutil, hashlib, re
import numpy as np, pandas as pd
from libcbm.input.sit import sit_cbm_factory
from libcbm.model.cbm import cbm_simulator
AG = ["SoftwoodMerch","SoftwoodFoliage","SoftwoodOther","HardwoodMerch","HardwoodFoliage","HardwoodOther"]
def topd(x): return x.to_pandas() if hasattr(x, "to_pandas") else x
ap = argparse.ArgumentParser(); ap.add_argument("state"); ap.add_argument("outdir")
ap.add_argument("--src", required=True); ap.add_argument("--years", type=int, default=10)
a = ap.parse_args(); ST, V = a.state, "noharv"
DB = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
work = os.path.join(a.outdir, "work", f"{ST}_MEYC_{V}")
if os.path.exists(work): shutil.rmtree(work)
shutil.copytree(a.src, work)
print("gy md5", hashlib.md5(open(os.path.join(work, "growth_and_yield.csv"), "rb").read()).hexdigest())
ev = pd.read_csv(os.path.join(work, "disturbance_events.csv")); n_before = len(ev)
dt = pd.read_csv(os.path.join(work, "disturbance_types.csv"))
hv = dt[dt["name"].str.contains(r"clear ?cut|partial cut|harvest|thinning|selection cut|shelterwood", case=False, regex=True)]
hid = sorted(hv["id"].tolist())
print(f"ASSERT {ST} harvest types by name: " + "; ".join(f"{i}={n}" for i, n in zip(hv["id"], hv["name"])))
assert len(hid) >= 1
m = ev["disturbance_type"].isin(hid)
print(f"ASSERT {ST} removed IDs {hid}: {int(m.sum())} event rows moved to year 9999")
ev.loc[m, "disturbance_year"] = 9999
ev.to_csv(os.path.join(work, "disturbance_events.csv"), index=False)
yrs = ev.loc[~m & (ev.disturbance_year <= a.years)]
print(f"{ST} {V}: events {n_before}, moved {int(m.sum())}, active in years 1..{a.years}: {len(yrs)}")
print("db", DB, hashlib.md5(open(DB, "rb").read()).hexdigest())
sit = sit_cbm_factory.load_sit(os.path.join(work, "sit_config.json"), db_path=DB)
classifiers, inventory = sit_cbm_factory.initialize_inventory(sit)
inv_map = {n: {i: s for s, i in vals.items()} for n, vals in sit.classifier_value_ids.items()}
recs, frecs, grp, aa = [], [], [], []; prev = {}
def rep(t, v):
    pools = topd(v.pools); inv = topd(v.inventory); flux = topd(v.flux); state = topd(v.state)
    area = inv["area"].values
    pn = pools.select_dtypes(include=["number"]).columns
    r = pools[pn].multiply(area, axis=0).sum(axis=0).to_dict(); r["timestep"] = t; r["total_area_ha"] = float(area.sum()); recs.append(r)
    fn = flux.select_dtypes(include=["number"]).columns
    f = flux[fn].multiply(area, axis=0).sum(axis=0).to_dict(); f["timestep"] = t; frecs.append(f)
    ag = pools[AG].sum(axis=1).values; age = state["age"].values
    if t == 0:
        ft = topd(v.classifiers)["ForestType"].map(inv_map["ForestType"]).values
        d0 = pd.DataFrame({"ft": ft, "age_bin10": (age // 10) * 10, "area": area, "AG_C": ag * area})
        aa.append(d0.groupby(["ft", "age_bin10"]).sum().reset_index())
    if t >= 1:
        agp = prev["v"] if len(prev["v"]) == len(ag) else ag
        abin = pd.cut(age, [-1,20,40,60,80,100,120,10000], labels=["0-20","21-40","41-60","61-80","81-100","101-120",">120"])
        bbin = pd.cut(agp * 200.0, [-1,5000,10000,15000,20000,25000,30000,1e12], labels=["[0,50)","[50,100)","[100,150)","[150,200)","[200,250)","[250,300)","[300,Inf)"])
        d = pd.DataFrame({"area": area, "dAG": (ag - agp) * area, "AG": ag * area})
        for c in fn: d[c] = flux[c].values * area
        for kind, b in (("age", abin), ("biomass", bbin)):
            gg = d.groupby(b, observed=False).sum(numeric_only=True); gg["kind"] = kind; gg["bin"] = gg.index.astype(str); gg["timestep"] = t
            grp.append(gg.reset_index(drop=True))
    prev["v"] = ag
with sit_cbm_factory.initialize_cbm(sit) as cbm:
    rb = sit_cbm_factory.create_sit_rule_based_processor(sit, cbm)
    cbm_simulator.simulate(cbm, n_steps=a.years, classifiers=classifiers, inventory=inventory,
                           reporting_func=rep, pre_dynamics_func=rb.pre_dynamics_func)
o = os.path.join(a.outdir, "runs"); os.makedirs(o, exist_ok=True)
pd.DataFrame(recs).to_csv(f"{o}/pools_{ST}_FVS_FIAW_NEW_{V}_{a.years}yr.csv", index=False)
pd.DataFrame(frecs).to_csv(f"{o}/flux_{ST}_FVS_FIAW_NEW_{V}_{a.years}yr.csv", index=False)
pd.concat(grp).to_csv(f"{o}/bins_{ST}_FVS_FIAW_NEW_{V}_{a.years}yr.csv", index=False)
pd.concat(aa).to_csv(f"{o}/agearea_{ST}_{a.years}yr.csv", index=False)
print("done", ST, V, a.years)
