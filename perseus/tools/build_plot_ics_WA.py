#!/usr/bin/env python3
"""build_plot_ics_WA.py — Washington per-plot IC builder from FIA tree-list."""
import argparse, csv, os, sys
from collections import defaultdict

SPCD_TO_LANDIS = {
    11: "PSF", 15: "WF", 17: "GF", 19: "AF", 20: "AF", 22: "NF",
    73: "WL", 81: "IC", 93: "ES", 98: "SS",
    101: "WBP", 108: "LP", 119: "WP", 122: "PP", 202: "DF",
    211: "PY", 231: "PY", 242: "WC", 263: "WH", 264: "MH",
    312: "BM", 351: "RA", 352: "RA", 361: "PM", 373: "PB",
    746: "QA", 747: "BCW", 815: "GO",
}
LBS_ACRE_TO_G_M2 = 0.112085

def age_class(d):
    try: d = float(d)
    except: return None
    if d < 5: return 10
    if d < 12: return 30
    return 50

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--tree", required=True)
    p.add_argument("--plot-list", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()
    meta = {}
    with open(args.plot_list) as f:
        for row in csv.DictReader(f):
            cn = str(row.get("FIRST_PLTCN") or row.get("PLT_CN", "")).strip()
            if cn:
                meta[cn] = {"plot_id": row["PLOT"], "invyr": row.get("FIRST_INVYR") or row.get("INVYR")}
    print(f"Loaded {len(meta)} plots", file=sys.stderr)
    cohort = defaultdict(float)
    with open(args.tree) as f:
        for r in csv.DictReader(f):
            cn = r.get("PLT_CN", "").strip()
            if cn not in meta: continue
            try:
                if int(r.get("STATUSCD", 0)) != 1: continue
                spcd = int(float(r.get("SPCD", 0)))
            except: continue
            sp = SPCD_TO_LANDIS.get(spcd)
            if sp is None: continue
            age = age_class(r.get("DIA"))
            if age is None: continue
            try:
                dry = float(r.get("DRYBIO_AG") or 0)
                tpa = float(r.get("TPA_UNADJ") or 0)
            except: continue
            if dry <= 0 or tpa <= 0: continue
            cohort[(cn, sp, age)] += dry * tpa * LBS_ACRE_TO_G_M2
    os.makedirs(args.out, exist_ok=True)
    summary = []
    nonempty = 0
    for cn, m in meta.items():
        d = os.path.join(args.out, f"plot_{m['plot_id']}")
        os.makedirs(d, exist_ok=True)
        pc = [(sp, age, bio) for (k, sp, age), bio in cohort.items() if k == cn]
        with open(os.path.join(d, "initial_communities.csv"), "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["MapCode", "SpeciesName", "CohortAge", "CohortBiomass"])
            for sp, age, bio in sorted(pc):
                w.writerow([1, sp, age, round(bio)])
        tot = sum(b for _, _, b in pc)
        summary.append({"plt_cn": cn, "plot_id": m["plot_id"], "invyr": m["invyr"],
                        "n_cohorts": len(pc),
                        "total_biomass_g_m2": round(tot),
                        "total_biomass_Mg_ha": round(tot/100, 2)})
        if pc: nonempty += 1
    with open(os.path.join(args.out, "_summary.csv"), "w", newline="") as f:
        if summary:
            w = csv.DictWriter(f, fieldnames=list(summary[0].keys()))
            w.writeheader(); w.writerows(summary)
    print(f"Wrote {len(meta)} ICs ({nonempty} non-empty)", file=sys.stderr)

if __name__ == "__main__":
    main()
