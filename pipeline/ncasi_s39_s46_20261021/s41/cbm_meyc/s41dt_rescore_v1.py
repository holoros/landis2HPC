"""s41 dying-tree rescore (PROPOSED AMENDED DEFINITION, NOT FILED; diagnostic only).
Recomputes, from existing libcbm run outputs (pools/flux, noharv, years 1..10),
the registered definition A mortality and gross (as cbm_gate_score_v4_20261015.py)
next to:
  dying-tree mortality = TurnoverMerchLitterInput
       + TurnoverOthLitterInput * stem_turnover / branch_turnover   (Other pool at the stem rate)
       + natural disturbance AG losses excluding foliage (Merch and Oth, litter input + to air)
  merch-only mortality = TurnoverMerchLitterInput + disturbance Merch losses
  gross_x = net + mort_x + removals, net = AG_t - AG_{t-1} (AG incl foliage, as registered)
Turnover rates are read from the state AIDB (turnover_parameter via the eco boundary of the
config's default spatial unit). Checks: implied rates TurnoverMerch/Merch_{t-1} and
TurnoverOth/Other_{t-1}; dying-tree variant using stem_rate * Other_{t-1} instead.
Pass flags against the frozen 0.85 to 1.15 band. Aggregates only.
usage: python s41dt_rescore_v1.py OUT_CSV RUNDIR:LABEL [...]"""
import sys, json, sqlite3, pandas as pd, numpy as np
T = dict(ME=(762.4297, 25.6128, 9.4943, 16.1185), MN=(633.4494, 25.1058, 10.6370, 14.4688))
g = pd.read_csv("/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/gates/grm_realism_fourstate_20261006.csv"); g.columns = [c.lower() for c in g.columns]
for _, r in g.iterrows(): T[r["state"]] = (r["stock_tg"], r.fia_gross_growth, r.fia_mortality, r.fia_net_growth)
AGP = ["SoftwoodMerch","SoftwoodFoliage","SoftwoodOther","HardwoodMerch","HardwoodFoliage","HardwoodOther"]
def rates(st):
    cfg = json.load(open(f"/users/PUOM0008/crsfaaron/ncasi_cem_yield/output/2x2_{st}/adapted_FVS_FIAW_NEW/sit_config.json"))["mapping_config"]["spatial_units"]
    con = sqlite3.connect(f"/users/PUOM0008/crsfaaron/cbm_states/states/{st}/data/processed/cbm_defaults_{st}.db")
    r = con.execute("""select t.stem_turnover, t.sw_branch, t.hw_branch, t.sw_foliage, t.hw_foliage, t.branch_snag_split, t.id
        from spatial_unit su join admin_boundary_tr a on a.admin_boundary_id=su.admin_boundary_id and a.locale_id=1
        join eco_boundary_tr e on e.eco_boundary_id=su.eco_boundary_id and e.locale_id=1
        join eco_boundary eb on eb.id=su.eco_boundary_id join turnover_parameter t on t.id=eb.turnover_parameter_id
        where a.name=? and e.name=?""", (cfg["admin_boundary"], cfg["eco_boundary"])).fetchone()
    con.close()
    return dict(zip(["stem","sw_branch","hw_branch","sw_fol","hw_fol","branch_snag_split","turnover_param_id"], r))
