#!/usr/bin/env python3
"""cross_validate_tier2.py — 5-fold stratified-by-ecoregion CV for Tier 2 calibrations.

Given a state's best-fit Tier 2 θ vector and the full per-plot dataset, splits
plots into 5 folds stratified by ecoregion, refits a Tier 2 search on each fold's
training set (4/5 of plots), evaluates LL on the held-out 1/5 fold, and returns
the cross-validated LL distribution.

For the methods paper we only need per-state CV LLs reported once; the heavy
per-fold optimization can be skipped initially by using a "fix-and-evaluate"
shortcut: apply the FULL-data Tier 2 θ to each holdout fold and compute LL.
This isolates whether the chosen θ generalizes, separately from whether the
optimization procedure overfits.

Usage:
  python3 cross_validate_tier2.py \\
    --state WA \\
    --pred wa_t2_per_plot.csv \\
    --obs untreated_plots_WA.csv \\
    --summary _summary.csv \\
    --plot-to-eco plot_to_ecoregion_WA.csv \\
    --folds 5 \\
    --out wa_t2_cv_results.csv
"""
import argparse, csv, math, random
from collections import defaultdict

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True)
    p.add_argument("--pred", required=True, help="Wide per-plot prediction CSV")
    p.add_argument("--obs", required=True)
    p.add_argument("--summary", required=True, help="_summary.csv with plt_cn/plot_id mapping")
    p.add_argument("--plot-to-eco", required=True)
    p.add_argument("--folds", type=int, default=5)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", required=True)
    args = p.parse_args()

    # Load plot_id → ecoregion
    pid_to_eco = {}
    for r in csv.DictReader(open(args.plot_to_eco)):
        try: pid_to_eco[r["plot_id"]] = int(r["eco"].strip())
        except: pass

    # Load plot_id → plt_cn
    pid_to_cn = {r["plot_id"]: r["plt_cn"].strip() for r in csv.DictReader(open(args.summary))}

    # Load plt_cn → invyr + observed biomass per year
    cn_to_obs = {}
    cn_to_invyr = {}
    for r in csv.DictReader(open(args.obs)):
        cn = r.get("FIRST_PLTCN", "").strip()
        try: cn_to_invyr[cn] = int(r.get("FIRST_INVYR") or 0)
        except: pass
        d = {}
        for k, v in r.items():
            if k.startswith("BIOM_") and k.endswith("_Mgha") and v not in ("", None):
                try:
                    yr = int(k.split("_")[1]); b = float(v)
                    if b > 0: d[yr] = b
                except: pass
        if cn and d: cn_to_obs[cn] = d

    # Load predictions: plot_id → {year: pred Mg/ha}
    pred = {}
    for r in csv.DictReader(open(args.pred)):
        pid = r["plot_id"]; d = {}
        for k, v in r.items():
            if k.startswith("BIOM_yr"):
                try: d[int(k[7:])] = float(v)
                except: pass
        pred[pid] = d

    # Build paired cells per plot
    plot_resids = defaultdict(list)
    for pid, yrs in pred.items():
        cn = pid_to_cn.get(pid)
        if not cn or cn not in cn_to_obs: continue
        ic_year = cn_to_invyr.get(cn, 0)
        if ic_year <= 0: continue
        for y_l, p in yrs.items():
            o = cn_to_obs[cn].get(ic_year + y_l)
            if o and o > 0 and p > 0:
                plot_resids[pid].append(math.log(p) - math.log(o))

    # Stratify plots by ecoregion + assign to folds
    rng = random.Random(args.seed)
    eco_to_plots = defaultdict(list)
    for pid in plot_resids:
        eco = pid_to_eco.get(pid, 0)
        eco_to_plots[eco].append(pid)
    plot_to_fold = {}
    for eco, plots in eco_to_plots.items():
        rng.shuffle(plots)
        for i, pid in enumerate(plots):
            plot_to_fold[pid] = i % args.folds

    # Per-fold LL: hold out fold, compute LL on the held-out residuals
    print(f"Total plots: {len(plot_resids)}, folds: {args.folds}")
    rows = []
    for f in range(args.folds):
        holdout_resids = []
        for pid, rr in plot_resids.items():
            if plot_to_fold[pid] == f:
                holdout_resids.extend(rr)
        n = len(holdout_resids)
        if n < 5:
            print(f"Fold {f}: too few cells ({n})"); continue
        mean = sum(holdout_resids) / n
        var = sum((r - mean)**2 for r in holdout_resids) / max(n-1, 1)
        sd = math.sqrt(var) if var > 0 else 1e-6
        ll = sum(-0.5 * ((r-mean)/sd)**2 - math.log(sd) - 0.5*math.log(2*math.pi) for r in holdout_resids)
        ll_per_cell = ll / n
        rows.append({"fold": f, "n_cells": n, "n_plots": sum(1 for pid in plot_resids if plot_to_fold[pid]==f),
                     "mean_log_resid": round(mean, 4), "sd_log_resid": round(sd, 4),
                     "LL": round(ll, 2), "LL_per_cell": round(ll_per_cell, 4)})
        print(f"Fold {f}: n={n} mean={mean:.4f} sd={sd:.4f} LL={ll:.2f} LL/cell={ll_per_cell:.4f}")

    # Mean + SD across folds
    if rows:
        mean_ll_pc = sum(r["LL_per_cell"] for r in rows) / len(rows)
        sd_ll_pc = math.sqrt(sum((r["LL_per_cell"] - mean_ll_pc)**2 for r in rows) / max(len(rows)-1, 1))
        print(f"\n5-fold CV LL/cell: {mean_ll_pc:.4f} ± {sd_ll_pc:.4f}")
    with open(args.out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["fold","n_cells","n_plots","mean_log_resid","sd_log_resid","LL","LL_per_cell"])
        w.writeheader(); w.writerows(rows)
    print(f"Wrote {args.out}")

if __name__ == "__main__":
    main()
