"""s46 Track L step 5: FIA AGB curves into cbm_exn under the registered one year spinup input shift.
Inventory = the registered CBM t0 rows (s45 capture). Curves: state file, section ALL, AGB_mean (Mg/ha dry, DRYBIO_AG basis),
ages 0..250, no refit; FT to curve group map = s42 s42fy_build_v1.py FTMAPS; FT999 (nonstocked) has no FIA curve and is excluded,
its area reported. Components (v2 L5, L6): merch(a) = s_m(a) B(a), other(a) = (1 - s_m(a)) B(a), foliage(a) = f(a) B(a), with
s_m and f from NSVB shares by state, FT group and 10 yr age class (nsvb_shares.R), interpolated by PCHIP across class nodes
(flat beyond the end nodes). CF 0.5. Spinup table J = spinup_table(I, 1); stepping supplies I(a+t). 10 undisturbed steps.
usage: python L5_curve_roundtrip.py ST OUTDIR SHARES_CSV"""
import os, sys, json, sqlite3
import numpy as np, pandas as pd
from scipy.interpolate import PchipInterpolator
sys.path.insert(0, os.path.dirname(__file__))
import exn_common as E, trackL_common as TC
from libcbm.input.sit import sit_cbm_factory
from libcbm.model.cbm_exn import cbm_exn_model, cbm_exn_spinup
from libcbm.model.cbm_exn.cbm_exn_parameters import parameters_factory
from libcbm.model.model_definition.model_variables import ModelVariables
from libcbm.model.model_definition.spinup_engine import SpinupState
ST, OUT, SHF = sys.argv[1], sys.argv[2], sys.argv[3]; os.makedirs(OUT, exist_ok=True)
S45 = "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cbm_exn"
DB = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
CAP = os.path.join(S45, "out", "L2", ST); W = os.path.join(CAP, "work_copy")
CUR = {"ME": "/users/PUOM0008/crsfaaron/maine_agb_yc_20261015/zenodo_upload/data/final_curves_capped_DATA.csv"}
for s in ("NH", "VT"): CUR[s] = f"/users/PUOM0008/crsfaaron/nhvt_agb_yc_20261016/out/stress/final_curves_capped_{s}_DATA.csv"
for s in ("MI", "WI", "MN"): CUR[s] = f"/users/PUOM0008/crsfaaron/lakes_agb_yc_20261016/yc_lakes_deliver/curves/final_curves_capped_{s}_DATA.csv"
FTMAPS = dict(  # s42 s42fy_build_v1.py lines 30 to 47
 NH={"FT100": "WRPH", "FT120": "SF", "FT160": "WRPH", "FT400": "OAK", "FT500": "OAK", "FT700": "MBB", "FT800": "MBB", "FT900": "AB"},
 VT={"FT100": "WRPH", "FT120": "SF", "FT380": "SF", "FT400": "OAK", "FT500": "OAK", "FT700": "MBB", "FT800": "MBB", "FT900": "AB"},
 MI={"FT100": "WRPH", "FT120": "SF", "FT200": "SF", "FT260": "SF", "FT380": "WRPH", "FT400": "OAK", "FT500": "OAK", "FT700": "EAC", "FT800": "MBB", "FT900": "AB"},
 WI={"FT100": "WRPH", "FT120": "SF", "FT260": "SF", "FT380": "WRPH", "FT400": "OAK", "FT500": "OAK", "FT700": "EAC", "FT800": "MBB", "FT900": "AB"},
 MN={"FT100": "WRPH", "FT120": "SF", "FT380": "WRPH", "FT400": "OAK", "FT500": "OAK", "FT700": "EAC", "FT800": "MBB", "FT900": "AB"},
 ME={"FT100": "WRPH", "FT120": "SF", "FT160": "WRPH", "FT380": "SF", "FT400": "OAK", "FT500": "OAK", "FT700": "EAC", "FT800": "MBB", "FT900": "AB"})
