#!/usr/bin/env python3
"""apply_theta_GA_perspecies.py — write θ-scaled SppEcoregionData.csv for GA."""
import argparse, csv, sys

SPECIES_GA = ["AE", "BC", "BE", "BG", "BO", "BSW", "CO", "EH", "ERC", "HK",
              "LL", "LO", "MG", "PO", "RM", "RO", "SL", "SM", "SO", "SP",
              "SY", "TT", "VP", "WAO", "WAS", "WO", "YB"]
N = len(SPECIES_GA)  # 27

def read_theta(path):
    mult = {}
    with open(path) as f:
        rdr = csv.DictReader(f)
        if rdr.fieldnames and "param" in rdr.fieldnames and "value" in rdr.fieldnames:
            for row in rdr:
                mult[row["param"]] = float(row["value"])
        else:
            f.seek(0)
            vals = [float(line.strip()) for line in f if line.strip()]
            assert len(vals) == 2 * N, f"Expected {2*N} values, got {len(vals)}"
            for sp, v in zip(SPECIES_GA, vals[:N]):
                mult[f"ANPP_{sp}"] = v
            for sp, v in zip(SPECIES_GA, vals[N:]):
                mult[f"BMAX_{sp}"] = v
    return mult

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--theta-csv", required=True)
    p.add_argument("--baseline-spp", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()
    mult = read_theta(args.theta_csv)
    expected = {f"ANPP_{s}" for s in SPECIES_GA} | {f"BMAX_{s}" for s in SPECIES_GA}
    missing = expected - mult.keys()
    if missing:
        sys.stderr.write(f"Missing multipliers: {sorted(missing)}\n"); sys.exit(1)
    with open(args.baseline_spp) as f, open(args.out, "w", newline="") as g:
        rdr = csv.DictReader(f)
        w = csv.DictWriter(g, fieldnames=rdr.fieldnames); w.writeheader()
        for r in rdr:
            sp = r["SpeciesCode"]
            try:
                r["ANPPmax"] = str(int(round(float(r["ANPPmax"]) * mult.get(f"ANPP_{sp}", 1.0))))
                r["BiomassMax"] = str(int(round(float(r["BiomassMax"]) * mult.get(f"BMAX_{sp}", 1.0))))
            except: pass
            w.writerow(r)

if __name__ == "__main__":
    main()
