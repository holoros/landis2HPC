"""Score the CBM-CFS3 (libcbm) FVS_FIAW_NEW cell against the pre-registered
Phase 1 realism gate (2026-10-15_ncasi-phase1-realism-gates_PLAN.md).
Currency: aboveground live tree biomass, dry Mg, = carbon / 0.5 (libcbm
biomass carbon fraction). Primary arm: noharv (harvest events removed,
natural disturbance events kept), years 1 to 10.
Definitions (state totals, Mg C then / 0.5):
  AG       = Softwood+Hardwood Merch + Foliage + Other pools
  net_t    = AG_t - AG_{t-1}
  mort_t   = TurnoverMerchLitterInput + TurnoverOthLitterInput
             + AG biomass losses in natural disturbance events
               (Disturbance{Merch,Fol,Oth}LitterInput + Disturbance{Merch,Fol,Oth}ToAir)
  rem_t    = DisturbanceSoftProduction + DisturbanceHardProduction
  gross_t  = net_t + mort_t + rem_t  (foliage litterfall netted out of gross)
  check    = DeltaBiomass_AG - TurnoverFolLitterInput, should equal gross_t
"""
import sys, pandas as pd, numpy as np
OUT = sys.argv[1]
CF = 0.5
AREA = dict(ME=7002925, NH=1910089, VT=1792058, MI=7790021, WI=6723136, MN=7076703)
# FIA EVALIDator 2024, dry Tg and Tg/yr aboveground live tree biomass
T = dict(  # stock, gross(1311), mort(335), net(311), stock lo95, hi95
 ME=(762.4297, 25.6128, 9.4943, 16.1185, 748.5695, 776.2899),
 MN=(633.4494, 25.1058, 10.6370, 14.4688, 622.6678, 644.2309),
)
g = pd.read_csv("/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/gates/grm_realism_fourstate_20261006.csv")
g.columns = [c.lower() for c in g.columns]
for _, r in g.iterrows():
    T[r["state"]] = (r["stock_tg"], r.fia_gross_growth, r.fia_mortality, r.fia_net_growth, np.nan, np.nan)
AGP = ["SoftwoodMerch","SoftwoodFoliage","SoftwoodOther","HardwoodMerch","HardwoodFoliage","HardwoodOther"]
WOOD = ["SoftwoodMerch","SoftwoodOther","HardwoodMerch","HardwoodOther"]
def col(F, names):
    have = [n for n in names if n in F.columns]
    miss = [n for n in names if n not in F.columns]
    return F[have].sum(axis=1) if have else pd.Series(0.0, index=F.index), miss
rows, comp = [], []
for st in ["ME","NH","VT","MI","WI","MN"]:
    for v in ["noharv","nodist","orig"]:
        try:
            P = pd.read_csv(f"{OUT}/runs/pools_{st}_FVS_FIAW_NEW_{v}_10yr.csv").set_index("timestep")
            F = pd.read_csv(f"{OUT}/runs/flux_{st}_FVS_FIAW_NEW_{v}_10yr.csv").set_index("timestep")
        except FileNotFoundError:
            continue
        ag = P[AGP].sum(axis=1); wood = P[WOOD].sum(axis=1); fol = ag - wood
        area = P["total_area_ha"].iloc[0]
        to, m1 = col(F, ["TurnoverMerchLitterInput","TurnoverOthLitterInput"])
        dl, m2 = col(F, ["DisturbanceMerchLitterInput","DisturbanceFolLitterInput","DisturbanceOthLitterInput",
                         "DisturbanceMerchToAir","DisturbanceFolToAir","DisturbanceOthToAir"])
        rm, m3 = col(F, ["DisturbanceSoftProduction","DisturbanceHardProduction"])
        tf, m4 = col(F, ["TurnoverFolLitterInput"])
        db, m5 = col(F, ["DeltaBiomass_AG"])
        yrs = range(1, 11)
        net = np.array([ag[t]-ag[t-1] for t in yrs])
        mort = np.array([to[t]+dl[t] for t in yrs])
        rem = np.array([rm[t] for t in yrs])
        gross = net + mort + rem
        chk = np.array([db[t]-tf[t] for t in yrs])
        for i, t in enumerate(yrs):
            comp.append(dict(state=st, variant=v, year=t, AG_C_start=ag[t-1], net_C=net[i], turnover_mort_C=to[t],
                             dist_mort_C=dl[t], removals_C=rem[i], gross_C=gross[i],
                             gross_check_DeltaBiomassAG_minus_folTO_C=chk[i], foliage_litterfall_C=tf[t]))
        f = 1.0/CF/1e6
        s0, gg, mm, nn, lo, hi = T[st]
        mod = dict(stock=ag[0]*f, gross=gross.mean()*f, mort=mort.mean()*f, net=net.mean()*f)
        rows.append(dict(state=st, variant=v, area_model_ha=area, area_fia_ha=AREA[st],
            model_stock_Tg=mod["stock"], model_stock_woody_Tg=wood[0]*f, model_foliage_share_t0=fol[0]/ag[0],
            fia_stock_Tg=s0, ratio_stock=mod["stock"]/s0, ratio_stock_woody=wood[0]*f/s0,
            model_gross_Tg_yr=mod["gross"], fia_gross_Tg_yr=gg, ratio_gross=mod["gross"]/gg,
            model_mort_Tg_yr=mod["mort"], fia_mort_Tg_yr=mm, ratio_mort=mod["mort"]/mm,
            model_mort_turnover_Tg_yr=to.loc[1:10].mean()*f, model_mort_disturbance_Tg_yr=dl.loc[1:10].mean()*f,
            model_net_Tg_yr=mod["net"], fia_net_Tg_yr=nn, ratio_net=mod["net"]/nn,
            model_removals_Tg_yr=rem.mean()*f,
            model_gross_Mg_ha_yr=mod["gross"]*1e6/area, model_mort_Mg_ha_yr=mod["mort"]*1e6/area,
            model_net_Mg_ha_yr=mod["net"]*1e6/area, model_stock_Mg_ha=mod["stock"]*1e6/area,
            gross_closure_rel=(chk.sum()-gross.sum())/gross.sum(),
            missing_flux_names=";".join(m1+m2+m3+m4+m5)))