FTMAP = FTMAPS[ST]; K = 250; NMIN = 10
MNFLAG = {"FT400", "FT500", "FT800"} if ST == "MN" else set()   # MN MBB and OAK curves from the pooled Lake States fit
S = E.spin_settings(ST); spu = S["spatial_unit_id"]
sit = sit_cbm_factory.load_sit(os.path.join(W, "sit_config.json"), db_path=DB); dmap = sit.default_disturbance_id_map
cfg = json.load(open(os.path.join(W, "sit_config.json")))["mapping_config"]
smap = {x["user_species"].replace(" ", ""): x["default_species"] for x in cfg["species"]["species_mapping"]}
con = sqlite3.connect(DB)
spid = {k: con.execute("select species_id from species_tr where name=? and locale_id=1", (v,)).fetchone()[0] for k, v in smap.items()}
con.close()
PX = parameters_factory(E.exn_dir(ST), None); swhw = PX.get_sw_hw_map()
gy = pd.read_csv(os.path.join(W, "growth_and_yield.csv"))
sidk = {}
for r in gy.itertuples(index=False):
    d = r._asdict(); ls = d["leading_species"].replace(" ", "")
    sidk[(d["c1"], d["c2"], d["c3"])] = int(spid[ls] if ls in spid else spid[d["c1"]])
# curves
cv = pd.read_csv(CUR[ST]); cv = cv[cv.section == "ALL"]
Bdry, q99 = {}, {}
for g, d in cv.groupby("ftg"):
    d = d.sort_values("age"); assert (d.age.values == np.arange(0, K + 1)).all(), g
    Bdry[g] = d.AGB_mean.values.astype(float); q99[g] = float(d.age_q99.iloc[0])
    last_sup = int(d[d.extrapolated.astype(str).str.upper() != "TRUE"].age.max()); q99[g] = (q99[g], last_sup)
# NSVB shares
sh = pd.read_csv(SHF); sh = sh[sh.state == ST]
ages = np.arange(0, K + 1)
def share_curve(ft):
    tg = int(ft[2:]); grp = [int(f[2:]) for f, g in FTMAP.items() if g == FTMAP[ft]]
    own = sh[sh.TYPGRPCD == tg].set_index("aclass"); pool = sh[sh.TYPGRPCD.isin(grp)]
    pw = pool.assign(wm=pool.merch_share * pool.mo_total_tons, wf=pool.foliage_over_mo * pool.mo_total_tons, wa=pool.node_age * pool.mo_total_tons).groupby("aclass")
    pool = pd.DataFrame(dict(n_cond=pw.n_cond.sum(), merch_share=pw.wm.sum() / pw.mo_total_tons.sum(), foliage_over_mo=pw.wf.sum() / pw.mo_total_tons.sum(), node_age=pw.wa.sum() / pw.mo_total_tons.sum()))
    nodes = []
    for ac in sorted(set(own.index) | set(pool.index)):
        if ac in own.index and own.loc[ac, "n_cond"] >= NMIN: r = own.loc[ac]; src = "ft"
        elif ac in pool.index and pool.loc[ac, "n_cond"] >= NMIN: r = pool.loc[ac]; src = "group"
        else: continue
        nodes.append(dict(aclass=ac, node_age=float(r.node_age), merch_share=float(r.merch_share), foliage_over_mo=float(r.foliage_over_mo), n_cond=int(r.n_cond), src=src))
    N = pd.DataFrame(nodes).sort_values("node_age")
    if len(N) < 2: raise RuntimeError(f"fewer than 2 share nodes for {ft}")
    x = N.node_age.values; xa = np.clip(ages, x.min(), x.max())
    sm = PchipInterpolator(x, N.merch_share.values)(xa); fo = PchipInterpolator(x, N.foliage_over_mo.values)(xa)
    return np.clip(sm, 0, 1), np.maximum(fo, 0), N.assign(ft=ft)
