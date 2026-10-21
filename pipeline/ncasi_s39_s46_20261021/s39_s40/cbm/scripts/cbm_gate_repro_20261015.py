"""Reproduction checks before any gate number is used.
(a) TEC year 0 and year 50 recomputed from the existing 2x2 pools files vs
    2x2_summary_DATA_2026-09-23.csv (all six states, FVS_FIAW_NEW).
(b) The rerun orig variant (10 yr) vs the existing 50 yr pools file at t0 and t10.
"""
import sys, pandas as pd, numpy as np
OUT = sys.argv[1]
S = pd.read_csv("/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_summary_DATA_2026-09-23.csv")
NONECO = {"timestep","Input","CO2","CH4","CO","NO2","Products","total_area_ha"}
rows = []
for st in ["ME","NH","VT","MI","WI","MN"]:
    p = pd.read_csv(f"/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{st}/libcbm_pools_{st}_FVS_FIAW_NEW_50yr.csv")
    eco = [c for c in p.columns if c not in NONECO]
    s = S[(S.state==st)&(S.cell=="FVS_FIAW_NEW")].iloc[0]
    for t, col in ((0,"tec_t0_MgC"),(50,"tec_t50_MgC")):
        v = p.loc[p.timestep==t, eco].sum(axis=1).iloc[0]
        rows.append(dict(state=st, check=f"existing_pools_TEC_t{t}_vs_summary", value=v, reference=s[col], rel_diff=v/s[col]-1))
    try:
        r = pd.read_csv(f"{OUT}/runs/pools_{st}_FVS_FIAW_NEW_orig_10yr.csv")
        for t in (0,10):
            a = r.loc[r.timestep==t, eco].sum(axis=1).iloc[0]
            b = p.loc[p.timestep==t, eco].sum(axis=1).iloc[0]
            rows.append(dict(state=st, check=f"rerun_orig_TEC_t{t}_vs_existing_pools", value=a, reference=b, rel_diff=a/b-1))
        a = r.loc[r.timestep==0, eco].sum(axis=1).iloc[0]
        rows.append(dict(state=st, check="rerun_orig_TEC_t0_vs_summary", value=a, reference=s["tec_t0_MgC"], rel_diff=a/s["tec_t0_MgC"]-1))
        ag = ["SoftwoodMerch","SoftwoodFoliage","SoftwoodOther","HardwoodMerch","HardwoodFoliage","HardwoodOther"]
        for t in (0,10):
            a = r.loc[r.timestep==t, ag].sum(axis=1).iloc[0]; b = p.loc[p.timestep==t, ag].sum(axis=1).iloc[0]
            rows.append(dict(state=st, check=f"rerun_orig_AGliveC_t{t}_vs_existing_pools", value=a, reference=b, rel_diff=a/b-1))
    except FileNotFoundError as e:
        rows.append(dict(state=st, check="rerun_orig_missing", value=np.nan, reference=np.nan, rel_diff=np.nan))
d = pd.DataFrame(rows); d["pass_0p1pct"] = d.rel_diff.abs() < 0.001
d.to_csv(f"{OUT}/cbm_repro_check_20261015.csv", index=False)
pd.set_option("display.width", 200); print(d.to_string())
