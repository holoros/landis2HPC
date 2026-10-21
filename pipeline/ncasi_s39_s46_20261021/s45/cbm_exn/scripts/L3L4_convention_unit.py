"""s45 Track L: L3 convention test (one undisturbed stand, sw and hw) and L4 unit test
(zero turnover, 1 Mg dry in must return 1 Mg dry, CF 0.5 in and out).
usage: python L3L4_convention_unit.py ST OUTDIR"""
import sys, os
import numpy as np, pandas as pd
sys.path.insert(0, os.path.dirname(__file__))
import exn_common as E
from libcbm.model.cbm_exn import cbm_exn_model
from libcbm.model.cbm_exn.cbm_exn_parameters import parameters_factory

ST, OUT = sys.argv[1], sys.argv[2]; os.makedirs(OUT, exist_ok=True)
S = E.spin_settings(ST); spu = S["spatial_unit_id"]; mat = S["mean_annual_temperature"]
PX = parameters_factory(E.exn_dir(ST), None)
sp = PX.species.copy()
swmap = PX.get_sw_hw_map()
sw_species = int([k for k, x in swmap.items() if x == 0][0]); hw_species = int([k for k, x in swmap.items() if x == 1][0])
TO = PX.get_turnover_parameters()
rate = {}
for sh, code in (("sw", 0), ("hw", 1)):
    r = TO[(TO.spatial_unit_id == spu) & (TO.sw_hw == code)].iloc[0]
    rate[code] = dict(Merch=r.StemAnnualTurnoverRate, Foliage=r.FoliageFallRate, Other=r.BranchTurnoverRate)
print("turnover rates used", rate)
N = 60
yrs = np.arange(1, N + 1)
inc = dict(Merch=np.where(yrs <= 40, 0.9, 0.3), Foliage=np.where(yrs <= 20, 0.12, 0.02), Other=np.where(yrs <= 40, 0.35, 0.12))
rows = []
with cbm_exn_model.initialize(config_path=E.exn_dir(ST)) as m:
    print("flux names", m.flux_names)
    v = E.bare_vars(m, 2, spu, np.array([0, 1]), np.array([sw_species, hw_species]), 0, mat)
    hist = []; fx = []
    for t in range(N):
        v = E.step(m, v, inc["Merch"][t], inc["Foliage"][t], inc["Other"][t])
        hist.append(v["pools"][["Merch", "Foliage", "Other", "StemSnag", "BranchSnag", "AboveGroundVeryFastSoil", "AboveGroundFastSoil"]].copy().assign(year=t + 1, sw_hw=[0, 1]))
        fx.append(v["flux"][["TurnoverMerchLitterInput", "TurnoverFolLitterInput", "TurnoverOthLitterInput", "DeltaBiomass_AG"]].copy().assign(year=t + 1, sw_hw=[0, 1]))
    H = pd.concat(hist); FX = pd.concat(fx)
    FX.to_csv(os.path.join(OUT, f"L3_convention_flux_{ST}.csv"), index=False); H.to_csv(os.path.join(OUT, f"L3_convention_pools_{ST}.csv"), index=False)
