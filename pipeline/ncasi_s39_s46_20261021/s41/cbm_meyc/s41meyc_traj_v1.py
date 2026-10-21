"""s41 cbm_meyc: 50 yr no harvest trajectory, old curves (registered FVS_FIAW_NEW
config, s40 run script) against the MEYC new curve configuration. Uses the v4
definition A components (diagnostic here; the gate is the 10 yr window). Also the
share of year 0 area whose stand age exceeds the AGB curve cell's observed age
(age_q99 of the statewide cell), i.e. sits on a flagged extrapolation.
Mg C -> dry Mg via /0.5. Aggregates only.
usage: python s41meyc_traj_v1.py OLD50DIR NEW50DIR NEW10DIR OUTPREFIX"""
import sys, numpy as np, pandas as pd
old, new, new10, pre = sys.argv[1:5]
AGP = ["SoftwoodMerch","SoftwoodFoliage","SoftwoodOther","HardwoodMerch","HardwoodFoliage","HardwoodOther"]
WOOD = ["SoftwoodMerch","SoftwoodOther","HardwoodMerch","HardwoodOther"]
f = 1 / 0.5 / 1e6
rows = []
for lab, d in (("old_FVS_curves", old), ("new_MEYC_curves", new)):
    P = pd.read_csv(f"{d}/runs/pools_ME_FVS_FIAW_NEW_noharv_50yr.csv").set_index("timestep")
    F = pd.read_csv(f"{d}/runs/flux_ME_FVS_FIAW_NEW_noharv_50yr.csv").set_index("timestep")
    ag = P[AGP].sum(axis=1); wood = P[WOOD].sum(axis=1); merch = P[["SoftwoodMerch","HardwoodMerch"]].sum(axis=1)
    dl = F[[c for c in ["DisturbanceMerchLitterInput","DisturbanceFolLitterInput","DisturbanceOthLitterInput",
                        "DisturbanceMerchToAir","DisturbanceFolToAir","DisturbanceOthToAir"] if c in F]].sum(axis=1)
    dm = F[[c for c in ["DisturbanceMerchLitterInput","DisturbanceMerchToAir"] if c in F]].sum(axis=1)
    rm = F[[c for c in ["DisturbanceSoftProduction","DisturbanceHardProduction"] if c in F]].sum(axis=1)
    for t in P.index:
        r = dict(run=lab, year=int(t), AG_Tg=ag[t] * f, woody_Tg=wood[t] * f, merch_Tg=merch[t] * f, AG_Mg_ha=ag[t] / 0.5 / P.loc[t, "total_area_ha"])
        if t >= 1:
            mort = F.loc[t, "TurnoverMerchLitterInput"] + F.loc[t, "TurnoverOthLitterInput"] + dl[t]
            r.update(net_Tg_yr=(ag[t] - ag[t - 1]) * f, mortA_Tg_yr=mort * f, merch_only_mort_Tg_yr=(F.loc[t, "TurnoverMerchLitterInput"] + dm[t]) * f,
                     gross_Tg_yr=(ag[t] - ag[t - 1] + mort + rm[t]) * f)
        rows.append(r)
T = pd.DataFrame(rows); T.to_csv(f"{pre}_traj50_annual_20261016.csv", index=False)
T["decade"] = ((T.year - 1) // 10 + 1) * 10
D = T[T.year >= 1].groupby(["run", "decade"])[["net_Tg_yr", "gross_Tg_yr", "mortA_Tg_yr", "merch_only_mort_Tg_yr"]].mean().reset_index()
S = T[T.year % 10 == 0][["run", "year", "AG_Tg", "woody_Tg", "AG_Mg_ha"]].rename(columns={"year": "decade"})
D = D.merge(S, on=["run", "decade"], how="outer").sort_values(["run", "decade"])
D.to_csv(f"{pre}_traj50_decadal_20261016.csv", index=False)
pd.set_option("display.width", 250); print(D.round(2).to_string())
# extrapolation share at year 0 and at year 50 (ages + 50)
FTMAP = {"FT100": "WRPH", "FT120": "SF", "FT160": "WRPH", "FT380": "SF", "FT400": "OAK", "FT500": "OAK", "FT700": "EAC", "FT800": "MBB", "FT900": "AB"}
cv = pd.read_csv("/users/PUOM0008/crsfaaron/maine_agb_yc_20261015/zenodo_upload/data/final_curves_capped_DATA.csv")
q = cv[cv.section == "ALL"].drop_duplicates("ftg").set_index("ftg").age_q99
A = pd.read_csv(f"{new10}/runs/agearea_ME_10yr.csv"); A["group"] = A.ft.map(FTMAP)
A = A[A.group.notna()].copy(); A["q99"] = A.group.map(q)
out = []
for h in (0, 10, 50):
    A["beyond"] = (A.age_bin10 + h) > A.q99  # bin lower edge; conservative
    A["ab"] = A.area * A.beyond
    g = A.groupby("group")["ab"].sum() / A.groupby("group")["area"].sum()
    for k, v in g.items(): out.append(dict(horizon_yr=h, group=k, area_share_beyond_obs_age=v))
    out.append(dict(horizon_yr=h, group="ALL", area_share_beyond_obs_age=(A.area * A.beyond).sum() / A.area.sum()))
E = pd.DataFrame(out); E.to_csv(f"{pre}_extrapolation_share_20261016.csv", index=False); print(E.round(3).to_string())
