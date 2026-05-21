#!/usr/bin/env python3
"""
likelihood.py

Compute the log-likelihood of an FIA observation set given a per-plot
LANDIS biomass output CSV. Used as the objective for CMA-ES and the
ABC summary statistic.

Likelihood model:
    log y_obs(plot, year)  ~  Normal( log y_pred(plot, year), sigma )

where y is state-expanded MMT contribution at FIA cycles 6/7/8 (years 2008/2013/2018).
sigma combines FIA standard error and LANDIS stochasticity (default 0.20 = ~20% relative).

Usage:
    python3 likelihood.py --pred per_plot.csv --obs untreated_plots.csv --sigma 0.20
"""

import argparse
import math
import sys
import pandas as pd
import numpy as np


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--pred",  required=True, help="per_plot biomass CSV (plot_id,year,state_mmt)")
    p.add_argument("--obs",   required=True, help="FIA observed plot list (PLOT, CYCLE5..8 MMT)")
    p.add_argument("--sigma", type=float, default=0.20,
                   help="Log-normal observation noise (default 0.20)")
    p.add_argument("--out",   default=None, help="Optional CSV with per-plot residuals")
    p.add_argument("--summary-only", action="store_true",
                   help="Print only the scalar log-likelihood")
    args = p.parse_args()

    pred = pd.read_csv(args.pred)
    pred = pred[pred.year.isin([5, 10, 15])].copy()
    pred_w = pred.pivot_table(index="plot_id", columns="year",
                               values="state_mmt").reset_index()
    pred_w.columns = ["plot_id", "pred_2008", "pred_2013", "pred_2018"]

    obs = pd.read_csv(args.obs)
    obs = obs[["PLOT", "CYCLE6_MMT", "CYCLE7_MMT", "CYCL85_MMT"]].rename(
        columns={"PLOT": "plot_id",
                 "CYCLE6_MMT": "obs_2008",
                 "CYCLE7_MMT": "obs_2013",
                 "CYCL85_MMT": "obs_2018"})

    m = obs.merge(pred_w, on="plot_id")

    # Log-normal likelihood with stdev sigma on log scale.
    #   log L = -0.5 * (log obs - log pred)^2 / sigma^2  - log(sigma) - log(obs) - 0.5*log(2pi)
    # We sum across all (plot, year) cells where both > 0.
    sigma = args.sigma
    cells = []
    for yr in [2008, 2013, 2018]:
        ok = (m[f"obs_{yr}"] > 0) & (m[f"pred_{yr}"] > 0) & m[f"pred_{yr}"].notna()
        sub = m[ok]
        log_obs = np.log(sub[f"obs_{yr}"].values)
        log_pred = np.log(sub[f"pred_{yr}"].values)
        z = log_obs - log_pred
        ll_cells = -0.5 * (z / sigma) ** 2 - math.log(sigma) - log_obs - 0.5 * math.log(2 * math.pi)
        cells.extend([(p, yr, lo, lp, ll)
                      for p, lo, lp, ll in zip(sub["plot_id"].values, log_obs, log_pred, ll_cells)])

    df = pd.DataFrame(cells, columns=["plot_id", "year", "log_obs", "log_pred", "ll_cell"])
    total_ll = df["ll_cell"].sum()
    n_cells = len(df)

    # Summary statistics for ABC
    df["resid"] = df["log_pred"] - df["log_obs"]
    by_year = df.groupby("year")["resid"].agg(["mean", "std", "count"]).reset_index()

    if args.summary_only:
        print(f"{total_ll:.4f}")
    else:
        print(f"=== likelihood ===")
        print(f"  log-likelihood (sum):  {total_ll:.4f}")
        print(f"  n cells:               {n_cells}")
        print(f"  ll per cell (mean):    {total_ll / n_cells:.4f}")
        print(f"\nResidual (log pred - log obs) by year:")
        print(by_year.to_string(index=False))

    if args.out:
        df.to_csv(args.out, index=False)
        sys.stderr.write(f"Wrote per-cell residuals to {args.out}\n")


if __name__ == "__main__":
    main()