comp, nodes_all, compchk, negs = {}, [], [], []
for ft, g in FTMAP.items():
    sm, fo, N = share_curve(ft); nodes_all.append(N)
    B = Bdry[g]
    M, O, F = sm * B, (1 - sm) * B, fo * B
    C = np.column_stack([M, F, O]) * E.CF             # (merch, foliage, other), ages 0..250, Mg C/ha
    I = np.diff(C, axis=0)                              # I(1..K)
    dB = np.diff(B) * E.CF
    rel = np.abs(I[:, 0] + I[:, 2] - dB) / np.maximum(np.abs(dB), 1e-300)
    compchk.append(dict(state=ST, ft=ft, group=g, max_rel_sum_err=float(rel[np.abs(dB) > 0].max()), n_ages=K, sum_ok=bool((rel[np.abs(dB) > 0] <= 1e-3).all())))
    decline = dB < 0
    for j, nm in ((0, "merch"), (2, "other"), (1, "foliage")):
        neg = I[:, j] < 0
        negs.append(dict(state=ST, ft=ft, group=g, component=nm, n_neg_outside_decline=int((neg & ~decline).sum()), n_neg_in_decline=int((neg & decline).sum()),
                         n_neg_outside_decline_age1_20=int((neg & ~decline)[:20].sum()), ages_neg_outside=";".join(str(a + 1) for a in np.where(neg & ~decline)[0][:12]),
                         min_neg_inc_outside=float(I[neg & ~decline, j].min()) if (neg & ~decline).any() else 0.0))
    comp[ft] = dict(C=C, I=I, sm=sm, fo=fo, g=g)
pd.DataFrame(compchk).to_csv(os.path.join(OUT, f"component_sum_{ST}.csv"), index=False)
pd.DataFrame(negs).to_csv(os.path.join(OUT, f"negative_increments_{ST}.csv"), index=False)
pd.concat(nodes_all).to_csv(os.path.join(OUT, f"share_nodes_{ST}.csv"), index=False)
pd.DataFrame({ft: comp[ft]["sm"] for ft in comp}, index=ages).to_csv(os.path.join(OUT, f"merch_share_curve_{ST}.csv"))
# inventory
snap = pd.read_csv(os.path.join(CAP, f"cap_snapshots_{ST}.csv")); s0 = snap[snap.t == 0].sort_values("row").reset_index(drop=True)
excl = s0[~s0.ForestType.isin(list(FTMAP))]
pd.DataFrame([dict(state=ST, excluded_types=";".join(sorted(excl.ForestType.unique())), excluded_area=float(excl.area.sum()), total_area=float(s0.area.sum()))]).to_csv(os.path.join(OUT, f"excluded_{ST}.csv"), index=False)
s0 = s0[s0.ForestType.isin(list(FTMAP))].reset_index(drop=True)
keys = list(zip(s0.ForestType, s0.Ecoregion, s0.Owner)); n = len(s0)
par = pd.DataFrame({"age": s0.inv_age.astype(int).values, "area": s0.area.values, "delay": s0.inv_delay.astype(int).values,
                    "return_interval": S["return_interval"], "min_rotations": S["min_rotations"], "max_rotations": S["max_rotations"],
                    "spatial_unit_id": s0.inv_spatial_unit.astype(int).values, "species": [sidk[k] for k in keys], "sw_hw": [swhw[sidk[k]] for k in keys],
                    "mean_annual_temperature": S["historic_mean_temperature"],
                    "historical_disturbance_type": [dmap[int(x)] for x in s0.inv_historical_disturbance_type],
                    "last_pass_disturbance_type": [dmap[int(x)] for x in s0.inv_last_pass_disturbance_type]})
assert (par.spatial_unit_id == spu).all() and (par.delay == 0).all()
incs = pd.concat([pd.DataFrame({"row_idx": i, "age": np.arange(1, K + 1), **dict(zip(["merch_inc", "foliage_inc", "other_inc"], TC.spinup_table(comp[k[0]]["I"], 1).T))})
                  for i, k in enumerate(keys)], ignore_index=True)
