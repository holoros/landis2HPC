"""s43 Track B: TreeMap 2020 pixel counts by raster Value inside one state polygon (cb_2023_us_state_20m).
Output stays on Cardinal (Value is a TreeMap key that maps to plots). usage: python 03_tm_pixels.py ST OUTCSV"""
import sys, struct, numpy as np, rasterio
from rasterio.warp import transform_geom
from rasterio.features import geometry_mask
from rasterio.windows import from_bounds
SHP = "/users/PUOM0008/crsfaaron/Disturbance/cb_2023_us_state_20m"
TIF = "/fs/scratch/PUOM0008/crsfaaron/TREEMAP_restore/TM2020/TreeMap2020_CONUS.tif"
ST, OUT = sys.argv[1], sys.argv[2]

def read_dbf(p):
    f = open(p, "rb"); h = f.read(32); n, hl, rl = struct.unpack("<IHH", h[4:12]); fields = []
    while True:
        d = f.read(32)
        if d[0] == 0x0D: break
        fields.append((d[:11].split(b"\0")[0].decode(), d[16]))
    f.seek(hl); recs = []
    for _ in range(n):
        r = f.read(rl); pos = 1; rec = {}
        for name, ln in fields: rec[name] = r[pos:pos + ln].decode("latin1").strip(); pos += ln
        recs.append(rec)
    return recs

def read_shp(p):
    b = open(p, "rb").read(); pos = 100; geoms = []
    while pos < len(b):
        _, ln = struct.unpack(">ii", b[pos:pos + 8]); pos += 8; c = b[pos:pos + 2 * ln]; pos += 2 * ln
        t = struct.unpack("<i", c[:4])[0]
        if t == 0: geoms.append(None); continue
        npart, npt = struct.unpack("<ii", c[36:44]); parts = list(struct.unpack("<%di" % npart, c[44:44 + 4 * npart]))
        pts = np.frombuffer(c[44 + 4 * npart:44 + 4 * npart + 16 * npt], dtype="<f8").reshape(-1, 2)
        geoms.append([pts[parts[i]:(parts[i + 1] if i + 1 < npart else npt)] for i in range(npart)])
    return geoms

def sarea(r): x, y = r[:, 0], r[:, 1]; return 0.5 * np.sum(x[:-1] * y[1:] - x[1:] * y[:-1])

recs = read_dbf(SHP + ".dbf"); geoms = read_shp(SHP + ".shp")
k = [i for i, r in enumerate(recs) if r.get("STUSPS") == ST]; assert len(k) == 1, k
rings = geoms[k[0]]; polys = []
for r in rings:
    if sarea(r) < 0: polys.append([r.tolist()])          # clockwise = outer ring (shapefile convention)
    else: polys[-1].append(r.tolist()) if polys else polys.append([r.tolist()])
geom = {"type": "MultiPolygon", "coordinates": polys}
print(ST, "rings", len(rings), "outer", len(polys), flush=True)
with rasterio.open(TIF) as src:
    g = transform_geom("EPSG:4269", src.crs, geom)
    xy = np.array([p for poly in g["coordinates"] for ring in poly for p in ring])
    win = from_bounds(xy[:, 0].min(), xy[:, 1].min(), xy[:, 0].max(), xy[:, 1].max(), src.transform).round_offsets().round_lengths()
    arr = src.read(1, window=win); tr = src.window_transform(win); nod = src.nodata
    print("window", arr.shape, "dtype", arr.dtype, "nodata", nod, "res", src.res, "crs", src.crs.to_string()[:40], flush=True)
    m = geometry_mask([g], out_shape=arr.shape, transform=tr, invert=True)
    inside = int(m.sum())
    v = arr[m]; v = v[(v > 0) & (v != nod)] if nod is not None else v[v > 0]
    cnt = np.bincount(v.astype(np.int64))
nz = np.nonzero(cnt)[0]
with open(OUT, "w") as f:
    f.write("Value,count\n")
    for i in nz: f.write(f"{i},{cnt[i]}\n")
print(f"{ST}: cells in polygon {inside}; mapped cells {int(cnt.sum())}; mapped ha {cnt.sum() * src.res[0] * src.res[1] / 1e4:.0f}; distinct values {len(nz)}", flush=True)
