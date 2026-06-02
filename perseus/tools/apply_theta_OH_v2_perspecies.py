#!/usr/bin/env python3
"""apply_theta_OH_perspecies.py — write theta-scaled SppEcoregionData.csv for Ohio.

v2 (2026-06-02): species pool extended from 23 to 25; added COTT (eastern cottonwood)
and SIM (silver maple) to address the IN per-plot LL outlier from bottomland species
being lumped to upland counterparts (cottonwood -> QA, silver maple -> RM). See
docs/indiana_ll_outlier_analysis.md for the audit.

Theta vector format (50 entries): [ANPP_WO..ANPP_SIM, BMAX_WO..BMAX_SIM].
"""
import argparse, csv, sys

SPECIES_OH = ["WO", "NRO", "BO", "POST", "SHO", "SHA_HK", "MOK_HK", "SM",
              "RM", "YP", "BE", "WAS", "BAS", "BSW", "WALN", "SWEETGUM",
              "BLACKGUM", "SYC", "SASSAFRAS", "DOGWOOD", "EWP", "QA", "AE",
              "COTT", "SIM"]
N_SPECIES = len(SPECIES_OH)

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
            for sp, v in zip(SPECIES_OH, vals[:N_SPECIES]):
                mult[f"ANPP_{sp}"] = v
            for sp, v in zip(SPECIES_OH, vals[N_SPECIES:]):
                mult[f"BMAX_{sp}"] = v
    return mult

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--theta-csv", required=True)
    p.add_argument("--baseline-spp", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()
    mult = read_theta(args.theta_csv)
    expected = {f"ANPP_{s}" for s in SPECIES_OH} | {f"BMAX_{s}" for s in SPECIES_OH}
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
