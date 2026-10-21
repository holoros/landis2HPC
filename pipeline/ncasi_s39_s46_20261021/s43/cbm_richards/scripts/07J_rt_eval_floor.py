"""s43 Track J: round trip evaluation at every occupied age (as 06_roundtrip_eval.R, md5 8c79690e...) with the occupancy and
area taken by forest type classifier (ft) from the pseudo-age inventory, plus the minimum merchantable volume floor test.
Floor test (diagnostic only; the libcbm chain is not changed): for the pass 0 volumes Vn of each ft, compute libcbm's own
volume-to-biomass conversion (VolumeToBiomassWrapper) with the CBM3 smoother on (as the chain runs) and off, and the ft's
Boudewyn factor min_volume. A young (age 1-20) occupied cell fails if |ratio-1| > 0.02. For each failing cell record whether
(i) Vn(age) < min_volume, (ii) the smoother is active (|on/off-1| > 0.02), (iii) the chain woody equals the smoother-on
conversion within 2 percent. Explanation rule (set here, not pre-registered): the floor explains the young failures if
(i) or (ii) holds for >= 90 percent of the area-weighted young failing cells.
usage: python 07J_rt_eval_floor.py OUTROOT S43ROOT"""
import os, sys, json, sqlite3, hashlib
import numpy as np, pandas as pd
from libcbm.wrapper.volume_to_biomass.volume_to_biomass_wrapper import VolumeToBiomassWrapper, MerchVolumeCurve

OR, S43 = sys.argv[1], sys.argv[2]
STS = ["ME", "NH", "VT", "MI", "WI", "MN"]
VARS = {"p90": (f"{OR}/rt_p90", f"{OR}/pseudo_p90"), "p95": (f"{OR}/rt_p95", f"{OR}/pseudo_p95"),
        "p99": (f"{OR}/rt_p99", f"{OR}/pseudo_p99"), "s43free": (f"{S43}/out/rt", f"{OR}/pseudo_s43free")}
WOODY = ["SWMerch", "SWOther", "HWMerch", "HWOther"]
v2b = VolumeToBiomassWrapper()

def md5(p): return hashlib.md5(open(p, "rb").read()).hexdigest()

def boud(V, f):  # copied from s43nd_build_v1.py (python chain)
    V = np.atleast_1d(np.asarray(V, float)); pos = V > 0; Vp = np.where(pos, V, 1.0)
    bm = f["a"] * Vp ** f["b"]
    bnm = np.minimum(f["k_nonmerch"] + f["a_nonmerch"] * bm ** f["b_nonmerch"], f["cap_nonmerch"]) * bm
    bsnm = np.minimum(f["k_sap"] + f["a_sap"] * bnm ** f["b_sap"], f["cap_sap"]) * bnm
    L = np.log(Vp + 5)
    ea = np.exp(f["a1"] + f["a2"] * Vp + f["a3"] * L); eb = np.exp(f["b1"] + f["b2"] * Vp + f["b3"] * L); ec = np.exp(f["c1"] + f["c2"] * Vp + f["c3"] * L)
    psw = 1 / (1 + ea + eb + ec); pbk = ea * psw; pbr = eb * psw
    lo = Vp < f["min_volume"]; hi = Vp > f["max_volume"]
    for arr, lk, hk in ((psw, "low_stemwood_prop", "high_stemwood_prop"), (pbk, "low_stembark_prop", "high_stembark_prop"), (pbr, "low_branches_prop", "high_branches_prop")):
        arr[lo] = f[lk]; arr[hi] = f[hk]
    tot = bsnm / psw
    return np.where(pos, bsnm + tot * pbk + tot * pbr, 0.0)

def factor(con, suid, sp):
    sid, gid, ftid = con.execute("select s.id, s.genus_id, s.forest_type_id from species s join species_tr t on t.species_id=s.id and t.locale_id=1 where t.name=?", (sp,)).fetchone()
    for q, k in (("select vol_to_bio_factor_id from vol_to_bio_species where spatial_unit_id=? and species_id=?", sid),
                 ("select vol_to_bio_factor_id from vol_to_bio_genus where spatial_unit_id=? and genus_id=?", gid),
                 ("select vol_to_bio_factor_id from vol_to_bio_forest_type where spatial_unit_id=? and forest_type_id=?", ftid)):
        r = con.execute(q, (suid, k)).fetchone()
        if r:
            f = pd.read_sql(f"select * from vol_to_bio_factor where id={r[0]}", con).iloc[0].to_dict(); f["sid"] = sid
            return f
    raise KeyError(sp)

