#!/usr/bin/env python3
"""aggregate_atlas_trajectories.py — merge per-plot LANDIS trajectories into atlas JSON.

Takes the per-plot biomass CSVs produced by a Tier 0 (literature) pass and a calibrated
pass, anchors them on the requested years, and writes t0 / t1 trajectory dicts onto each
plot record in atlas/{ST}.json. This is the merge step of the GA/ME (and later MN/WI/MI)
trajectory export; the LANDIS runs that produce the input CSVs are run separately on
Cardinal in the post-chain compute window so they do not compete with calibration chains.

Per-plot CSV format (as emitted by the runners): plot_id,year,TotalBiomass_gm2
Biomass is converted from g/m2 to Mg/ha (x 0.01) to match the atlas convention.

Usage:
  python3 aggregate_atlas_trajectories.py --state GA \
      --t0-csv t0.csv --t1-csv t1.csv \
      --atlas-in atlas/GA.json --atlas-out atlas/GA.json \
      --years 0 25 50 75 100 --key plot_id
"""
import argparse
import csv
import json
from collections import defaultdict


def load_traj(path, years):
    """Return {plot_id: {year: Mg_ha}} restricted to the requested years."""
    out = defaultdict(dict)
    yset = set(years)
    with open(path) as f:
        for r in csv.DictReader(f):
            pid = str(r["plot_id"]).strip()
            try:
                y = int(float(r["year"]))
                v = float(r["TotalBiomass_gm2"]) * 0.01
            except (KeyError, ValueError, TypeError):
                continue
            if y in yset and v >= 0:
                out[pid][str(y)] = round(v, 1)
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True)
    p.add_argument("--t0-csv", required=True)
    p.add_argument("--t1-csv", required=True)
    p.add_argument("--atlas-in", required=True)
    p.add_argument("--atlas-out", required=True)
    p.add_argument("--years", nargs="+", type=int, default=[0, 25, 50, 75, 100])
    p.add_argument("--key", default="plot_id",
                   help="plot record field to match the CSV plot_id against")
    args = p.parse_args()

    t0 = load_traj(args.t0_csv, args.years)
    t1 = load_traj(args.t1_csv, args.years)
    atlas = json.load(open(args.atlas_in))
    plots = atlas.get("plots", [])

    n_t0 = n_t1 = 0
    for rec in plots:
        pid = str(rec.get(args.key, "")).strip()
        if pid in t0:
            rec["t0"] = t0[pid]; n_t0 += 1
        if pid in t1:
            rec["t1"] = t1[pid]; n_t1 += 1

    atlas["trajectory_years"] = args.years
    json.dump(atlas, open(args.atlas_out, "w"))
    print(f"{args.state}: matched t0 for {n_t0} plots, t1 for {n_t1} plots, "
          f"of {len(plots)} atlas plots (key={args.key})")


if __name__ == "__main__":
    main()
