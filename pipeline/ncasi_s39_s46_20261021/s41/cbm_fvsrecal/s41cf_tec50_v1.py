"""s41 cbm_fvsrecal: total ecosystem carbon density (the 2x2 F15 metric), as in aggregate_2x2_DRAFT_2026-09-23.py:
sum of all pools except Input, CO2, CH4, CO, NO2, Products at years 0 and 50, over total_area_ha.
usage: python s41cf_tec50_v1.py OUTCSV LABEL:POOLS_PATTERN(with {ST}) [...]"""
import sys, pandas as pd
EX = {"timestep", "Input", "CO2", "CH4", "CO", "NO2", "Products", "total_area_ha"}
rows = []
for spec in sys.argv[2:]:
    lab, pat = spec.split(":", 1)
    for ST in ["ME", "NH", "VT", "MI", "WI", "MN"]:
        P = pd.read_csv(pat.format(ST=ST)); cols = [c for c in P.columns if c not in EX]
        a = P["total_area_ha"].iloc[-1]; t = P[cols].sum(axis=1)
        rows.append(dict(curves=lab, state=ST, area_ha=a, timesteps=len(P) - 1, tec_t0_MgC=t.iloc[0], tec_t50_MgC=t.iloc[-1],
                         dens_t0_MgC_ha=t.iloc[0] / a, dens_t50_MgC_ha=t.iloc[-1] / a))
R = pd.DataFrame(rows); R.to_csv(sys.argv[1], index=False); print(R.round(3).to_string(index=False))
