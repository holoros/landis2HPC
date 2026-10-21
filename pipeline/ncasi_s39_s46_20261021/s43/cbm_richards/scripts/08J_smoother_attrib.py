"""s43 Track J addendum to the floor test (diagnostic; libcbm chain not changed). Reads out/tbJ_roundtrip_cells_DATA.csv.
(a) pass 0: for young occupied failing cells, share (area weighted) where the python chain on the final volumes misses the target
    by > 2 percent (the correction passes moved the young volumes off the target; build artifact) vs where it hits the target
    but libcbm's smoother-on conversion does not (smoother).
(b) pass 1 (direct python inversion of the target, before any correction): recompute V1 = invert(target), libcbm conversion
    with smoother on/off, and compare with the pass 1 libcbm round trip ratio. Young occupied cells failing at pass 1 are
    attributed to the smoother if |v2b_on(V1)/target - 1| > 0.02 while |v2b_off(V1)/target - 1| <= 0.02.
usage: python 08J_smoother_attrib.py OUTROOT S43ROOT"""
import sys, json, sqlite3
import numpy as np, pandas as pd
from libcbm.wrapper.volume_to_biomass.volume_to_biomass_wrapper import VolumeToBiomassWrapper, MerchVolumeCurve
OR, S43 = sys.argv[1], sys.argv[2]
exec(open(f"{OR}/../scripts/07J_rt_eval_floor.py").read().split("CELLS = []")[0].split("OR, S43 = sys.argv[1], sys.argv[2]")[1])  # boud, factor, VARS, WOODY, v2b
def invert(T, f, vmax=5000.0):  # copied from s43nd_build_v1.py
    if T <= 0: return 0.0
    lo, hi = 0.0, vmax
    for _ in range(80):
        mid = 0.5 * (lo + hi)
        if boud(mid, f)[0] < T: lo = mid
        else: hi = mid
    return 0.5 * (lo + hi)
C = pd.read_csv(f"{OR}/tbJ_roundtrip_cells_DATA.csv")
C["py_miss"] = (C.py_boud / C.target - 1).abs() > 0.02
OUT = []
for V, (RT, PS) in VARS.items():
    for ST in STS:
        R1 = pd.read_csv(f"{RT}/{ST}/s43nd_{ST}_roundtrip_all_passes_20261019.csv"); R1 = R1[(R1["pass"] == 1) & (R1.age <= 20)]
        cfg = json.load(open(f"{RT}/{ST}/adapted_NETDRV/sit_config.json"))["mapping_config"]
        smap = {x["user_species"].replace(" ", ""): x["default_species"] for x in cfg["species"]["species_mapping"]}
        DB = f"/users/PUOM0008/crsfaaron/cbm_states/states/{ST}/data/processed/cbm_defaults_{ST}.db"
        con = sqlite3.connect(DB)
        suid = con.execute("""select su.id from spatial_unit su join admin_boundary_tr a on a.admin_boundary_id=su.admin_boundary_id and a.locale_id=1
           join eco_boundary_tr e on e.eco_boundary_id=su.eco_boundary_id and e.locale_id=1 where a.name=? and e.name=?""",
           (cfg["spatial_units"]["admin_boundary"], cfg["spatial_units"]["eco_boundary"])).fetchone()[0]
        for ft in sorted(R1.ft.unique()):
            fa = factor(con, suid, smap[ft]); c = C[(C.variant == V) & (C.st == ST) & (C.ft == ft)].sort_values("age")
            V1 = np.array([invert(float(t), fa) for t in c.target.values]).astype(np.float64)
            ages = c.age.values.astype(np.int32)
            on = v2b.volume_to_biomass(suid, [MerchVolumeCurve(int(fa["sid"]), ages, V1)], use_smoother=True, db_path=DB)[WOODY].sum(axis=1).values / 0.5
            off = v2b.volume_to_biomass(suid, [MerchVolumeCurve(int(fa["sid"]), ages, V1)], use_smoother=False, db_path=DB)[WOODY].sum(axis=1).values / 0.5
            r1 = R1[R1.ft == ft].set_index("age").ratio.reindex(range(1, 21)).values
            k = c.age.values <= 20
            OUT.append(pd.DataFrame(dict(variant=V, st=ST, ft=ft, age=c.age.values[k], area_ha=c.area_ha.values[k], target=c.target.values[k], V1=V1[k],
                ratio_pass1=r1, v2b_on_V1_ratio=on[k] / c.target.values[k], v2b_off_V1_ratio=off[k] / c.target.values[k],
                fail_pass0=c.err.values[k] > 0.02, py_miss_pass0=c.py_miss.values[k], smoother_active_pass0=c.smoother_active.values[k])))
        con.close()
O = pd.concat(OUT, ignore_index=True)
O["fail_pass1"] = (O.ratio_pass1 - 1).abs() > 0.02
O["smoother_pass1"] = ((O.v2b_on_V1_ratio - 1).abs() > 0.02) & ((O.v2b_off_V1_ratio - 1).abs() <= 0.02)
O["chain1_eq_v2b_on"] = (O.ratio_pass1 / O.v2b_on_V1_ratio - 1).abs() <= 0.02
O.to_csv(f"{OR}/tbJ_young_pass1_smoother_cells_DATA.csv", index=False)
def s(g):
    o = g[g.area_ha > 0]; a = o.area_ha.sum(); f1 = o[o.fail_pass1]; f0 = o[o.fail_pass0]
    w = lambda x, m: x[m].area_ha.sum() / x.area_ha.sum() if x.area_ha.sum() > 0 else np.nan
    return pd.Series(dict(young_area=a, fail_share_pass1=f1.area_ha.sum() / a, fail_share_pass0=f0.area_ha.sum() / a,
        pass1_fail_smoother_share=w(f1, f1.smoother_pass1), pass1_fail_chain_eq_v2b_on_share=w(f1, f1.chain1_eq_v2b_on),
        pass0_fail_py_miss_share=w(f0, f0.py_miss_pass0), pass0_fail_smoother_share=w(f0, f0.smoother_active_pass0),
        pass0_fail_py_miss_or_smoother_share=w(f0, f0.py_miss_pass0 | f0.smoother_active_pass0)))
T = pd.concat([O.groupby("variant").apply(s, include_groups=False).reset_index().assign(st="ALL"),
               O.groupby(["variant", "st"]).apply(s, include_groups=False).reset_index()])
T.to_csv(f"{OR}/tbJ_young_smoother_attrib_DATA.csv", index=False)
pd.set_option("display.width", 220)
print(T[T.st == "ALL"].round(4).to_string()); print("done 08J")
