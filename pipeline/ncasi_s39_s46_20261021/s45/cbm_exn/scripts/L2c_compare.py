"""s45 Track L null test, part c: compare the registered scorer's ratios on the cbm_exn replay with the registered v4 gate results (tolerance 0.01, plan v2 L2, v5 item 2)."""
import sys, pandas as pd, numpy as np
A = pd.read_csv("/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/cbm/rerun_v2_20261015/cbm_gate_results_v4_20261015.csv").set_index("state")
B = pd.read_csv(sys.argv[1] + "/cbm_gate_results_v4_20261015.csv"); B = B[B.variant == "noharv"].set_index("state")
rows = []
for st in ["ME", "NH", "VT", "MI", "WI", "MN"]:
    if st not in B.index: rows.append(dict(state=st, status="missing")); continue
    for c in ["ratio_stock", "ratio_gross", "ratio_mort", "ratio_net", "ratio_stock_woody", "ratio_grossB", "ratio_mortB"]:
        d = B.loc[st, c] - A.loc[st, c]
        rows.append(dict(state=st, ratio=c, registered=A.loc[st, c], cbm_exn=B.loc[st, c], diff=d, gate_quantity=c in ["ratio_stock", "ratio_gross", "ratio_mort", "ratio_net"],
                         within_0_01=bool(abs(d) <= 0.01)))
R = pd.DataFrame(rows); R.to_csv(sys.argv[2], index=False)
pd.set_option("display.width", 200); print(R.round(5).to_string())
g = R[R.gate_quantity == True]
print("NULL TEST (4 gate ratios x 6 states within 0.01):", "PASS" if g.within_0_01.all() else "FAIL", int(g.within_0_01.sum()), "of", len(g))
