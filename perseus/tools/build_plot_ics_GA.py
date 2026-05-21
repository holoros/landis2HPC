#!/usr/bin/env python3
"""build_plot_ics_GA.py — Georgia per-plot IC builder from FIA tree-list."""
import argparse, csv, os, sys
from collections import defaultdict

SPCD_TO_LANDIS = {
    110: "SP",   111: "SL",   121: "LL",   131: "LO",   132: "VP",
    219: "ERC",  241: "EH",   261: "EH",
    315: "RM",   316: "RM",   317: "RM",   318: "SM",
    371: "YB",   375: "YB",
    400: "HK",   401: "HK",   402: "HK",   403: "HK",   407: "HK",   409: "HK",
    531: "BE",
    540: "WAS",  541: "WAS",  543: "WAS",  544: "WAS",
    611: "SY",   621: "TT",
    641: "MG",   651: "MG",   652: "MG",
    693: "BG",   694: "BG",
    762: "BC",
    802: "WO",   806: "BO",   812: "WAO",  813: "RO",   817: "WAO",
    822: "SO",   827: "WO",   832: "CO",   833: "RO",   835: "WAO",
    837: "PO",   838: "PO",
    901: "BSW",  972: "AE",   975: "AE",
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
    print(f"Loaded {len(meta)} target plots", file=sys.stderr)

    cohort = defaultdict(float)
    scanned = kept = 0
    with open(args.tree) as f:
        for r in csv.DictReader(f):
            scanned += 1
            if scanned % 200000 == 0:
                print(f"  scanned {scanned:,}, kept {kept:,}", file=sys.stderr)
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
            kept += 1

    print(f"Done: {scanned:,} rows scanned, {kept:,} kept, {len(cohort):,} cohorts", file=sys.stderr)
    os.makedirs(args.out, exist_ok=True)
    summary = []
    nonempty = 0
    for cn, m in meta.items():
        d = os.path.join(args.out, f"plot_{m['plot_id']}")
        os.makedirs(d, exist_ok=True)
        plot_cohorts = [(sp, age, bio) for (k, sp, age), bio in cohort.items() if k == cn]
        with open(os.path.join(d, "initial_communities.csv"), "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["MapCode", "SpeciesName", "CohortAge", "CohortBiomass"])
            for sp, age, bio in sorted(plot_cohorts):
                w.writerow([1, sp, age, round(bio)])
        tot = sum(b for _, _, b in plot_cohorts)
        summary.append({"plt_cn": cn, "plot_id": m["plot_id"], "invyr": m["invyr"],
                        "n_cohorts": len(plot_cohorts),
                        "total_biomass_g_m2": round(tot),
                        "total_biomass_Mg_ha": round(tot/100, 2)})
        if plot_cohorts: nonempty += 1

    with open(os.path.join(args.out, "_summary.csv"), "w", newline="") as f:
        if summary:
            w = csv.DictWriter(f, fieldnames=list(summary[0].keys()))
            w.writeheader(); w.writerows(summary)
    print(f"Wrote {len(meta)} ICs ({nonempty} non-empty)", file=sys.stderr)

if __name__ == "__main__":
    main()
