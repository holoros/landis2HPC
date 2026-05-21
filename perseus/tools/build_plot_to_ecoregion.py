#!/usr/bin/env python3
"""build_plot_to_ecoregion.py — sample an ecoregion raster at each plot's lat/lon.

State-agnostic. Reads the plot list (PLOT, FIRST_PLTCN, PUB_LAT, PUB_LONG),
samples the L3 ecoregion GeoTIFF at each plot location, writes plot_id,plt_cn,eco.
Handles raster CRS reprojection from EPSG:4326 lat/lon if needed.
"""
import argparse, csv, sys
from osgeo import gdal, osr

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--plot-list", required=True)
    p.add_argument("--ecoregion-tif", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()

    ds = gdal.Open(args.ecoregion_tif)
    if ds is None:
        sys.stderr.write(f"Cannot open {args.ecoregion_tif}\n"); sys.exit(1)
    gt = ds.GetGeoTransform()
    band = ds.GetRasterBand(1)
    arr = band.ReadAsArray()
    nrows, ncols = arr.shape
    nodata = band.GetNoDataValue()

    # Build a transform from EPSG:4326 (lat/lon) to the raster CRS
    src_srs = osr.SpatialReference(); src_srs.ImportFromEPSG(4326)
    dst_srs = osr.SpatialReference(); dst_srs.ImportFromWkt(ds.GetProjection())
    try:
        src_srs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
        dst_srs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    except Exception:
        pass
    ct = osr.CoordinateTransformation(src_srs, dst_srs)

    def sample(lat, lon):
        x, y, _ = ct.TransformPoint(lon, lat)  # traditional GIS order: lon, lat
        col = int((x - gt[0]) / gt[1])
        row = int((y - gt[3]) / gt[5])
        if 0 <= row < nrows and 0 <= col < ncols:
            v = arr[row, col]
            if nodata is not None and v == nodata:
                return None
            return int(v)
        return None

    rows_out = []
    n_ok = 0; n_miss = 0
    with open(args.plot_list) as f:
        for r in csv.DictReader(f):
            pid = r["PLOT"]
            cn = r.get("FIRST_PLTCN") or r.get("PLT_CN") or ""
            try:
                lat = float(r["PUB_LAT"]); lon = float(r["PUB_LONG"])
            except (KeyError, ValueError):
                n_miss += 1; continue
            eco = sample(lat, lon)
            if eco is None:
                n_miss += 1; continue
            rows_out.append({"plot_id": pid, "plt_cn": cn, "eco": eco})
            n_ok += 1

    with open(args.out, "w", newline="") as g:
        w = csv.DictWriter(g, fieldnames=["plot_id", "plt_cn", "eco"])
        w.writeheader(); w.writerows(rows_out)
    # Report ecoregion distribution
    from collections import Counter
    dist = Counter(r["eco"] for r in rows_out)
    sys.stderr.write(f"Wrote {args.out}: {n_ok} plots mapped, {n_miss} unmapped\n")
    sys.stderr.write(f"Ecoregion distribution: {dict(sorted(dist.items()))}\n")

if __name__ == "__main__":
    main()
