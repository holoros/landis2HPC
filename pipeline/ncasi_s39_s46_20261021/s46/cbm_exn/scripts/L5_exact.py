import pandas as pd
O = "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/L5"
for st in ["ME", "NH", "VT", "MI", "WI", "MN"]:
    R = pd.read_csv(f"{O}/roundtrip_rows_{st}.csv"); r = R[(R.t == 0) & (R.inv_age >= 2)]
    k = r.groupby(["ft", "eco", "own"]).rel_err_mo.apply(lambda x: x.abs().max())
    s1 = R[(R.t == 1) & (R.inv_age >= 2)]
    m = ((r.merch_C - r.comp_merch_C).abs() / r.comp_merch_C.where(r.comp_merch_C > 0)).max()
    print(st, "ft_eco_own strata", len(k), "pass", int((k <= 0.02).sum()), "t0 mo %.2e step1 %.2e foliage %.2e merch %.2e rows1_20 %d" % (r.rel_err_mo.abs().max(), s1.rel_err_mo.abs().max(), r.rel_err_fol.abs().max(), m, int((r.inv_age <= 20).sum())))
