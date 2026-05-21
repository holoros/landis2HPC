#!/usr/bin/env python3
"""
apply_theta_eco.py — Tier 1.5 of the Bayesian inverse parameterization.

Three multipliers (one per Maine ecoregion 58 / 59 / 82) on ANPPmax and
BiomassMax. Per-species variation NOT included (Tier 2).

Parameter file format:
  param,value
  ANPP_eco58,1.20
  ANPP_eco59,1.20
  ANPP_eco82,1.30
  BMAX_eco58,1.20
  BMAX_eco59,1.20
  BMAX_eco82,1.30

Usage:
  python3 apply_theta_eco.py --theta-csv theta_eco.csv \
      --baseline-spp /path/SppEcoregionData.csv \
      --out /path/SppEcoregionData_eco.csv
"""

import argparse
import csv
import sys

ECOREGIONS = ["58", "59", "82"]


def read_theta(path):
    multipliers = {}
    with open(path) as f:
        for row in csv.DictReader(f):
            multipliers[row["param"]] = float(row["value"])
    return multipliers


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--theta-csv",     required=True)
    p.add_argument("--baseline-spp",  required=True)
    p.add_argument("--out",           required=True)
    args = p.parse_args()

    mult = read_theta(args.theta_csv)
    expected = {f"{kind}_eco{eco}" for kind in ("ANPP", "BMAX") for eco in ECOREGIONS}
    missing = expected - mult.keys()
    if missing:
        sys.stderr.write(f"ERROR missing parameters: {missing}\n"); sys.exit(1)

    with open(args.baseline_spp) as fin, open(args.out, "w", newline="") as fout:
        reader = csv.DictReader(fin)
        writer = csv.DictWriter(fout, fieldnames=reader.fieldnames)
        writer.writeheader()
        n = 0
        for row in reader:
            eco = row["EcoregionName"].strip()
            if eco not in ECOREGIONS:
                writer.writerow(row); n += 1; continue
            try:
                anpp = float(row["ANPPmax"]); bmax = float(row["BiomassMax"])
            except (ValueError, KeyError):
                writer.writerow(row); n += 1; continue
            row["ANPPmax"]    = f"{anpp * mult[f'ANPP_eco{eco}']:.0f}"
            row["BiomassMax"] = f"{bmax * mult[f'BMAX_eco{eco}']:.0f}"
            writer.writerow(row); n += 1

    print(f"wrote {n} rows. Multipliers:")
    for eco in ECOREGIONS:
        print(f"  eco {eco}: ANPP×{mult[f'ANPP_eco{eco}']:.3f}  BMAX×{mult[f'BMAX_eco{eco}']:.3f}")


if __name__ == "__main__":
    main()
