#!/usr/bin/env python3
"""aggregate_WA_csv.py — turn the per-plot results/plot_<id>.csv files into a wide table.

Each per-plot CSV has long format: plot_id, year, TotalBiomass_gm2
We pivot to wide: plot_id, BIOM_yr0, BIOM_yr5, ..., BIOM_yr100 in Mg/ha.
"""
import argparse, csv, glob, os, sys
from collections import defaultdict

GM2_TO_MGHA = 0.01

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--results-dir", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--years", default="0,5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95,100")
    args = p.parse_args()
    years = [int(y) for y in args.years.split(",")]
    files = sorted(glob.glob(os.path.join(args.results_dir, "plot_*.csv")))
    rows = []
    for f in files:
        with open(f) as fp:
            rdr = csv.DictReader(fp)
            data = {int(r["year"]): float(r["TotalBiomass_gm2"]) for r in rdr}
        pid = os.path.basename(f).replace("plot_", "").replace(".csv", "")
        row = {"plot_id": pid}
        ok = True
        for y in years:
            v = data.get(y)
            if v is None: ok = False; break
            row[f"BIOM_yr{y}"] = round(v * GM2_TO_MGHA, 3)
        if ok: rows.append(row)
    print(f"Wrote {len(rows)} plots from {len(files)} files", file=sys.stderr)
    with open(args.out, "w", newline="") as fp:
        w = csv.DictWriter(fp, fieldnames=["plot_id"] + [f"BIOM_yr{y}" for y in years])
        w.writeheader(); w.writerows(rows)

if __name__ == "__main__":
    main()
