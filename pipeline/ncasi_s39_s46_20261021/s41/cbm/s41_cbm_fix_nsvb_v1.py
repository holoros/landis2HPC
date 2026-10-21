"""s41 POST HOC DIAGNOSTIC (not a gate pass). Fix F2: replace the Boudewyn
volume to biomass factor rows used by the FVS_FIAW_NEW cell with an NSVB
calibrated chain per forest type group, built from FIA DataMart 2024
(s41_fia_nsvb_calibration_20261015.csv, design based ratios of totals):
  eq1  b_m  = a * V,  a = DRYBIO_BOLE / VOLCFNET (trees >= 5 in), b = 1
  eq2  nonmerch factor constant = DRYBIO_STEM / DRYBIO_BOLE (trees >= 5 in)
  eq3  sapling factor constant  = DRYBIO_STEM all trees / trees >= 5 in
  eq4-7 constant proportions of stemwood, bark, branches, foliage from NSVB totals
Each forest type group gets its own factor row through a distinct species of
the SAME softwood/hardwood class as the original mapping (so turnover, root
and spinup parameters are unchanged); groups with < 30 conditions use the
state pooled row. Works on COPIES of the adapted config and the state AIDB.
Then runs 10 years with all flux indicators, harvest types removed by name
(the s40 noharv arm), writing runs/pools_, flux_, bins_ files in the s40 layout
so the unmodified s40 scorer cbm_gate_score_v4 can score them.
usage: python s41_cbm_fix_nsvb_v1.py ST OUTDIR [--years 10]"""
import argparse, os, shutil, json, sqlite3, hashlib, math
import numpy as np, pandas as pd
from libcbm.input.sit import sit_cbm_factory
from libcbm.model.cbm import cbm_simulator
AG = ["SoftwoodMerch","SoftwoodFoliage","SoftwoodOther","HardwoodMerch","HardwoodFoliage","HardwoodOther"]
ap = argparse.ArgumentParser(); ap.add_argument("state"); ap.add_argument("outdir"); ap.add_argument("--years", type=int, default=10)
ap.add_argument("--cal", default="s41_fia_nsvb_calibration_20261015.csv"); ap.add_argument("--min_cond", type=int, default=30)
a = ap.parse_args(); ST = a.state; V = "noharv"
def topd(x): return x.to_pandas() if hasattr(x, "to_pandas") else x
SRC = f"/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{ST}/adapted_FVS_FIAW_NEW"
DB0 = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
work = os.path.join(a.outdir, "work", f"{ST}_FVS_FIAW_NEW_fixF2")
if os.path.exists(work): shutil.rmtree(work)
shutil.copytree(SRC, work)
DB = os.path.join(work, f"cbm_defaults_{ST}_fixF2.db"); shutil.copy(DB0, DB)
print("db source", DB0, hashlib.md5(open(DB0, "rb").read()).hexdigest())
cfgp = os.path.join(work, "sit_config.json"); cfg = json.load(open(cfgp)); m = cfg["mapping_config"]
cal = pd.read_csv(a.cal); cal = cal[cal.state == ST].set_index("TYPGRPCD")
con = sqlite3.connect(DB)
suid = con.execute("""select su.id from spatial_unit su join admin_boundary_tr a on a.admin_boundary_id=su.admin_boundary_id and a.locale_id=1
   join eco_boundary_tr e on e.eco_boundary_id=su.eco_boundary_id and e.locale_id=1 where a.name=? and e.name=?""",
   (m["spatial_units"]["admin_boundary"], m["spatial_units"]["eco_boundary"])).fetchone()[0]
