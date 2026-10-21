"""s41: yield curve value at each FVS sample stand's own starting age against
that stand's starting (FIA measured) merchantable volume, calibrated FVS arm.
Inputs are the cbm-yield-adapter files (no PLT_CN, no coordinates).
usage: python s41_curve_vs_start_v1.py <cbm-yield-adapter dir> <out csv>"""
import sys, numpy as np, pandas as pd
d0, out = sys.argv[1], sys.argv[2]
c = pd.read_csv(f"{d0}/yield_curve_coefficients_DATA_2026-09-17.csv"); c = c[c.arm == "calibrated"]
d = pd.read_csv(f"{d0}/fvs_growth_points_DATA_2026-09-17.csv"); d = d[d.arm == "calibrated"].sort_values(["stand_id", "stand_age"])
d = d.merge(c[["state", "TYPGRPCD", "b0", "b1", "b2"]], on=["state", "TYPGRPCD"], how="left")
assert d.b0.notna().all()
d["fit"] = d.b0 * (1 - np.exp(-d.b1 * d.stand_age)) ** d.b2
d["k"] = d.groupby("stand_id").cumcount()
f0 = d[d.k == 0]
g = f0.groupby("state").agg(n_stands=("stand_id", "size"), mean_start_age=("stand_age", "mean"), start_vol_m3ha=("merch_vol_m3ha", "mean"), curve_at_start_m3ha=("fit", "mean"))
g["curve_over_start"] = g.curve_at_start_m3ha / g.start_vol_m3ha
a = d.groupby("state").agg(obs=("merch_vol_m3ha", "mean"), fit=("fit", "mean")); g["curve_over_obs_all_points"] = a.fit / a.obs
g["vol_after_50yr_m3ha"] = d[d.k == 10].groupby("state").merch_vol_m3ha.mean()
g.reset_index().to_csv(out, index=False); print(g.round(3).to_string())
