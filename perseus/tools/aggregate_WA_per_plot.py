#!/usr/bin/env python3
"""aggregate_WA_per_plot.py — pull per-plot biomass trajectory from WA Tier 0 runs.

Each plot run dir holds:
  output/biomass/biomass-TotalBiomass-{0,5,10,...,100}.tif  (g/m^2, single pixel)

We extract the pixel value for years 0,5,10,...,30 (the FIA observation window)
and write a wide table keyed by plot_id with one column per year (Mg/ha).
"""
import argparse, csv, os, glob, sys
from osgeo import gdal

CELL_AREA_HA = 0.09  # 30m x 30m
GM2_TO_MGHA = 0.01   # 1 g/m^2 = 0.01 Mg/ha

def read_total(path):
    ds = gdal.Open(path)
    if ds is None: return None
    arr = ds.GetRasterBand(1).ReadAsArray()
    return float(arr.flatten()[0]) * GM2_TO_MGHA  # cell value in g/m^2 → Mg/ha

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--runs-dir", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--clim", default="baseline")
    p.add_argument("--harv", default="none")
    p.add_argument("--years", default="0,5,10,15,20,25,30")
    args = p.parse_args()
    years = [int(y) for y in args.years.split(",")]
    suffix = f"__clim_{args.clim}_harv_{args.harv}"
    dirs = sorted(glob.glob(os.path.join(args.runs_dir, f"plot_*{suffix}")))
    rows = []
    missed = 0
    for d in dirs:
        pid = os.path.basename(d).split("__")[0].replace("plot_", "")
        row = {"plot_id": pid}
        ok = True
        for y in years:
            f = os.path.join(d, "output", "biomass", f"biomass-TotalBiomass-{y}.tif")
            v = read_total(f) if os.path.exists(f) else None
            if v is None:
                ok = False; break
            row[f"BIOM_yr{y}"] = round(v, 3)
        if ok:
            rows.append(row)
        else:
            missed += 1
    print(f"Read {len(rows)} plots, missed {missed}", file=sys.stderr)
    with open(args.out, "w", newline="") as fp:
        w = csv.DictWriter(fp, fieldnames=["plot_id"] + [f"BIOM_yr{y}" for y in years])
        w.writeheader(); w.writerows(rows)
    print(f"Wrote {args.out}", file=sys.stderr)

if __name__ == "__main__":
    main()
