"""NCASI Phase 1 CBM-CFS3 realism gate, 15 Oct 2026.
Reruns one existing 2x2 cell (FVS_FIAW_NEW) for N years from a COPY of its
adapted SIT config, with an events variant, saving area-weighted pools and
ALL libcbm flux indicators per timestep, plus per age class and per AG
biomass class aggregates. Reads the existing adapted config; writes only
under the output directory given.

variant: orig   = events as in the 2x2 cell (harvest + natural)
         noharv = harvest events (DIST01 clearcut, DIST05 partial cut) moved to year 9999
         nodist = every event moved to year 9999
"""
import argparse, os, shutil, hashlib, json
import numpy as np, pandas as pd
from libcbm.input.sit import sit_cbm_factory
from libcbm.model.cbm import cbm_simulator

AG = ["SoftwoodMerch","SoftwoodFoliage","SoftwoodOther","HardwoodMerch","HardwoodFoliage","HardwoodOther"]

def topd(x):
    return x.to_pandas() if hasattr(x, "to_pandas") else x

ap = argparse.ArgumentParser()
ap.add_argument("state"); ap.add_argument("variant"); ap.add_argument("outdir")
ap.add_argument("--years", type=int, default=10)
ap.add_argument("--cell", default="FVS_FIAW_NEW")
a = ap.parse_args()
ST, V = a.state, a.variant
SRC = f"/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{ST}/adapted_{a.cell}"
DB = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
work = os.path.join(a.outdir, "work", f"{ST}_{a.cell}_{V}")
if os.path.exists(work): shutil.rmtree(work)
shutil.copytree(SRC, work)
ev = pd.read_csv(os.path.join(work, "disturbance_events.csv"))
n_before = len(ev)
if V == "noharv":
    m = ev["disturbance_type"].isin(["DIST01", "DIST05"])
elif V == "nodist":
    m = pd.Series(True, index=ev.index)
else:
    m = pd.Series(False, index=ev.index)
ev.loc[m, "disturbance_year"] = 9999
ev.to_csv(os.path.join(work, "disturbance_events.csv"), index=False)
yrs = ev.loc[~m & (ev.disturbance_year <= a.years)]
print(f"{ST} {V}: events {n_before}, moved {int(m.sum())}, active in years 1..{a.years}: {len(yrs)}")
print(yrs.groupby("disturbance_type")["target"].agg(["count","sum"]).to_string())
print("db", DB, hashlib.md5(open(DB,"rb").read()).hexdigest())

sit = sit_cbm_factory.load_sit(os.path.join(work, "sit_config.json"), db_path=DB)
classifiers, inventory = sit_cbm_factory.initialize_inventory(sit)
recs, frecs, grp = [], [], []
prev_ag = {}

def rep(t, cbm_vars):
    pools = topd(cbm_vars.pools); inv = topd(cbm_vars.inventory)
    flux = topd(cbm_vars.flux); state = topd(cbm_vars.state)
    area = inv["area"].values
    pn = pools.select_dtypes(include=["number"]).columns
    r = pools[pn].multiply(area, axis=0).sum(axis=0).to_dict()
    r["timestep"] = t; r["total_area_ha"] = float(area.sum()); recs.append(r)
    fn = flux.select_dtypes(include=["number"]).columns
    f = flux[fn].multiply(area, axis=0).sum(axis=0).to_dict()
    f["timestep"] = t; frecs.append(f)
    ag = pools[AG].sum(axis=1).values  # Mg C/ha per stand, end of step
    age = state["age"].values
    if t >= 1:
        agp = prev_ag["v"]
        if len(agp) != len(ag):
            agp = ag  # stand count changed by a split; fall back
        abin = pd.cut(age, [-1,20,40,60,80,100,120,10000], labels=["0-20","21-40","41-60","61-80","81-100","101-120",">120"])
        bmg = agp * 2.0 * 100.0  # Mg C/ha -> g dry m-2, start of step
        bbin = pd.cut(bmg, [-1,5000,10000,15000,20000,25000,30000,1e12], labels=["[0,50)","[50,100)","[100,150)","[150,200)","[200,250)","[250,300)","[300,Inf)"])
        d = pd.DataFrame({"area": area, "dAG": (ag-agp)*area, "AG": ag*area})
        for c in fn:
            d[c] = flux[c].values * area
        for kind, b in (("age", abin), ("biomass", bbin)):
            g = d.groupby(b, observed=False).sum(numeric_only=True)
            g["kind"] = kind; g["bin"] = g.index.astype(str); g["timestep"] = t
            grp.append(g.reset_index(drop=True))
    prev_ag["v"] = ag

with sit_cbm_factory.initialize_cbm(sit) as cbm:
    rb = sit_cbm_factory.create_sit_rule_based_processor(sit, cbm)
    cbm_simulator.simulate(cbm, n_steps=a.years, classifiers=classifiers,
                           inventory=inventory, reporting_func=rep,
                           pre_dynamics_func=rb.pre_dynamics_func)
o = os.path.join(a.outdir, "runs"); os.makedirs(o, exist_ok=True)
pd.DataFrame(recs).to_csv(f"{o}/pools_{ST}_{a.cell}_{V}_{a.years}yr.csv", index=False)
pd.DataFrame(frecs).to_csv(f"{o}/flux_{ST}_{a.cell}_{V}_{a.years}yr.csv", index=False)
pd.concat(grp).to_csv(f"{o}/bins_{ST}_{a.cell}_{V}_{a.years}yr.csv", index=False)
print("flux columns:", list(pd.DataFrame(frecs).columns))
print("done", ST, V)
