"""s41 diagnostic column: merchantable-only mortality (TurnoverMerchLitterInput +
natural disturbance merch losses) and the registered definition A components,
for the s40 baseline noharv runs and the s41 fixF2 runs. Also year 0 pool
shares and the Other/Merch turnover ratio. Mg C -> dry Tg via /0.5/1e6.
usage: python s41_merch_mort_diag_v1.py OUT_CSV RUNDIR:LABEL [RUNDIR:LABEL ...]"""
import sys, pandas as pd, numpy as np
T = dict(ME=(762.4297, 25.6128, 9.4943, 16.1185), MN=(633.4494, 25.1058, 10.6370, 14.4688))
g = pd.read_csv("/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/gates/grm_realism_fourstate_20261006.csv"); g.columns = [c.lower() for c in g.columns]
for _, r in g.iterrows(): T[r["state"]] = (r["stock_tg"], r.fia_gross_growth, r.fia_mortality, r.fia_net_growth)
AGP = ["SoftwoodMerch","SoftwoodFoliage","SoftwoodOther","HardwoodMerch","HardwoodFoliage","HardwoodOther"]
rows = []
for spec in sys.argv[2:]:
    d, lab = spec.split(":")
    for st in ["ME","NH","VT","MI","WI","MN"]:
        try:
            P = pd.read_csv(f"{d}/runs/pools_{st}_FVS_FIAW_NEW_noharv_10yr.csv").set_index("timestep")
            F = pd.read_csv(f"{d}/runs/flux_{st}_FVS_FIAW_NEW_noharv_10yr.csv").set_index("timestep")
        except FileNotFoundError: continue
        f = 1 / 0.5 / 1e6; y = range(1, 11)
        merch = P[["SoftwoodMerch","HardwoodMerch"]].sum(axis=1); oth = P[["SoftwoodOther","HardwoodOther"]].sum(axis=1); fol = P[["SoftwoodFoliage","HardwoodFoliage"]].sum(axis=1)
        dm = F.loc[y, [c for c in ["DisturbanceMerchLitterInput","DisturbanceMerchToAir"] if c in F]].sum(axis=1)
        mm = (F.loc[y, "TurnoverMerchLitterInput"] + dm).mean() * f
        s0, gg, mo, nn = T[st]
        rows.append(dict(run=lab, state=st, stock0_Tg=(merch[0] + oth[0] + fol[0]) * f, ratio_stock=(merch[0] + oth[0] + fol[0]) * f / s0,
                         merch0_Tg=merch[0] * f, other0_Tg=oth[0] * f, foliage0_Tg=fol[0] * f, other_over_merch_t0=oth[0] / merch[0],
                         turnover_merch_Tg_yr=F.loc[y, "TurnoverMerchLitterInput"].mean() * f, turnover_other_Tg_yr=F.loc[y, "TurnoverOthLitterInput"].mean() * f,
                         other_over_merch_turnover=F.loc[y, "TurnoverOthLitterInput"].sum() / F.loc[y, "TurnoverMerchLitterInput"].sum(),
                         merch_only_mort_Tg_yr=mm, ratio_merch_only_mort=mm / mo, fia_mort_Tg_yr=mo))
R = pd.DataFrame(rows); R.to_csv(sys.argv[1], index=False)
pd.set_option("display.width", 250); print(R.round(4).to_string())
