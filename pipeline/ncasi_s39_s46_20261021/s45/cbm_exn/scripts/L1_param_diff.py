"""s45 Track L step L1: dump CBM3 path parameters (libcbm cbm_defaults loader, as the
registered SIT run receives them) and cbm_exn path parameters (libcbm cbm_exn
parameter_extraction from the same state db), and diff them by spatial unit and
species (sw_hw). Any difference on the spatial unit and disturbance types the
registered run uses is a stop (plan v2 L1).
usage: python L1_param_diff.py ST OUTDIR"""
import sys, os, json, sqlite3, hashlib
import numpy as np, pandas as pd
from libcbm.model.cbm import cbm_defaults
from libcbm.model.cbm_exn.parameters import parameter_extraction
from libcbm.model.cbm_exn.cbm_exn_parameters import parameters_factory

ST, OUT = sys.argv[1], sys.argv[2]
DB = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
SRC = f"/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{ST}/adapted_FVS_FIAW_NEW"
os.makedirs(OUT, exist_ok=True)
print("db md5", hashlib.md5(open(DB, "rb").read()).hexdigest())
EXN = os.path.join(OUT, "exn_params")
os.makedirs(EXN, exist_ok=True)
parameter_extraction.extract(DB, EXN, "en-CA")
P3 = cbm_defaults.load_cbm_parameters(DB)
for k, v in P3.items():
    if isinstance(v, pd.DataFrame):
        v.to_csv(os.path.join(OUT, f"cbm3_{k}.csv"), index=False)
cfg = json.load(open(os.path.join(SRC, "sit_config.json")))["mapping_config"]
con = sqlite3.connect(DB)
suid = con.execute("""select su.id from spatial_unit su join admin_boundary_tr a on a.admin_boundary_id=su.admin_boundary_id and a.locale_id=1
   join eco_boundary_tr e on e.eco_boundary_id=su.eco_boundary_id and e.locale_id=1 where a.name=? and e.name=?""",
   (cfg["spatial_units"]["admin_boundary"], cfg["spatial_units"]["eco_boundary"])).fetchone()[0]
dtn = [x["default_dist_type"] for x in cfg["disturbance_types"]]
dtid = {n: con.execute("select disturbance_type_id from disturbance_type_tr where name=? and locale_id=1", (n,)).fetchone()[0] for n in dtn}
pool = pd.read_sql("select id, code from pool", con).set_index("id").code.to_dict()
con.close()
print("spatial unit", suid, "disturbance types", dtid)
rows = []
def rec(kind, key, cbm3, exn):
    d = np.nan if (cbm3 is None or exn is None) else abs(float(cbm3) - float(exn))
    rows.append(dict(kind=kind, key=key, cbm3=cbm3, cbm_exn=exn, abs_diff=d,
                     match=bool(d == 0.0) if not np.isnan(d) else False))

# turnover by spatial unit and sw_hw
t3 = P3["turnover_parameters"]
con = sqlite3.connect(DB); eb = con.execute("select eco_boundary_id from spatial_unit where id=?", (suid,)).fetchone()[0]; con.close()
r3 = t3[t3.EcoBoundaryId == eb].iloc[0]
tx = pd.read_csv(os.path.join(EXN, "turnover_parameters.csv"))
for sh, pre in (("sw", "Softwood"), ("hw", "Hardwood")):
    rx = tx[(tx.spatial_unit_id == suid) & (tx.sw_hw == sh)].iloc[0]
    m = {"FoliageFallRate": f"{pre}FoliageFallRate", "StemAnnualTurnoverRate": "StemAnnualTurnoverRate",
         "BranchTurnoverRate": f"{pre}BranchTurnoverRate", "CoarseRootTurnProp": "CoarseRootTurnProp",
         "FineRootTurnProp": "FineRootTurnProp", "OtherToBranchSnagSplit": "OtherToBranchSnagSplit",
         "CoarseRootAGSplit": "CoarseRootAGSplit", "FineRootAGSplit": "FineRootAGSplit",
         "StemSnag": f"{pre}StemSnagTurnoverRate", "BranchSnag": f"{pre}BranchSnagTurnoverRate"}
    for kx, k3 in m.items():
        rec("turnover", f"spu{suid}|{sh}|{kx}", r3[k3], rx[kx])

# decay: cbm_exn has one rate per DOM pool name; CBM3 has SW and HW snag pools
d3 = P3["decay_parameters"].copy(); d3["pool"] = d3.Pool.map(pool)
dx = pd.read_csv(os.path.join(EXN, "decay_parameters.csv"))
dmap = {"OrganicMatterDecayRate": "base_decay_rate", "ReferenceTemp": "reference_temp", "Q10": "q10",
        "PropToAtmosphere": "prop_to_atmosphere", "MaxDecayRate": "max_rate"}
for _, r in d3.iterrows():
    nm = r["pool"].replace("Softwood", "").replace("Hardwood", "")
    sel = dx[dx["pool"] == nm]
    for k3, kx in dmap.items():
        if len(sel) != 1:
            rec("decay", f"{r['pool']}|{k3}|exn_rows={len(sel)}", r[k3], None)
        else:
            rec("decay", f"{r['pool']}|{k3}", r[k3], sel.iloc[0][kx])