R = pd.DataFrame(rows)
def ok(r, lo, hi): return bool(lo <= r <= hi)
R["pass_stock"] = [ok(r, 0.90, 1.10) or (not np.isnan(T[s][4]) and T[s][4] <= m <= T[s][5])
                   for r, s, m in zip(R.ratio_stock, R.state, R.model_stock_Tg)]
R["pass_gross"] = [ok(r, .85, 1.15) for r in R.ratio_gross]
R["pass_mort"] = [ok(r, .85, 1.15) for r in R.ratio_mort]
R["pass_net"] = [ok(r, .85, 1.15) for r in R.ratio_net]
R["age_class_test"] = "not exposed: FIA age class targets from remeasured pairs not built"
R["gate_state"] = np.where(R[["pass_stock","pass_gross","pass_mort","pass_net"]].all(axis=1),
                           "PARTIAL (4 of 4 scored pass; age class not scored)", "FAIL")
R.loc[R.variant!="noharv","gate_state"] = "sensitivity only, not the gate arm"
R.to_csv(f"{OUT}/cbm_gate_results_20261015.csv", index=False)
pd.DataFrame(comp).to_csv(f"{OUT}/cbm_gate_annual_components_20261015.csv", index=False)
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 50)
print(R[["state","variant","ratio_stock","ratio_stock_woody","ratio_gross","ratio_mort","ratio_net","model_removals_Tg_yr","gross_closure_rel","gate_state","missing_flux_names"]].round(3).to_string())

# Supplementary: per age class and per biomass class gross growth (noharv), Mg dry/ha/yr
B = []
for st in ["ME","NH","VT","MI","WI","MN"]:
    try: b = pd.read_csv(f"{OUT}/runs/bins_{st}_FVS_FIAW_NEW_noharv_10yr.csv")
    except FileNotFoundError: continue
    b["gross_C"] = b.get("DeltaBiomass_AG", 0) - b.get("TurnoverFolLitterInput", 0)
    b["mort_C"] = sum(b.get(c, 0) for c in ["TurnoverMerchLitterInput","TurnoverOthLitterInput","DisturbanceMerchLitterInput",
                   "DisturbanceFolLitterInput","DisturbanceOthLitterInput","DisturbanceMerchToAir","DisturbanceFolToAir","DisturbanceOthToAir"])
    s = b.groupby(["kind","bin"])[["area","gross_C","mort_C"]].sum().reset_index()
    s["gross_Mg_ha_yr"] = s.gross_C/CF/s.area; s["mort_Mg_ha_yr"] = s.mort_C/CF/s.area
    s["area_share"] = s.area / s.groupby("kind").area.transform("sum"); s["state"] = st
    B.append(s)
if B:
    B = pd.concat(B)
    try:
        fb = pd.read_csv("/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/gates/behav_bins_20261015.csv")
        fb = fb.drop_duplicates(["state","bin"])[["state","bin","plots","fia_gg"]]
        fb["fia_gg_Mg_ha_yr"] = fb.fia_gg/100.0
        B = B.merge(fb, on=["state","bin"], how="left")
        hi = B[(B.kind=="biomass") & B.bin.isin(["[200,250)","[250,300)","[300,Inf)"])].copy()
        sup = []
        for st, h in hi.groupby("state"):
            if h.fia_gg_Mg_ha_yr.notna().all():
                m = (h.gross_C.sum()/CF)/h.area.sum(); fia = np.average(h.fia_gg_Mg_ha_yr, weights=h.plots)
                sup.append(dict(state=st, cbm_gross_gt200=m, fia_gross_gt200=fia, ratio=m/fia, cbm_area_share_gt200=h.area_share.sum()))
        print("\nSupplementary biomass class >200 Mg/ha (not the gate):"); print(pd.DataFrame(sup).round(3).to_string())
        pd.DataFrame(sup).to_csv(f"{OUT}/cbm_biomassclass_gt200_SUPPLEMENTARY_20261015.csv", index=False)
    except Exception as e:
        print("bins merge failed", e)
    B.to_csv(f"{OUT}/cbm_gate_bins_noharv_20261015.csv", index=False)
    print(B[B.kind=="age"][["state","bin","area_share","gross_Mg_ha_yr","mort_Mg_ha_yr"]].round(3).to_string())
