#!/usr/bin/env python3
"""likelihood_WA.py — log-likelihood of LANDIS predictions vs FIA observed.

We map each plot's WA Tier-0 trajectory year y (=2001 + y, since IC year is 2001)
against FIA observed columns BIOM_<year>_Mgha in untreated_plots_WA.csv.

Uses log-residuals: r = log(pred) - log(obs). Assume Normal residuals with σ
estimated as sample stddev. LL = sum -0.5*(r/σ)^2 - log(σ) - log(sqrt(2π)).
"""
import argparse, csv, math, sys

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--pred", required=True, help="per_plot.csv from aggregate_WA_per_plot.py")
    p.add_argument("--obs", required=True, help="untreated_plots_WA.csv")
    p.add_argument("--summary-csv", required=True, help="plot_to_ecoregion_WA._summary.csv to get plt_cn/plot_id map")
    p.add_argument("--out-residuals", default=None)
    p.add_argument("--ic-year", type=int, default=None, help="LANDIS year 0 corresponds to this calendar year (overrides per-plot FIRST_INVYR if set)")
    args = p.parse_args()

    # Load plt_cn -> (observed BIOM_yyyy_Mgha dict, invyr)
    obs = {}
    cn_to_invyr = {}
    obs_years = set()
    with open(args.obs) as f:
        rdr = csv.DictReader(f)
        for r in rdr:
            cn = r.get("FIRST_PLTCN", "").strip()
            try: invyr = int(r.get("FIRST_INVYR", "") or 0)
            except: invyr = 0
            biom_yrs = {}
            for k, v in r.items():
                if k.startswith("BIOM_") and k.endswith("_Mgha") and v not in ("", None):
                    try:
                        yr = int(k.split("_")[1])
                        b = float(v)
                        if b > 0:
                            biom_yrs[yr] = b
                            obs_years.add(yr)
                    except: pass
            if biom_yrs and cn:
                obs[cn] = biom_yrs
                cn_to_invyr[cn] = invyr

    # Load plot_id -> plt_cn (summary csv has plt_cn first col, plot_id second)
    pid_to_cn = {}
    with open(args.summary_csv) as f:
        for r in csv.DictReader(f):
            pid_to_cn[r["plot_id"]] = r["plt_cn"].strip()

    # Load predictions
    pred = {}
    with open(args.pred) as f:
        rdr = csv.DictReader(f)
        for r in rdr:
            pid = r["plot_id"]
            yrs = {}
            for k, v in r.items():
                if k.startswith("BIOM_yr"):
                    try: yrs[int(k[7:])] = float(v)
                    except: pass
            pred[pid] = yrs

    # Build paired (obs, pred) per plot_id at each LANDIS year
    # Use per-plot FIRST_INVYR for IC year unless overridden
    pairs = []
    n_skipped_invyr = 0
    for pid, yrs_pred in pred.items():
        cn = pid_to_cn.get(pid)
        if not cn or cn not in obs:
            continue
        plot_ic_year = args.ic_year if args.ic_year else cn_to_invyr.get(cn, 0)
        if plot_ic_year <= 0:
            n_skipped_invyr += 1
            continue
        for y_landis, p_val in yrs_pred.items():
            cal_year = plot_ic_year + y_landis
            o = obs[cn].get(cal_year)
            if o is None or o <= 0 or p_val <= 0:
                continue
            pairs.append((pid, plot_ic_year, cal_year, p_val, o, math.log(p_val) - math.log(o)))
    if n_skipped_invyr:
        print(f"Skipped {n_skipped_invyr} plots with missing invyr", file=sys.stderr)

    if not pairs:
        print("No paired observations found", file=sys.stderr)
        sys.exit(1)

    resids = [pair[5] for pair in pairs]
    mean = sum(resids) / len(resids)
    var = sum((r - mean)**2 for r in resids) / max(len(resids) - 1, 1)
    sigma = math.sqrt(var) if var > 0 else 1e-6
    ll = sum(-0.5 * ((r - mean)/sigma)**2 - math.log(sigma) - 0.5*math.log(2*math.pi) for r in resids)

    print(f"Cells paired: {len(pairs)}")
    print(f"Unique plots paired: {len(set(p[0] for p in pairs))}")
    print(f"Mean log-residual: {mean:.4f}")
    print(f"Stddev log-residual: {sigma:.4f}")
    print(f"Log-likelihood: {ll:.2f}")

    if args.out_residuals:
        with open(args.out_residuals, "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["plot_id", "invyr", "cal_year", "pred_Mgha", "obs_Mgha", "log_resid"])
            for row in pairs: w.writerow(row)

if __name__ == "__main__":
    main()
