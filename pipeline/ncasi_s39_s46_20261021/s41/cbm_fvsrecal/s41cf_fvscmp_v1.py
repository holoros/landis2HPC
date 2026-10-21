"""s41 cbm_fvsrecal: compare a rerun of the September frame projections against the
September output (stand set identity and calibrated-arm trajectories), and write
state x arm x year_offset means (aggregates only, no stand ids).
usage: python s41cf_fvscmp_v1.py SEPT_TRAJ SEPT_INV NEW_TRAJ NEW_INV OUT_AGG_CSV LABEL"""
import sys, pandas as pd, numpy as np
st, si, nt, ni, out, lab = sys.argv[1:7]
keys = ["stand_id", "state", "regime", "inv_year", "age0", "site_index_ft", "fortypcd", "n_trees"]
A = pd.read_csv(si); B = pd.read_csv(ni)
A = A[A.state.isin(B.state.unique())]
k = [c for c in keys if c in A.columns and c in B.columns]
same = len(A) == len(B) and A[k].reset_index(drop=True).equals(B[k].reset_index(drop=True))
print(f"{lab} stand set identity on {k}: {'IDENTICAL' if same else 'DIFFERENT'} ({len(A)} vs {len(B)} stands)")
cols = ["stand_id", "scenario", "arm", "year_offset", "merch_vol_m3ha", "tot_vol_m3ha", "c_abg_live_MgCha", "ba", "tpa"]
S = pd.read_csv(st, usecols=cols + ["state"]); S = S[(S.scenario == "no_harvest") & S.state.isin(B.state.unique())]
N = pd.read_csv(nt, usecols=cols + ["state"]); N = N[N.scenario == "no_harvest"]
for arm in sorted(N.arm.unique()):
    if arm not in ("calibrated", "default"):
        continue
    m = S[S.arm == arm].merge(N[N.arm == arm], on=["stand_id", "year_offset"], suffixes=("_s", "_n"), how="outer", indicator=True)
    print(f"{lab} arm {arm}: rows sept {int((S.arm==arm).sum())} new {int((N.arm==arm).sum())} unmatched {int((m._merge!='both').sum())}")
    for v in ["merch_vol_m3ha", "tot_vol_m3ha", "c_abg_live_MgCha", "ba", "tpa"]:
        print(f"   max abs diff {v}: {np.nanmax(np.abs(m[v+'_s'] - m[v+'_n'])):.6g}")
g = N.groupby(["state", "arm", "year_offset"]).agg(n_stands=("stand_id", "nunique"), merch_vol_m3ha=("merch_vol_m3ha", "mean"),
    tot_vol_m3ha=("tot_vol_m3ha", "mean"), c_abg_live_MgCha=("c_abg_live_MgCha", "mean"), ba=("ba", "mean"), tpa=("tpa", "mean")).reset_index()
g["run"] = lab; g.to_csv(out, index=False)
print(g[g.year_offset.isin([0, 25, 50])].round(2).to_string(index=False))
