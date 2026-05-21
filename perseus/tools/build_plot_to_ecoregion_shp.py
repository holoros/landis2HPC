#!/usr/bin/env python3
"""build_plot_to_ecoregion_shp.py — assign EPA L3 ecoregion to plots by point-in-polygon.

State-agnostic. Reads plot list (PLOT, FIRST_PLTCN, PUB_LAT, PUB_LONG), reprojects
each plot's lat/lon to the ecoregion shapefile CRS, and finds the containing polygon's
US_L3CODE. Writes plot_id,plt_cn,eco. Avoids needing a pre-rasterized ecoregion tif.
"""
import argparse, csv, sys
from osgeo import ogr, osr

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--plot-list", required=True)
    p.add_argument("--eco-shp", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--code-field", default="US_L3CODE")
    args = p.parse_args()

    ds = ogr.Open(args.eco_shp)
    lyr = ds.GetLayer()
    shp_srs = lyr.GetSpatialRef()
    wgs = osr.SpatialReference(); wgs.ImportFromEPSG(4326)
    try:
        wgs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
        shp_srs.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
    except Exception:
        pass
    ct = osr.CoordinateTransformation(wgs, shp_srs)

    # Build an in-memory list of (geom, code) with bounding boxes for speed
    feats = []
    for feat in lyr:
        g = feat.GetGeometryRef()
        if g is None: continue
        code = feat.GetField(args.code_field)
        try: code = int(code)
        except (TypeError, ValueError): continue
        feats.append((g.Clone(), code, g.GetEnvelope()))  # env = (minX,maxX,minY,maxY)
    sys.stderr.write(f"Loaded {len(feats)} ecoregion polygons\n")

    rows_out = []; n_ok = 0; n_miss = 0
    from collections import Counter
    dist = Counter()
    with open(args.plot_list) as f:
        for r in csv.DictReader(f):
            pid = r["PLOT"]; cn = r.get("FIRST_PLTCN") or r.get("PLT_CN") or ""
            try:
                lat = float(r["PUB_LAT"]); lon = float(r["PUB_LONG"])
            except (KeyError, ValueError):
                n_miss += 1; continue
            x, y, _ = ct.TransformPoint(lon, lat)
            pt = ogr.Geometry(ogr.wkbPoint); pt.AddPoint(x, y)
            found = None
            for g, code, env in feats:
                if x < env[0] or x > env[1] or y < env[2] or y > env[3]:
                    continue
                if g.Contains(pt):
                    found = code; break
            if found is None:
                n_miss += 1; continue
            rows_out.append({"plot_id": pid, "plt_cn": cn, "eco": found})
            dist[found] += 1; n_ok += 1

    with open(args.out, "w", newline="") as g:
        w = csv.DictWriter(g, fieldnames=["plot_id", "plt_cn", "eco"])
        w.writeheader(); w.writerows(rows_out)
    sys.stderr.write(f"Wrote {args.out}: {n_ok} mapped, {n_miss} unmapped\n")
    sys.stderr.write(f"Ecoregion distribution: {dict(sorted(dist.items()))}\n")

if __name__ == "__main__":
    main()