CELLS = []
for V, (RT, PS) in VARS.items():
    AF = pd.read_csv(f"{PS}/tb_pseudoage_age_area_by_ft_DATA.csv")
    for ST in STS:
        f = f"{RT}/{ST}/s43nd_{ST}_roundtrip_all_passes_20261019.csv"; print("md5", V, ST, md5(f), flush=True)
        R = pd.read_csv(f); R = R[R["pass"] == 0].copy()
        cfgdir = f"{RT}/{ST}/adapted_NETDRV"
        cfg = json.load(open(f"{cfgdir}/sit_config.json"))["mapping_config"]
        smap = {x["user_species"].replace(" ", ""): x["default_species"] for x in cfg["species"]["species_mapping"]}
        DB = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
        con = sqlite3.connect(DB)
        suid = con.execute("""select su.id from spatial_unit su join admin_boundary_tr a on a.admin_boundary_id=su.admin_boundary_id and a.locale_id=1
           join eco_boundary_tr e on e.eco_boundary_id=su.eco_boundary_id and e.locale_id=1 where a.name=? and e.name=?""",
           (cfg["spatial_units"]["admin_boundary"], cfg["spatial_units"]["eco_boundary"])).fetchone()[0]
        gy = pd.read_csv(f"{cfgdir}/growth_and_yield.csv")
        for ft in sorted(R.ft.unique()):
            fa = factor(con, suid, smap[ft])
            row = gy[gy.c1 == ft].iloc[0]; vol = np.array([float(row[f"v{a}"]) for a in range(0, 201)])
            ages = np.arange(1, 201, dtype=np.int32)
            on = v2b.volume_to_biomass(suid, [MerchVolumeCurve(int(fa["sid"]), ages, vol[1:].astype(np.float64))], use_smoother=True, db_path=DB)
            off = v2b.volume_to_biomass(suid, [MerchVolumeCurve(int(fa["sid"]), ages, vol[1:].astype(np.float64))], use_smoother=False, db_path=DB)
            d = R[R.ft == ft].set_index("age").reindex(range(1, 201))
            CELLS.append(pd.DataFrame(dict(variant=V, st=ST, ft=ft, group=d.group.values, age=np.arange(1, 201), vol=vol[1:], min_volume=fa["min_volume"],
                v2b_on=on[WOODY].sum(axis=1).values, v2b_off=off[WOODY].sum(axis=1).values, py_boud=boud(vol[1:], fa),
                cbm_woody=d.cbm_woody.values, target=d.target.values, ratio=d.ratio.values)))
        con.close()
C = pd.concat(CELLS, ignore_index=True)
C["v2b_age_check"] = True
# units: libcbm pools are C; calibrate v2b (smoother off) against the python chain at ages 20-150
w = C[(C.age >= 20) & (C.age <= 150) & (C.py_boud > 0)]
cfac = float(np.median(w.v2b_off / w.py_boud)); print("v2b_off / python chain median (expect 0.5 if tC):", round(cfac, 5))
C["v2b_on_B"] = C.v2b_on / cfac; C["v2b_off_B"] = C.v2b_off / cfac
C["err"] = (C.ratio - 1).abs()
AA = []
for V, (RT, PS) in VARS.items():
    AF = pd.read_csv(f"{PS}/tb_pseudoage_age_area_by_ft_DATA.csv"); AF["variant"] = V; AA.append(AF)
AA = pd.concat(AA)
area = AA[AA.age_int <= 200].groupby(["variant", "st", "ft", "age_int"]).area_ha.sum().rename("area_ha").reset_index().rename(columns={"age_int": "age"})
C = C.merge(area, on=["variant", "st", "ft", "age"], how="left"); C["area_ha"] = C.area_ha.fillna(0.0)
C["fail"] = C.err > 0.02; C["occ"] = C.area_ha > 0; C["young"] = C.age <= 20
C["below_minvol"] = C.vol < C.min_volume
C["smoother_active"] = (C.v2b_on_B / C.v2b_off_B.where(C.v2b_off_B > 0) - 1).abs() > 0.02
C["chain_eq_v2b_on"] = (C.cbm_woody / C.v2b_on_B.where(C.v2b_on_B > 0) - 1).abs() <= 0.02
C["floor_explains_cell"] = C.below_minvol | C.smoother_active
C.drop(columns=["v2b_age_check"]).to_csv(f"{OR}/tbJ_roundtrip_cells_DATA.csv", index=False)

# per stratum, every occupied age (as 06)
S = C.groupby(["variant", "st", "ft", "group"]).apply(lambda g: pd.Series(dict(
    max_err_pct_1_200=100 * g.err.max(), max_err_pct_occupied=100 * g.err[g.occ].max() if g.occ.any() else np.nan,
    n_occ_ages_fail=int((g.fail & g.occ).sum()), n_ages_fail=int(g.fail.sum()),
    pass_occupied_2pct=int((g.fail & g.occ).sum()) == 0)), include_groups=False).reset_index()