for code in (0, 1):
    h = H[H.sw_hw == code].set_index("year")
    for p in ("Merch", "Foliage", "Other"):
        r = rate[code][p]; net = np.cumsum(inc[p])
        g_half = np.zeros(N); g_simple = np.zeros(N); P = 0.0; Q = 0.0
        for t in range(N):
            P = (P + inc[p][t] / 2) * (1 - r) + inc[p][t] / 2; g_half[t] = P
            Q = Q * (1 - r) + inc[p][t]; g_simple[t] = Q
        obs = h[p].values
        for nm, ex in (("net_cumulative_increments", net), ("gross_halfstep_growth_turnover_growth", g_half), ("gross_simple_inc_minus_rate_x_pool", g_simple)):
            rows.append(dict(state=ST, sw_hw=["sw", "hw"][code], pool=p, rate=r, hypothesis=nm,
                             max_rel_dev=float(np.max(np.abs(obs - ex) / np.maximum(ex, 1e-12))), pool_y60=float(obs[-1]), expected_y60=float(ex[-1])))
    # turnover flux check: is turnover computed on the pools (rate x pool at the start of the step plus half the increment)?
    f = FX[FX.sw_hw == code].set_index("year")
    for p, fn in (("Merch", "TurnoverMerchLitterInput"), ("Foliage", "TurnoverFolLitterInput"), ("Other", "TurnoverOthLitterInput")):
        r = rate[code][p]; pool_end = h[p].values; pool_start = np.concatenate([[0.0], pool_end[:-1]])
        ex = r * (pool_start + inc[p] / 2)
        rows.append(dict(state=ST, sw_hw=["sw", "hw"][code], pool=p, rate=r, hypothesis="flux_equals_rate_x_(start_pool_plus_half_inc)",
                         max_rel_dev=float(np.max(np.abs(f[fn].values[1:] - ex[1:]) / np.maximum(ex[1:], 1e-12))), pool_y60=float(f[fn].values[-1]), expected_y60=float(ex[-1])))
    rows.append(dict(state=ST, sw_hw=["sw", "hw"][code], pool="DeltaBiomass_AG", rate=np.nan, hypothesis="DeltaBiomass_AG_equals_sum_of_increments",
                     max_rel_dev=float(np.max(np.abs(f["DeltaBiomass_AG"].values - (inc["Merch"] + inc["Foliage"] + inc["Other"])) / (inc["Merch"] + inc["Foliage"] + inc["Other"]))),
                     pool_y60=float(f["DeltaBiomass_AG"].values[-1]), expected_y60=float(inc["Merch"][-1] + inc["Foliage"][-1] + inc["Other"][-1])))
    rows.append(dict(state=ST, sw_hw=["sw", "hw"][code], pool="StemSnag_y60", rate=np.nan, hypothesis="snag_pool_positive", max_rel_dev=np.nan,
                     pool_y60=float(h["StemSnag"].values[-1]), expected_y60=np.nan))
C = pd.DataFrame(rows)
C.to_csv(os.path.join(OUT, f"L3_convention_{ST}.csv"), index=False)
print(C.to_string())
B0 = C[C.hypothesis.isin(["net_cumulative_increments", "gross_halfstep_growth_turnover_growth", "gross_simple_inc_minus_rate_x_pool"])]
best = B0.loc[B0.groupby(["sw_hw", "pool"]).max_rel_dev.idxmin()]
print("best hypothesis per pool:"); print(best[["sw_hw", "pool", "hypothesis", "max_rel_dev"]].to_string())

# L4 unit test: zero turnover, 1 Mg dry per component in one year
TZ = pd.read_csv(os.path.join(E.exn_dir(ST), "turnover_parameters.csv"))
for c in ["FoliageFallRate", "StemAnnualTurnoverRate", "BranchTurnoverRate", "CoarseRootTurnProp", "FineRootTurnProp"]:
    TZ[c] = 0.0
U = []
with cbm_exn_model.initialize(parameters={"turnover_parameters": TZ}, config_path=E.exn_dir(ST)) as m:
    for comp in ("Merch", "Foliage", "Other"):
        v = E.bare_vars(m, 2, spu, np.array([0, 1]), np.array([sw_species, hw_species]), 0, mat)
        d = {k: 0.0 for k in ("Merch", "Foliage", "Other")}; d[comp] = float(E.dry_to_c(1.0))
        v = E.step(m, v, d["Merch"], d["Foliage"], d["Other"])
        out = E.c_to_dry(v["pools"][comp].values)
        for code in (0, 1):
            U.append(dict(state=ST, test=f"zero_turnover_1Mg_{comp}", sw_hw=["sw", "hw"][code], Mg_in=1.0, Mg_out=float(out[code]),
                          abs_err=float(abs(out[code] - 1.0)), pass_=bool(abs(out[code] - 1.0) < 1e-9)))
U = pd.DataFrame(U); U.to_csv(os.path.join(OUT, f"L4_unit_{ST}.csv"), index=False)
print(U.to_string())
print("UNIT TEST", "PASS" if U.pass_.all() else "FAIL")
