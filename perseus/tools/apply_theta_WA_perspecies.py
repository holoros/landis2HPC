#!/usr/bin/env python3
"""apply_theta_WA_perspecies.py — write θ-scaled SppEcoregionData.csv with per-species multipliers.

Theta vector format (50 entries):
  [ANPP_DF, ANPP_WH, ..., ANPP_GO, BMAX_DF, ..., BMAX_GO]
"""
import argparse, csv, sys

SPECIES_WA = ["DF", "WH", "WC", "PSF", "GF", "NF", "SS", "ES", "AF", "WF",
              "LP", "PP", "WP", "WBP", "MH", "WL", "IC", "PY", "BM", "RA",
              "PM", "PB", "QA", "BCW", "GO"]
N_SPECIES = len(SPECIES_WA)

def read_theta(path):
    mult = {}
    with open(path) as f:
        reader = csv.DictReader(f)
        if reader.fieldnames and "param" in reader.fieldnames and "value" in reader.fieldnames:
            for row in reader:
                mult[row["param"]] = float(row["value"])
        else:
            f.seek(0)
            vals = [float(line.strip()) for line in f if line.strip()]
            assert len(vals) == 2 * N_SPECIES, f"Expected {2*N_SPECIES} values, got {len(vals)}"
            for sp, v in zip(SPECIES_WA, vals[:N_SPECIES]):
                mult[f"ANPP_{sp}"] = v
            for sp, v in zip(SPECIES_WA, vals[N_SPECIES:]):
                mult[f"BMAX_{sp}"] = v
    return mult

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--theta-csv", required=True)
    p.add_argument("--baseline-spp", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()
    mult = read_theta(args.theta_csv)
    expected = {f"ANPP_{s}" for s in SPECIES_WA} | {f"BMAX_{s}" for s in SPECIES_WA}
    missing = expected - mult.keys()
    if missing:
        sys.stderr.write(f"Missing multipliers: {sorted(missing)}\n")
        sys.exit(1)
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
