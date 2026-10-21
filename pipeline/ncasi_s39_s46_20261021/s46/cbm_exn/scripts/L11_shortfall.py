"""s46 Track L v7 L11 evidence: pre-shift (shift 0) t0 shortfall of cbm_exn AG vs CBM3 per stratum (ft, eco, own) over one year's increment I(a); shifts 1 and 2 for contrast."""
import pandas as pd, numpy as np
O = "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out"
rows = []
for st in ["ME", "NH", "VT", "MI", "WI", "MN"]:
    for s in (0, 1, 2):
        d = pd.read_csv(f"{O}/null_shift{s}/t0_rows_{st}.csv"); d["short"] = d.cbm3_ag - d.exn_ag
        g = d[(d.age >= 2) & (d.inc_ag_age_a.abs() > 1e-9)].copy(); g["r"] = g.short / g.inc_ag_age_a
        sa = g.groupby(["ft", "eco", "own"]).apply(lambda x: (x.r * x.area).sum() / x.area.sum())
        a1 = d[d.age == 1]
        rows.append(dict(state=st, shift=s, n_strata=len(sa), n_rows=len(g), stratum_aw_min=sa.min(), stratum_aw_max=sa.max(), row_min=g.r.min(), row_max=g.r.max(),
                         stock_short_share=d.short.mul(d.area).sum() / d.cbm3_ag.mul(d.area).sum(), age1_rows=len(a1), age1_area_share=a1.area.sum() / d.area.sum(),
                         n_rows_inc0=int(((d.age >= 2) & (d.inc_ag_age_a.abs() <= 1e-9)).sum())))
R = pd.DataFrame(rows); R.to_csv(f"{O}/L11_preshift_shortfall_by_state.csv", index=False)
pd.set_option("display.width", 250); print(R.round(6).to_string())
