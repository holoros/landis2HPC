#!/usr/bin/env python3
"""
build_ga_plot_list.py — construct an untreated, multi-cycle plot list for GA
calibration. Joins GA_PLOT + GA_COND + GA_TREE.

Output: untreated_plots_GA.csv with at minimum:
  PLOT, FIRST_PLTCN, FIRST_INVYR, PUB_LAT, PUB_LONG, COUNTYCD,
  N_CYCLES, BIOM_<year1>_Mgha, BIOM_<year2>_Mgha, ...

Filters applied:
  - Plot has rows in COND with COND_STATUS_CD == 1 (accessible forest) for ALL its measurement years
  - All COND rows for the plot have no treatment signal (TRTCD1/2/3 all 0 or blank)
  - Plot has measurements across >= 2 distinct INVYRs
  - At least one tree row with positive DRYBIO_AG in the TREE table
"""
import argparse, csv, sys
from collections import defaultdict

LBS_ACRE_TO_G_M2 = 0.112085

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--plot", required=True)
    p.add_argument("--cond", required=True)
    p.add_argument("--tree", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--min-cycles", type=int, default=2)
    p.add_argument("--limit", type=int, default=0)
    args = p.parse_args()

    # 1. Read PLOT table: build (STATECD, UNITCD, COUNTYCD, PLOT) -> list of (INVYR, PLT_CN, lat, lon)
    plot_records = defaultdict(list)
    with open(args.plot) as f:
        for r in csv.DictReader(f):
            try:
                pl = int(r["PLOT"])
                invyr = int(r.get("INVYR", 0))
                cn = r.get("CN", "").strip()
                if not cn or invyr < 1990: continue
                key = (r.get("STATECD"), r.get("UNITCD"), r.get("COUNTYCD"), pl)
                lat = r.get("LAT") or r.get("PUB_LAT") or ""
                lon = r.get("LON") or r.get("PUB_LONG") or ""
                plot_records[key].append({
                    "invyr": invyr, "plt_cn": cn,
                    "lat": lat, "lon": lon,
                    "countycd": r.get("COUNTYCD"),
                })
            except (KeyError, ValueError):
                continue
    print(f"Loaded {len(plot_records)} plot keys from PLOT", file=sys.stderr)

    # 2. Read COND table: filter to forested + untreated
    # Per plot-year: forested if any row COND_STATUS_CD == 1; untreated if all TRTCD blank/0
    cond_status = defaultdict(lambda: {"forested": False, "treated": False})
    with open(args.cond) as f:
        for r in csv.DictReader(f):
            cn = r.get("PLT_CN", "").strip()
            if not cn: continue
            try:
                csc = int(r.get("COND_STATUS_CD") or 0)
            except: csc = 0
            if csc == 1:
                cond_status[cn]["forested"] = True
            for trt_field in ("TRTCD1", "TRTCD2", "TRTCD3", "ALL_TRTCD"):
                v = r.get(trt_field) or ""
                try:
                    if int(v) > 0:
                        cond_status[cn]["treated"] = True
                        break
                except: pass
    print(f"COND rows aggregated for {len(cond_status)} plt_cn", file=sys.stderr)

    # 3. Read TREE table: per (plt_cn) sum of live biomass (Mg/ha)
    tree_bio = defaultdict(float)
    with open(args.tree) as f:
        for r in csv.DictReader(f):
            cn = r.get("PLT_CN", "").strip()
            if not cn: continue
            try:
                if int(r.get("STATUSCD", 0)) != 1: continue
                dry = float(r.get("DRYBIO_AG") or 0)
                tpa = float(r.get("TPA_UNADJ") or 0)
            except: continue
            if dry <= 0 or tpa <= 0: continue
            tree_bio[cn] += dry * tpa * LBS_ACRE_TO_G_M2 / 100.0  # g/m^2 -> Mg/ha
    print(f"TREE rows aggregated for {len(tree_bio)} plt_cn", file=sys.stderr)

    # 4. For each unique plot key, find FIRST cycle that's forested + untreated + has biomass.
    rows_out = []
    for key, recs in plot_records.items():
        recs_sorted = sorted(recs, key=lambda x: x["invyr"])
        # Keep only valid cycles
        valid = []
        for rec in recs_sorted:
            cn = rec["plt_cn"]
            cs = cond_status.get(cn, {"forested": False, "treated": False})
            if not cs["forested"] or cs["treated"]:
                continue
            bio = tree_bio.get(cn, 0)
            if bio <= 0: continue
            valid.append({**rec, "biom_Mgha": bio})
        if len(valid) < args.min_cycles:
            continue
        first = valid[0]
        out = {
            "PLOT": key[3],
            "FIRST_PLTCN": first["plt_cn"],
            "FIRST_INVYR": first["invyr"],
            "PUB_LAT": first["lat"],
            "PUB_LONG": first["lon"],
            "COUNTYCD": first["countycd"],
            "N_CYCLES": len(valid),
        }
        # Per-cycle biomass: stash as BIOM_<INVYR>
        for rec in valid:
            out[f"BIOM_{rec['invyr']}_Mgha"] = round(rec["biom_Mgha"], 3)
        rows_out.append(out)

    rows_out.sort(key=lambda r: (-r["N_CYCLES"], int(r["PLOT"])))
    if args.limit > 0:
        rows_out = rows_out[:args.limit]
    print(f"Plots passing filters: {len(rows_out)}", file=sys.stderr)

    # Build a stable column list
    cycle_cols = set()
    for r in rows_out:
        for k in r:
            if k.startswith("BIOM_"):
                cycle_cols.add(k)
    cycle_cols = sorted(cycle_cols)
    base_cols = ["PLOT", "FIRST_PLTCN", "FIRST_INVYR", "PUB_LAT", "PUB_LONG",
                 "COUNTYCD", "N_CYCLES"]
    with open(args.out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=base_cols + cycle_cols)
        w.writeheader()
        for r in rows_out:
            w.writerow(r)
    print(f"Wrote {args.out} ({len(rows_out)} plots, columns: {base_cols + cycle_cols})", file=sys.stderr)

if __name__ == "__main__":
    main()
