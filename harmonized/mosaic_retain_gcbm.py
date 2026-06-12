#!/usr/bin/env python3
"""mosaic_retain_gcbm.py - retain GCBM spatial rasters for the harmonized assessment.

The Maine statewide GCBM array (run_maine_statewide.sh) writes per-tile GeoTIFFs to
runs/gcbm_maine_statewide_<tx>_<ty>/output/<Variable>/...<step>.tif. The standard
pipeline only runs aggregate_geotiffs.py (CSV rollup) and the rasters are never
mosaicked or archived. This script mosaics the per-tile, per-step GeoTIFFs into
full-extent rasters per variable per timestep and writes them to a retained dir,
ready for the zenodo-deposit skill (DOI, FAIR archive).

Retained variables (the harmonized comparables): AG_Biomass_C (aboveground live C,
the cross-model comparable), Total_Ecosystem_C, and Age. One mosaicked GeoTIFF per
variable per 5-yr step (LZW-compressed, tiled, with overviews).

Usage:
  python3 mosaic_retain_gcbm.py \
    --runs-glob '/users/PUOM0008/crsfaaron/cbm_maine/runs/gcbm_maine_statewide_*' \
    --out /fs/scratch/PUOM0008/crsfaaron/FIA/gcbm_rasters/ME \
    --vars AG_Biomass_C Total_Ecosystem_C Age

Needs gdal CLI (gdalbuildvrt, gdal_translate, gdaladdo) on PATH - available in the
libcbm env (source envs/libcbm/bin/activate) or `module load gdal`.
"""
import argparse, glob, os, re, subprocess, sys
from collections import defaultdict

def sh(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(f"FAILED: {' '.join(cmd)}\n{r.stderr[-800:]}\n")
    return r.returncode == 0

# moja GeoTIFF names end with the timestep, commonly <Variable>_<...>_<step>.tif or
# .../<Variable>/<x>_<y>/<Variable>_<x>_<y>_<step>.tif. Pull the trailing integer as step.
STEP_RE = re.compile(r"_(\d+)\.tif{1,2}$", re.IGNORECASE)

def collect(runs_glob, variables):
    # by_var_step[var][step] -> list of per-tile tif paths
    by = defaultdict(lambda: defaultdict(list))
    for run_dir in sorted(glob.glob(runs_glob)):
        outdir = os.path.join(run_dir, "output")
        if not os.path.isdir(outdir):
            continue
        for var in variables:
            vdir = os.path.join(outdir, var)
            if not os.path.isdir(vdir):
                continue
            for tif in glob.glob(os.path.join(vdir, "**", "*.tif*"), recursive=True):
                m = STEP_RE.search(os.path.basename(tif))
                step = int(m.group(1)) if m else 0
                by[var][step].append(tif)
    return by

def mosaic(tifs, out_tif):
    vrt = out_tif.replace(".tif", ".vrt")
    listfile = out_tif + ".lst"
    with open(listfile, "w") as fh:
        fh.write("\n".join(tifs) + "\n")
    ok = sh(["gdalbuildvrt", "-q", "-input_file_list", listfile, vrt])
    if ok:
        ok = sh(["gdal_translate", "-q", "-of", "GTiff",
                 "-co", "COMPRESS=LZW", "-co", "TILED=YES", "-co", "BIGTIFF=IF_SAFER",
                 vrt, out_tif])
    if ok:
        sh(["gdaladdo", "-q", "-r", "average", out_tif, "2", "4", "8", "16"])
    for f in (vrt, listfile):
        try: os.remove(f)
        except OSError: pass
    return ok

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs-glob", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--vars", nargs="+",
                    default=["AG_Biomass_C", "Total_Ecosystem_C", "Age"])
    ap.add_argument("--step0-year", type=int, default=2025)
    ap.add_argument("--step-years", type=int, default=5)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    by = collect(a.runs_glob, a.vars)
    if not by:
        sys.exit("no per-tile GeoTIFFs found - check --runs-glob and that the run finished")
    n_ok = 0
    for var in a.vars:
        for step in sorted(by[var]):
            year = a.step0_year + a.step_years * step
            out_tif = os.path.join(a.out, f"{var}_{year}.tif")
            tifs = sorted(by[var][step])
            if mosaic(tifs, out_tif):
                n_ok += 1
                print(f"retained {var} step {step} -> {out_tif}  ({len(tifs)} tiles)")
    print(f"\nDONE: {n_ok} mosaicked rasters retained under {a.out}")
    print("Next: zenodo-deposit skill to mint a DOI for the GCBM spatial layer.")

if __name__ == "__main__":
    main()
