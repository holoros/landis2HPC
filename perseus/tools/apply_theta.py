#!/usr/bin/env python3
"""
apply_theta.py

Take a Tier 1 parameter vector theta (26 entries: 13 species ×
{ANPPmax_multiplier, BiomassMax_multiplier}) and write a modified
SppEcoregionData CSV that the per-plot LANDIS scenarios will read.

theta layout:
  [ANPP_BF, ANPP_SM, ..., ANPP_HE, BMAX_BF, BMAX_SM, ..., BMAX_HE]
  13 + 13 = 26 entries, multipliers around 1.0

Usage:
  python3 apply_theta.py --theta-csv theta.csv --baseline-spp /path/SppEcoregionData.csv \
      --out /path/SppEcoregionData_theta.csv

The output CSV is identical to baseline except:
  ANPPmax_modified  = ANPPmax_baseline  * ANPP_<SpeciesCode>
  BiomassMax_mod    = BiomassMax_baseline * BMAX_<SpeciesCode>
"""

import argparse
import csv
import sys

SPECIES = ["BF", "SM", "BE", "RS", "WS", "BS", "CE", "YB", "RM", "IH", "PINE", "ASH", "HE"]


def read_theta(path):
    """Read theta as a flat 26-vector. Format: column 'value' or single column."""
    multipliers = {}
    with open(path) as f:
        reader = csv.DictReader(f)
        if reader.fieldnames and "param" in reader.fieldnames and "value" in reader.fieldnames:
            for row in reader:
                multipliers[row["param"]] = float(row["value"])
        else:
            # fall back to flat list of values
            f.seek(0)
            vals = [float(line.strip()) for line in f if line.strip()]
            if len(vals) != 26:
                raise ValueError(f"Expected 26 values, got {len(vals)}")
            for sp, v in zip(SPECIES, vals[:13]):
                multipliers[f"ANPP_{sp}"] = v
            for sp, v in zip(SPECIES, vals[13:]):
                multipliers[f"BMAX_{sp}"] = v
    return multipliers


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--theta-csv",     required=True, help="Parameter vector CSV (param,value)")
    p.add_argument("--baseline-spp",  required=True, help="Baseline SspEcoregionData.csv to multiply against")
    p.add_argument("--out",           required=True, help="Output SspEcoregionData CSV")
    args = p.parse_args()

    mult = read_theta(args.theta_csv)
    expected = {f"ANPP_{sp}" for sp in SPECIES} | {f"BMAX_{sp}" for sp in SPECIES}
    missing = expected - mult.keys()
    if missing:
        sys.stderr.write(f"ERROR: missing parameters: {missing}\n")
        sys.exit(1)

    n_in = n_out = 0
    with open(args.baseline_spp) as fin, open(args.out, "w", newline="") as fout:
        reader = csv.DictReader(fin)
        writer = csv.DictWriter(fout, fieldnames=reader.fieldnames)
        writer.writeheader()
        for row in reader:
            n_in += 1
            sp = row["SpeciesCode"]
            if sp not in SPECIES:
                # unknown species — keep unchanged
                writer.writerow(row)
                n_out += 1
                continue
            try:
                anpp = float(row["ANPPmax"])
                bmax = float(row["BiomassMax"])
            except (ValueError, KeyError):
                writer.writerow(row)
                n_out += 1
                continue
            anpp_new = anpp * mult[f"ANPP_{sp}"]
            bmax_new = bmax * mult[f"BMAX_{sp}"]
            row["ANPPmax"]    = f"{anpp_new:.0f}"
            row["BiomassMax"] = f"{bmax_new:.0f}"
            writer.writerow(row)
            n_out += 1

    print(f"Read {n_in} rows, wrote {n_out} to {args.out}")
    print(f"Applied {len(mult)} multipliers: ANPPmax range "
          f"[{min(v for k,v in mult.items() if k.startswith('ANPP')):.3f}, "
          f"{max(v for k,v in mult.items() if k.startswith('ANPP')):.3f}], "
          f"BMAX range [{min(v for k,v in mult.items() if k.startswith('BMAX')):.3f}, "
          f"{max(v for k,v in mult.items() if k.startswith('BMAX')):.3f}]")


if __name__ == "__main__":
    main()