sp = pd.read_sql("select s.id, t.name, s.forest_type_id from species s join species_tr t on t.species_id=s.id and t.locale_id=1", con)
name2id = dict(zip(sp.name, sp.id)); id2ft = dict(zip(sp.id, sp.forest_type_id))
used_ids = {name2id[x["default_species"]] for x in m["species"]["species_mapping"]}
taken = set(); tmpl = pd.read_sql("select * from vol_to_bio_factor limit 1", con).iloc[0].to_dict()
nid = con.execute("select max(id) from vol_to_bio_factor").fetchone()[0] + 1
log = []
for x in m["species"]["species_mapping"]:
    grp = int(x["user_species"].split()[1]); orig = x["default_species"]; oid = name2id[orig]; ftid = id2ft[oid]
    if grp in cal.index and cal.loc[grp, "n_cond"] >= a.min_cond: r = cal.loc[grp]; src = f"group {grp}"
    else: r = cal.loc[-1]; src = "state pooled"
    if oid not in taken: sid = oid
    else:
        cand = sp[(sp.forest_type_id == ftid) & (~sp.id.isin(used_ids | taken))].sort_values("id")
        sid = int(cand.id.iloc[0])
    taken.add(sid); new = sp[sp.id == sid].name.iloc[0]
    f = dict(tmpl); f["id"] = nid
    f.update(a=float(r.a_merch_wood_per_m3), b=1.0, k_nonmerch=float(r.k_nonmerch), a_nonmerch=0.0, b_nonmerch=1.0, cap_nonmerch=float(r.k_nonmerch),
             k_sap=float(r.k_sap), a_sap=0.0, b_sap=1.0, cap_sap=float(r.k_sap),
             a1=math.log(r.p_bark / r.p_stemwood), a2=0.0, a3=0.0, b1=math.log(r.p_branch / r.p_stemwood), b2=0.0, b3=0.0,
             c1=math.log(r.p_foliage / r.p_stemwood), c2=0.0, c3=0.0, min_volume=0.0, max_volume=1e9,
             low_stemwood_prop=float(r.p_stemwood), high_stemwood_prop=float(r.p_stemwood), low_stembark_prop=float(r.p_bark), high_stembark_prop=float(r.p_bark),
             low_branches_prop=float(r.p_branch), high_branches_prop=float(r.p_branch), low_foliage_prop=float(r.p_foliage), high_foliage_prop=float(r.p_foliage))
    cols = list(f.keys())
    con.execute(f"insert into vol_to_bio_factor ({','.join(cols)}) values ({','.join('?'*len(cols))})", [f[c] for c in cols])
    con.execute("delete from vol_to_bio_species where spatial_unit_id=? and species_id=?", (suid, sid))
    con.execute("insert into vol_to_bio_species (spatial_unit_id, species_id, vol_to_bio_factor_id) values (?,?,?)", (suid, sid, nid))
    log.append(dict(state=ST, ft=x["user_species"], calib=src, orig_species=orig, run_species=new, sw_hw=ftid, factor_id=nid,
                    a=f["a"], k_nonmerch=f["k_nonmerch"], k_sap=f["k_sap"], p_stemwood=f["low_stemwood_prop"], p_bark=f["low_stembark_prop"],
                    p_branch=f["low_branches_prop"], p_foliage=f["low_foliage_prop"]))
    x["default_species"] = new; nid += 1
con.commit(); con.close()
json.dump(cfg, open(cfgp, "w"), indent=1)
L = pd.DataFrame(log); print(L.round(4).to_string())
os.makedirs(os.path.join(a.outdir, "runs"), exist_ok=True)
L.to_csv(os.path.join(a.outdir, "runs", f"fixF2_factors_{ST}.csv"), index=False)
# noharv arm exactly as s40 cbm_gate_run_v2: harvest types removed by name
ev = pd.read_csv(os.path.join(work, "disturbance_events.csv"))
dt = pd.read_csv(os.path.join(work, "disturbance_types.csv"))
hv = dt[dt["name"].str.contains(r"clear ?cut|partial cut|harvest|thinning|selection cut|shelterwood", case=False, regex=True)]
hid = sorted(hv["id"].tolist()); print(f"ASSERT {ST} harvest types by name: " + "; ".join(f"{i}={n}" for i, n in zip(hv["id"], hv["name"])))
mm = ev["disturbance_type"].isin(hid); ev.loc[mm, "disturbance_year"] = 9999
ev.to_csv(os.path.join(work, "disturbance_events.csv"), index=False)
print(f"ASSERT {ST} removed IDs {hid}: {int(mm.sum())} event rows moved to year 9999")
sit = sit_cbm_factory.load_sit(cfgp, db_path=DB)
classifiers, inventory = sit_cbm_factory.initialize_inventory(sit)
recs, frecs, grp = [], [], []; prev = {}
def rep(t, v):
    pools = topd(v.pools); inv = topd(v.inventory); flux = topd(v.flux); state = topd(v.state)
    area = inv["area"].values
    pn = pools.select_dtypes(include=["number"]).columns
    r = pools[pn].multiply(area, axis=0).sum(axis=0).to_dict(); r["timestep"] = t; r["total_area_ha"] = float(area.sum()); recs.append(r)
    fn = flux.select_dtypes(include=["number"]).columns
    f = flux[fn].multiply(area, axis=0).sum(axis=0).to_dict(); f["timestep"] = t; frecs.append(f)
    ag = pools[AG].sum(axis=1).values; age = state["age"].values
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
    cbm_simulator.simulate(cbm, n_steps=a.years, classifiers=classifiers, inventory=inventory, reporting_func=rep, pre_dynamics_func=rb.pre_dynamics_func)
o = os.path.join(a.outdir, "runs")
pd.DataFrame(recs).to_csv(f"{o}/pools_{ST}_FVS_FIAW_NEW_{V}_{a.years}yr.csv", index=False)
pd.DataFrame(frecs).to_csv(f"{o}/flux_{ST}_FVS_FIAW_NEW_{V}_{a.years}yr.csv", index=False)
pd.concat(grp).to_csv(f"{o}/bins_{ST}_FVS_FIAW_NEW_{V}_{a.years}yr.csv", index=False)
print("done", ST)
