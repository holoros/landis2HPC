"""s46 Track L null test compare: registered scorer ratios on the cbm_exn replay vs cbm_gate_results_v4_20261015.csv.
Registered criterion (v6 L3, v7 L14): all 24 gate ratios (stock, gross, mort, net x 6 states) within 0.01 AND largest absolute difference < 1e-3.
usage: python L2_compare.py OUTDIR CSV LABEL"""
import sys, pandas as pd, numpy as np
A = pd.read_csv("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/rerun_v2_20261015/cbm_gate_results_v4_20261015.csv").set_index("state")
B = pd.read_csv(sys.argv[1] + "/cbm_gate_results_v4_20261015.csv"); B = B[B.variant == "noharv"].set_index("state")
rows = []
for st in ["ME", "NH", "VT", "MI", "WI", "MN"]:
    for c in ["ratio_stock", "ratio_gross", "ratio_mort", "ratio_net"]:
        if st not in B.index: rows.append(dict(state=st, ratio=c, registered=A.loc[st, c], cbm_exn=np.nan, diff=np.nan, within_0_01=False)); continue
        d = B.loc[st, c] - A.loc[st, c]
        rows.append(dict(state=st, ratio=c, registered=A.loc[st, c], cbm_exn=B.loc[st, c], diff=d, within_0_01=bool(abs(d) <= 0.01)))
R = pd.DataFrame(rows); R.to_csv(sys.argv[2], index=False)
pd.set_option("display.width", 200); print(R.to_string())
mx = float(R["diff"].abs().max()); n = int(R.within_0_01.sum())
ok = bool(R.within_0_01.all() and mx < 1e-3)
print(f"NULL {sys.argv[3]}: {n} of {len(R)} within 0.01; largest abs diff {mx:.3e}; registered criterion", "PASS" if ok else "FAIL")