# disturbance matrices for the spatial unit and the types used, per sw_hw
a3 = P3["disturbance_matrix_associations"]; v3 = P3["disturbance_matrix_values"]
ax = pd.read_csv(os.path.join(EXN, "disturbance_matrix_association.csv"))
vx = pd.read_csv(os.path.join(EXN, "disturbance_matrix_value.csv"))
SWP = {"SoftwoodMerch", "SoftwoodFoliage", "SoftwoodOther", "SoftwoodCoarseRoots", "SoftwoodFineRoots", "SoftwoodStemSnag", "SoftwoodBranchSnag"}
HWP = {p.replace("Softwood", "Hardwood") for p in SWP}
for n, i in dtid.items():
    m3 = a3[(a3.spatial_unit_id == suid) & (a3.disturbance_type_id == i)]
    if len(m3) != 1:
        rec("dm", f"{n}|cbm3_assoc_rows={len(m3)}", None, None); continue
    mv = v3[v3.disturbance_matrix_id == m3.disturbance_matrix_id.iloc[0]].copy()
    mv["src"] = mv.source_pool_id.map(pool); mv["snk"] = mv.sink_pool_id.map(pool)
    for sh, own, other in (("sw", SWP, HWP), ("hw", HWP, SWP)):
        sub = mv[~mv.src.isin(other) & ~mv.snk.isin(other)].copy()
        sub["s"] = sub.src.str.replace("Softwood", "").str.replace("Hardwood", "")
        sub["k"] = sub.snk.str.replace("Softwood", "").str.replace("Hardwood", "")
        mx = ax[(ax.spatial_unit_id == suid) & (ax.disturbance_type_id == i) & (ax.sw_hw == sh)]
        if len(mx) != 1:
            rec("dm", f"{n}|{sh}|exn_assoc_rows={len(mx)}", None, None); continue
        xv = vx[vx.disturbance_matrix_id == mx.disturbance_matrix_id.iloc[0]]
        A = sub.groupby(["s", "k"]).proportion.sum(); X = xv.groupby(["source_pool", "sink_pool"]).proportion.sum()
        X.index.names = ["s", "k"]
        J = pd.concat([A.rename("a"), X.rename("x")], axis=1)
        for (s, k), r in J.iterrows():
            rec("dm", f"{n}|{sh}|{s}->{k}", 0.0 if np.isnan(r.a) else r.a, 0.0 if np.isnan(r.x) else r.x)

# root parameters, slow mixing
r3 = P3["root_parameter"].iloc[0]; rx = pd.read_csv(os.path.join(EXN, "root_parameters.csv")).iloc[0]
for k in ["hw_a", "hw_b", "sw_a", "frp_a", "frp_b", "frp_c"]:
    rec("root", k, r3[k], rx[k])
rec("slow_mixing", "rate", P3["slow_mixing_rate"].iloc[0, -1], pd.read_csv(os.path.join(EXN, "slow_mixing_rate.csv")).iloc[0, -1])

# species to sw_hw for the species the registered config maps
con = sqlite3.connect(DB)
sp = pd.read_sql("""select s.id, t.name, f.id as ft from species s join species_tr t on t.species_id=s.id and t.locale_id=1
     join forest_type f on f.id=s.forest_type_id""", con)
con.close()
PX = parameters_factory(EXN, None)
swhw = PX.get_sw_hw_map()
for us in cfg["species"]["species_mapping"]:
    r = sp[sp.name == us["default_species"]].iloc[0]
    rec("species_sw_hw", f"{us['user_species']}={us['default_species']}", 0 if r.ft == 1 else 1, swhw[int(r.id)])

# spinup parameters (cbm_exn takes them per stand; dumped here from the CBM3 tables to be passed unchanged)
s3 = P3["spinup_parameter"]; s3 = s3[s3.spatial_unit_id == suid]
mt = P3["mean_annual_temp"]; mt = mt[mt.spatial_unit_id == suid]
spin = dict(spatial_unit_id=int(suid), return_interval=int(s3.return_interval.iloc[0]), min_rotations=int(s3.min_rotations.iloc[0]),
            max_rotations=int(s3.max_rotations.iloc[0]), historic_mean_temperature=float(s3.historic_mean_temperature.iloc[0]),
            mean_annual_temperature=float(mt.mean_annual_temperature.iloc[0]), dist_type_ids=dtid)
json.dump(spin, open(os.path.join(OUT, "spinup_settings.json"), "w"), indent=1)
R = pd.DataFrame(rows); R["state"] = ST
R.to_csv(os.path.join(OUT, f"L1_param_diff_{ST}.csv"), index=False)
print(R.groupby("kind").match.agg(["sum", "count"]).to_string())
bad = R[~R.match]
print("NON MATCHING ROWS", len(bad)); print(bad.to_string())
print("spinup", spin)
