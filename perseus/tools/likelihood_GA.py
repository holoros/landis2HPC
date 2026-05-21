#!/usr/bin/env python3
"""likelihood_GA.py — log-likelihood of GA LANDIS predictions vs FIA observed.

Reads per_plot.csv (plot_id, year, biomass_Mg_ha) and untreated_plots_GA.csv
(PLOT, FIRST_INVYR, BIOM_<year>_Mgha for each cycle).

LANDIS sim year N -> FIA calendar year (FIRST_INVYR + N) -> matches BIOM_<year>_Mgha
when that column exists for that plot.

LL = sum over all (plot, sim_yr) cells of log-normal density:
     log L = -0.5 * (log obs - log pred)^2 / sigma^2 - log(sigma) - log(obs) - 0.5*log(2pi)
"""
import argparse, math
import pandas as pd
import numpy as np

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--pred", required=True)
    p.add_argument("--obs", required=True)
    p.add_argument("--sigma", type=float, default=0.20)
    args = p.parse_args()

    pred = pd.read_csv(args.pred)  # plot_id, year, biomass_Mg_ha
    obs = pd.read_csv(args.obs)    # PLOT, FIRST_INVYR, BIOM_<year>_Mgha
    obs["PLOT"] = obs["PLOT"].astype(int)
    obs["FIRST_INVYR"] = pd.to_numeric(obs["FIRST_INVYR"], errors="coerce").astype("Int64")
    pred["plot_id"] = pred["plot_id"].astype(int)

    # Map cycle years to LANDIS sim year (5-yr increments)
    biom_cols = [c for c in obs.columns if c.startswith("BIOM_") and c.endswith("_Mgha")]
    obs_years = sorted(int(c.split("_")[1]) for c in biom_cols)

    sigma = args.sigma
    cells = []
    for _, prow in pred.iterrows():
        pid = int(prow["plot_id"])
        sim_yr = int(prow["year"])
        pred_v = float(prow["biomass_Mg_ha"])
        if pred_v <= 0:
            continue
        # Find matching observation
        match = obs[obs["PLOT"] == pid]
        if len(match) == 0:
            continue
        invyr = match["FIRST_INVYR"].iloc[0]
        if pd.isna(invyr):
            continue
        target_yr = int(invyr) + sim_yr
        col = f"BIOM_{target_yr}_Mgha"
        if col not in obs.columns:
            continue
        obs_v = match[col].iloc[0]
        if pd.isna(obs_v) or obs_v <= 0:
            continue
        z = math.log(pred_v) - math.log(float(obs_v))
        ll = -0.5*(z/sigma)**2 - math.log(sigma) - math.log(float(obs_v)) - 0.5*math.log(2*math.pi)
        cells.append((pid, sim_yr, target_yr, z, ll))

    df = pd.DataFrame(cells, columns=["plot_id","sim_yr","obs_yr","log_resid","ll_cell"])
    total = df["ll_cell"].sum()
    n = len(df)
    by_yr = df.groupby("sim_yr").agg(
        n=("ll_cell","size"),
        mean_resid=("log_resid","mean"),
        std_resid=("log_resid","std"),
    ).reset_index()
    print(f"=== GA likelihood ===")
    print(f"  log-likelihood (sum): {total:.4f}")
    print(f"  n cells:              {n}")
    print(f"  ll per cell (mean):   {total/n if n else 0:.4f}")
    print(f"  sigma:                {sigma}")
    print(f"\nResidual (log pred - log obs) by sim year:")
    print(by_yr.to_string(index=False))
    print(f"\nLL_NUMERIC: {total:.4f}")

if __name__ == "__main__":
    main()
