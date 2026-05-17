#!/usr/bin/env python3
"""apply_theta_uniform_WA.py — write a θ-scaled SppEcoregionData.csv.

θ multiplies ANPPmax + BiomassMax uniformly across all species × ecoregions.
"""
import argparse, csv

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--in-csv", required=True)
    p.add_argument("--out-csv", required=True)
    p.add_argument("--theta", type=float, required=True)
    args = p.parse_args()
    with open(args.in_csv) as f, open(args.out_csv, "w", newline="") as g:
        rdr = csv.DictReader(f)
        fields = rdr.fieldnames
        w = csv.DictWriter(g, fieldnames=fields); w.writeheader()
        for r in rdr:
            try:
                r["ANPPmax"] = str(int(round(float(r["ANPPmax"]) * args.theta)))
                r["BiomassMax"] = str(int(round(float(r["BiomassMax"]) * args.theta)))
            except: pass
            w.writerow(r)

if __name__ == "__main__":
    main()
