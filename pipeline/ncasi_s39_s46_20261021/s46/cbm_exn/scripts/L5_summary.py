"""s46 Track L step 5 aggregate summary (state level aggregates only)."""
import pandas as pd, numpy as np
O = "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s46/cbm_exn/out/L5"
rt, cs, ng, ex, nd, xc = [], [], [], [], [], []
for st in ["ME", "NH", "VT", "MI", "WI", "MN"]:
    R = pd.read_csv(f"{O}/roundtrip_rows_{st}.csv"); r0 = R[R.t == 0]
    tst = r0[r0.inv_age >= 2]; fail = tst.rel_err_mo.abs() > 0.02
    strata = tst.assign(f=fail).groupby("ft").f.any()
    A = r0.area.sum(); y = r0[r0.inv_age <= 20]; ty = y[y.inv_age >= 2]
    s1 = R[(R.t == 1) & (R.inv_age >= 2)]
    rt.append(dict(state=st, strata=len(strata), strata_pass=int((~strata).sum()), rows_tested=len(tst), rows_fail=int(fail.sum()),
                   fail_area_share_all=float(tst[fail].area.sum() / A), fail_area_share_age1_20=float(ty[ty.rel_err_mo.abs() > 0.02].area.sum() / y.area.sum()),
                   max_abs_rel_t0=float(tst.rel_err_mo.abs().max()), max_abs_rel_step1=float(s1.rel_err_mo.abs().max()),
                   max_abs_rel_steps1_10=float(R[(R.t > 0) & (R.inv_age >= 2)].rel_err_mo.abs().max()),
                   max_abs_rel_foliage_t0=float(tst.rel_err_fol.abs().max()), max_abs_rel_merch_t0=float(((tst.merch_C - tst.comp_merch_C).abs() / tst.comp_merch_C.where(tst.comp_merch_C > 0)).max()),
                   age1_rows=int((r0.inv_age == 1).sum()), age1_area_share=float(r0[r0.inv_age == 1].area.sum() / A), neg_pools=int(R.neg_pool.sum()),
                   occupied_ages=int(r0.inv_age.nunique()), age_max=int(r0.inv_age.max())))
    c = pd.read_csv(f"{O}/component_sum_{st}.csv"); cs.append(dict(state=st, max_rel_sum_err=float(c.max_rel_sum_err.max()), all_ok=bool(c.sum_ok.all())))
    n = pd.read_csv(f"{O}/negative_increments_{st}.csv"); ng.append(n)
    e = pd.read_csv(f"{O}/spinup_extrap_{st}.csv"); ex.append(e)
    d = pd.read_csv(f"{O}/share_nodes_{st}.csv"); nd.append(d.groupby(["ft"]).agg(n_nodes=("aclass", "size"), src=("src", lambda s: ",".join(sorted(set(s))))).reset_index().assign(state=st))
    sm = pd.read_csv(f"{O}/merch_share_curve_{st}.csv", index_col=0); dd = sm.diff().abs()
    xc.append(dict(state=st, max_annual_change_merch_share=float(dd.max().max()), merch_share_age1_min=float(sm.loc[1].min()), merch_share_age1_max=float(sm.loc[1].max()),
                   merch_share_age100_min=float(sm.loc[100].min()), merch_share_age100_max=float(sm.loc[100].max())))
    xe = pd.read_csv(f"{O}/excluded_{st}.csv"); rt[-1].update(excluded=xe.excluded_types.iloc[0], excluded_area_share=float(xe.excluded_area.iloc[0] / xe.total_area.iloc[0]))
pd.set_option("display.width", 300); pd.set_option("display.max_columns", 40)
RT = pd.DataFrame(rt); print(RT.T.to_string()); RT.to_csv(f"{O}/../L5_roundtrip_summary_by_state.csv", index=False)
print(pd.DataFrame(cs).to_string()); print(pd.DataFrame(xc).round(4).to_string())
N = pd.concat(ng); N.to_csv(f"{O}/../L5_negative_increments_all.csv", index=False)
print(N.groupby(["state", "component"])[["n_neg_outside_decline", "n_neg_outside_decline_age1_20", "n_neg_in_decline"]].sum().unstack().to_string())
print(N[N.n_neg_outside_decline > 0][["state", "ft", "component", "n_neg_outside_decline", "ages_neg_outside", "min_neg_inc_outside"]].to_string())
E = pd.concat(ex)
E2 = E.groupby(["state", "ft", "group"]).apply(lambda x: pd.Series(dict(max_supported_age=int(x.max_supported_age.iloc[0]), area=x.area.sum(),
        share_spinup_years_beyond=float((x.years_beyond_support * x.area).sum() / (x.spinup_growth_years * x.area).sum()),
        share_rows_age_beyond=float(x[x.inv_age > x.max_supported_age].area.sum() / x.area.sum()), years_beyond_K=float(x.years_beyond_K.sum()),
        mean_growth_years=float((x.spinup_growth_years * x.area).sum() / x.area.sum())))).reset_index()
E2.to_csv(f"{O}/../L5_spinup_extrapolation_by_stratum.csv", index=False); print(E2.round(4).to_string())
Es = E.groupby("state").apply(lambda x: pd.Series(dict(share_spinup_years_beyond=float((x.years_beyond_support * x.area).sum() / (x.spinup_growth_years * x.area).sum()),
        inv_area_beyond_support=float(x[x.inv_age > x.max_supported_age].area.sum() / x.area.sum()), min_sup=int(x.max_supported_age.min()), max_sup=int(x.max_supported_age.max()),
        years_beyond_K=float(x.years_beyond_K.sum()), growth_years_min=float(x.spinup_growth_years.min()), growth_years_max=float(x.spinup_growth_years.max()))))
print(Es.round(4).to_string()); print(pd.concat(nd).to_string())
