#!/usr/bin/env python3
"""apply_theta_uniform_GA.py — multiply ANPPmax and BiomassMax in GA SspEcoregionData by a uniform theta.

Usage:
  python3 apply_theta_uniform_GA.py --theta 1.10 \
    --baseline /fs/scratch/.../states/GA/inputs/SppEcoregionData.csv \
    --out /fs/scratch/.../states/GA/perseus/bayesian/GA_t1_x110/SppEcoregionData_t1_x110.csv
"""
import argparse, csv

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--theta", type=float, required=True)
    p.add_argument("--baseline", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()
    n = 0
    with open(args.baseline) as fin, open(args.out, "w", newline="") as fout:
        reader = csv.DictReader(fin)
        writer = csv.DictWriter(fout, fieldnames=reader.fieldnames)
        writer.writeheader()
        for row in reader:
            try:
                anpp = float(row["ANPPmax"]); bmax = float(row["BiomassMax"])
                row["ANPPmax"] = f"{anpp * args.theta:.0f}"
                row["BiomassMax"] = f"{bmax * args.theta:.0f}"
            except (KeyError, ValueError):
                pass
            writer.writerow(row)
            n += 1
    print(f"Wrote {n} rows scaled by theta={args.theta}")

if __name__ == "__main__":
    main()