def ok(x): return bool(0.85 <= x <= 1.15)
rows = []
for spec in sys.argv[2:]:
    d, lab = spec.split(":")
    try: v4 = pd.read_csv(f"{d}/cbm_gate_results_v4_20261015.csv").set_index(["state","variant"])
    except FileNotFoundError: v4 = None
    for st in ["ME","NH","VT","MI","WI","MN"]:
        try:
            P = pd.read_csv(f"{d}/runs/pools_{st}_FVS_FIAW_NEW_noharv_10yr.csv").set_index("timestep")
            F = pd.read_csv(f"{d}/runs/flux_{st}_FVS_FIAW_NEW_noharv_10yr.csv").set_index("timestep")
        except FileNotFoundError: continue
        R = rates(st); assert abs(R["sw_branch"] - R["hw_branch"]) < 1e-9
        k = R["stem"] / R["sw_branch"]
        c = lambda n: F[n] if n in F else pd.Series(0.0, index=F.index)
        y = list(range(1, 11)); f = 1 / 0.5 / 1e6
        ag = P[AGP].sum(axis=1); merch = P[["SoftwoodMerch","HardwoodMerch"]].sum(axis=1); oth = P[["SoftwoodOther","HardwoodOther"]].sum(axis=1)
        net = np.array([ag[t] - ag[t - 1] for t in y])
        tm = c("TurnoverMerchLitterInput")[y].values; to = c("TurnoverOthLitterInput")[y].values
        dmer = (c("DisturbanceMerchLitterInput") + c("DisturbanceMerchToAir"))[y].values
        doth = (c("DisturbanceOthLitterInput") + c("DisturbanceOthToAir"))[y].values
        dfol = (c("DisturbanceFolLitterInput") + c("DisturbanceFolToAir"))[y].values
        rem = (c("DisturbanceSoftProduction") + c("DisturbanceHardProduction"))[y].values
        oth_prev = np.array([oth[t - 1] for t in y]); merch_prev = np.array([merch[t - 1] for t in y])
        m_reg = tm + to + dmer + doth + dfol
        m_dt = tm + to * k + dmer + doth
        m_dt_pool = tm + R["stem"] * oth_prev + dmer + doth
        m_mo = tm + dmer
        s0, gg, mo, nn = T[st]
        out = dict(run=lab, state=st, fia_gross_Tg_yr=gg, fia_mort_Tg_yr=mo, fia_net_Tg_yr=nn,
                   stem_turnover=R["stem"], branch_turnover=R["sw_branch"], branch_snag_split=R["branch_snag_split"], turnover_param_id=R["turnover_param_id"],
                   implied_merch_rate=float((tm / merch_prev).mean()), implied_other_rate=float((to / oth_prev).mean()),
                   net_Tg_yr=net.mean() * f, ratio_net=net.mean() * f / nn,
                   other_turnover_Tg_yr=to.mean() * f, dist_foliage_Tg_yr=dfol.mean() * f)
        for nm, m in (("reg", m_reg), ("dt", m_dt), ("dtpool", m_dt_pool), ("merch", m_mo)):
            gr = net + m + rem
            out[f"mort_{nm}_Tg_yr"] = m.mean() * f; out[f"ratio_mort_{nm}"] = m.mean() * f / mo
            out[f"gross_{nm}_Tg_yr"] = gr.mean() * f; out[f"ratio_gross_{nm}"] = gr.mean() * f / gg
            out[f"pass_mort_{nm}"] = ok(out[f"ratio_mort_{nm}"]); out[f"pass_gross_{nm}"] = ok(out[f"ratio_gross_{nm}"])
        out["pass_net"] = ok(out["ratio_net"])
        if v4 is not None and (st, "noharv") in v4.index:
            vv = v4.loc[(st, "noharv")]
            out["v4_ratio_mort"] = vv.ratio_mort; out["v4_ratio_gross"] = vv.ratio_gross; out["v4_ratio_net"] = vv.ratio_net
            out["v4_ratio_mortB"] = vv.ratio_mortB; out["v4_ratio_grossB"] = vv.ratio_grossB
            out["repro_ok"] = bool(abs(vv.ratio_mort - out["ratio_mort_reg"]) < 1e-6 and abs(vv.ratio_gross - out["ratio_gross_reg"]) < 1e-6)
        rows.append(out)
D = pd.DataFrame(rows); D.to_csv(sys.argv[1], index=False)
pd.set_option("display.width", 300); pd.set_option("display.max_columns", 60)
print(D[["run","state","implied_merch_rate","implied_other_rate","ratio_mort_reg","ratio_mort_dt","ratio_mort_dtpool","ratio_mort_merch",
         "ratio_gross_reg","ratio_gross_dt","ratio_gross_merch","ratio_net","dist_foliage_Tg_yr","repro_ok"]].round(4).to_string())