sup = np.array([q99[comp[k[0]]["g"]][1] for k in keys])
yrs = np.zeros(n); beyond = np.zeros(n); beyondK = np.zeros(n)
GROW = (SpinupState.AnnualProcesses.value, SpinupState.GrowToFinalAge.value)
def rep(t, sv):
    stt = sv["state"]["spinup_state"].to_numpy(); ag = sv["state"]["age"].to_numpy()
    gr = np.isin(stt, GROW); bage = ag + 1                 # biomass age after a growth step = post-step state age + 1 (registered J)
    yrs[gr] += 1; beyond[gr & (bage > sup)] += 1; beyondK[gr & (bage > K)] += 1
def target(k, a):
    a = np.minimum(a, K); return comp[k[0]]["C"][a]
with cbm_exn_model.initialize(config_path=E.exn_dir(ST)) as m:
    sv = cbm_exn_spinup.prepare_spinup_vars(ModelVariables.from_pandas({"parameters": par, "increments": incs}), m.parameters, False)
    v = cbm_exn_spinup.spinup(m, sv, reporting_func=rep).to_pandas()
    for kk in list(v.keys()): v[kk] = v[kk].reset_index(drop=True)
    res = []
    def check(t, v):
        P = v["pools"][["Merch", "Foliage", "Other"]].values; a = s0.inv_age.astype(int).values + t
        Tg = np.array([target(k, aa) for k, aa in zip(keys, a)])
        mo, tmo = P[:, 0] + P[:, 2], Tg[:, 0] + Tg[:, 2]
        res.append(pd.DataFrame(dict(t=t, ft=[k[0] for k in keys], eco=[k[1] for k in keys], own=[k[2] for k in keys], inv_age=s0.inv_age.astype(int).values,
                                     area=s0.area.values, cbm_mo_C=mo, curve_mo_C=tmo, rel_err_mo=(mo - tmo) / np.where(tmo > 0, tmo, np.nan),
                                     cbm_fol_C=P[:, 1], comp_fol_C=Tg[:, 1], rel_err_fol=(P[:, 1] - Tg[:, 1]) / np.where(Tg[:, 1] > 0, Tg[:, 1], np.nan),
                                     merch_C=P[:, 0], comp_merch_C=Tg[:, 0], neg_pool=(P < 0).any(axis=1))))
    check(0, v)
    v["parameters"]["mean_annual_temperature"] = S["mean_annual_temperature"]
    for t in range(1, 11):
        a = s0.inv_age.astype(int).values + t - 1
        Is = np.array([comp[k[0]]["I"][aa] if aa + 1 <= K else np.zeros(3) for k, aa in zip(keys, a)])   # I(a+1): row index a
        v = E.step(m, v, Is[:, 0], Is[:, 1], Is[:, 2], np.zeros(n, dtype=int)); check(t, v)
R = pd.concat(res, ignore_index=True)
R.to_csv(os.path.join(OUT, f"roundtrip_rows_{ST}.csv"), index=False)
pd.DataFrame(dict(state=ST, ft=[k[0] for k in keys], group=[comp[k[0]]["g"] for k in keys], inv_age=par.age, area=par.area, max_supported_age=sup,
                  spinup_growth_years=yrs, years_beyond_support=beyond, years_beyond_K=beyondK)).to_csv(os.path.join(OUT, f"spinup_extrap_{ST}.csv"), index=False)
r0 = R[(R.t == 0) & (R.inv_age >= 2)]
print("RT", ST, "t0 rows ages>=2", len(r0), "max |rel| mo", float(r0.rel_err_mo.abs().max()), "fail(>2%)", int((r0.rel_err_mo.abs() > 0.02).sum()),
      "age1 rows", int((R[R.t == 0].inv_age == 1).sum()), "| steps 1-10 ages>=2 max |rel|", float(R[(R.t > 0) & (R.inv_age >= 2)].rel_err_mo.abs().max()),
      "| comp sum ok", all(c["sum_ok"] for c in compchk), "| neg pools", int(R.neg_pool.sum()))