S.to_csv(f"{OR}/tbJ_roundtrip_by_stratum_DATA.csv", index=False)
# young failure share weighted by inventory area, and floor test
AREA_ALL = AA.groupby(["variant", "st"]).area_ha.sum().rename("area_total").reset_index()
AREA_GT200 = AA[AA.age_int > 200].groupby(["variant", "st"]).area_ha.sum().rename("area_age_gt200").reset_index()
def ysum(g):
    y = g[g.young & g.occ]; f = y[y.fail]
    return pd.Series(dict(area_young=y.area_ha.sum(), area_young_fail=f.area_ha.sum(),
        young_fail_share_area=f.area_ha.sum() / y.area_ha.sum() if y.area_ha.sum() > 0 else np.nan,
        n_young_occ_cells=len(y), n_young_fail_cells=len(f),
        area_occ_all=g[g.occ].area_ha.sum(), area_fail_all=g[g.occ & g.fail].area_ha.sum(),
        fail_share_area_all_ages=g[g.occ & g.fail].area_ha.sum() / g[g.occ].area_ha.sum(),
        floor_minvol_share=f[f.below_minvol].area_ha.sum() / f.area_ha.sum() if len(f) else np.nan,
        floor_smoother_share=f[f.smoother_active].area_ha.sum() / f.area_ha.sum() if len(f) else np.nan,
        floor_either_share=f[f.floor_explains_cell].area_ha.sum() / f.area_ha.sum() if len(f) else np.nan,
        chain_eq_v2b_on_share=f[f.chain_eq_v2b_on].area_ha.sum() / f.area_ha.sum() if len(f) else np.nan,
        nonyoung_fail_minvol_share=(lambda o: o[o.below_minvol].area_ha.sum() / o.area_ha.sum() if o.area_ha.sum() > 0 else np.nan)(g[g.occ & g.fail & ~g.young]),
        young_pass_minvol_share=(lambda o: o[o.below_minvol].area_ha.sum() / o.area_ha.sum() if o.area_ha.sum() > 0 else np.nan)(y[~y.fail])))
Y = C.groupby(["variant", "st"]).apply(ysum, include_groups=False).reset_index()
YT = C.groupby(["variant"]).apply(ysum, include_groups=False).reset_index(); YT["st"] = "ALL"
AT = pd.concat([AREA_ALL, AREA_ALL.groupby("variant", as_index=False).area_total.sum().assign(st="ALL")])
AG = pd.concat([AREA_GT200, AREA_GT200.groupby("variant", as_index=False).area_age_gt200.sum().assign(st="ALL")])
Y = pd.concat([Y, YT]).merge(AT, on=["variant", "st"], how="left").merge(AG, on=["variant", "st"], how="left")
Y["area_age_gt200"] = Y.area_age_gt200.fillna(0.0); Y["share_area_age_gt200_not_roundtripped"] = Y.area_age_gt200 / Y.area_total
Y["young_fail_share_of_total_area"] = Y.area_young_fail / Y.area_total
Y["floor_explains_rule_ge_0p9"] = Y.floor_either_share >= 0.9
Y.to_csv(f"{OR}/tbJ_young_failure_floor_DATA.csv", index=False)
# s43-style young class cells (ages 1-10, 11-20, by ft): fail if max err > 2 percent
C["cls"] = np.where(C.age <= 10, "1-10", np.where(C.age <= 20, "11-20", "21+"))
YC = C[C.young].groupby(["variant", "st", "ft", "cls"]).agg(max_err=("err", "max"), occupied=("occ", "any")).reset_index()
YC["fail"] = YC.max_err > 0.02
YCs = YC.groupby("variant").agg(cells=("fail", "size"), fail=("fail", "sum"), occ_cells=("occupied", "sum")).reset_index()
YCs.to_csv(f"{OR}/tbJ_young_classcells_DATA.csv", index=False)
SS = S.groupby("variant").agg(strata=("pass_occupied_2pct", "size"), pass_occupied=("pass_occupied_2pct", "sum")).reset_index()
SS.to_csv(f"{OR}/tbJ_roundtrip_strata_pass_DATA.csv", index=False)
pd.set_option("display.width", 200)
print(SS.to_string()); print(YCs.to_string())
print(Y[Y.st == "ALL"][["variant", "young_fail_share_area", "young_fail_share_of_total_area", "fail_share_area_all_ages", "floor_minvol_share", "floor_smoother_share", "chain_eq_v2b_on_share", "share_area_age_gt200_not_roundtripped"]].round(4).to_string())
print("done 07J")
