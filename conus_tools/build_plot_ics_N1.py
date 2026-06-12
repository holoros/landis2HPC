#!/usr/bin/env python3
"""build_plot_ics_N1.py - Cluster N1 (Northeast hardwood-boreal) per-plot IC builder.

Rebuilt for the CONUS onboarding so N1 states (NH, VT, NY, MA, CT, RI) no longer
fall back to the MN species map (which silently drops Acadian flora). The SPCD ->
LANDIS map is reused verbatim from ME's calibrated species_lookup_ME.R (the N1
reference), not invented: 27 FIA species codes lumped into the 13-species Acadian
pool with ME's documented rules (PINE = white+red+jack pine; IH = paper/gray birch,
aspens, balsam poplar, blackgum, American elm; ASH = white+black+green; BS =
black spruce+tamarack; RM = red+striped+silver+mountain maple).

Output contract matches build_plot_ics_WA.py exactly: plot_<id>/initial_communities.csv
(MapCode,SpeciesName,CohortAge,CohortBiomass) plus _summary.csv (plt_cn, plot_id,
invyr, n_cohorts, total_biomass_g_m2, total_biomass_Mg_ha).

KNOWN FLORA LIMIT: Maine's pool has no oak/hickory. Southern N1 states (NH, VT, MA,
CT) carry oak-hickory that has no analog here. Run validate first; if uncovered
biomass is non-trivial, extend the N1 pool rather than silently dropping it.
"""
import argparse, csv, os, sys
from collections import defaultdict

# Base 27 codes reused verbatim from ME species_lookup_ME.R (cluster N1 reference).
# EXTENDED 2026-06-09 for the broader Northeast (NH/VT/MA/CT/NY carry oak-hickory
# that Maine lacks): added RO (red-oak group) and HICK (hickory group) with traits
# and per-ecoregion productivity borrowed from the calibrated OH/IN central-hardwood
# neighbour (nearest analog; documented). Minor gaps lumped: black cherry -> IH
# (fast pioneer hardwood), sweet birch -> YB (same genus Betula).
SPCD_TO_LANDIS = {
    12: "BF",
    71: "BS", 95: "BS",          # tamarack + black spruce -> boreal conifer
    94: "WS",
    97: "RS",
    105: "PINE", 125: "PINE", 129: "PINE",
    241: "CE",                   # northern white cedar
    261: "HE",
    315: "RM", 316: "RM", 317: "RM", 319: "RM",
    318: "SM",
    371: "YB", 372: "YB",        # yellow birch + sweet birch (Betula)
    375: "IH", 379: "IH", 660: "IH", 741: "IH", 743: "IH", 746: "IH", 972: "IH",
    762: "IH",                   # black cherry -> intolerant-hardwood group
    531: "BE",
    541: "ASH", 543: "ASH", 544: "ASH",
    # red-oak group (extension)
    802: "RO", 806: "RO", 812: "RO", 823: "RO", 832: "RO", 833: "RO", 837: "RO",
    # hickory group (extension)
    400: "HICK", 401: "HICK", 402: "HICK", 403: "HICK", 407: "HICK", 409: "HICK",
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
    p.add_argument("--plot-list", required=True,
                   help="CSV with plt_cn/PLT_CN/FIRST_PLTCN and plot_id/PLOT columns")
    p.add_argument("--out", required=True)
    args = p.parse_args()

    meta = {}
    with open(args.plot_list) as f:
        for row in csv.DictReader(f):
            cn = str(row.get("plt_cn") or row.get("FIRST_PLTCN") or row.get("PLT_CN", "")).strip()
            pid = row.get("plot_id") or row.get("PLOT")
            if cn and pid:
                meta[cn] = {"plot_id": pid, "invyr": row.get("invyr") or row.get("FIRST_INVYR") or row.get("INVYR")}
    print(f"Loaded {len(meta)} plots", file=sys.stderr)

    cohort = defaultdict(float)
    with open(args.tree) as f:
        for r in csv.DictReader(f):
            cn = r.get("PLT_CN", "").strip()
            if cn not in meta: continue
            try:
                if int(r.get("STATUSCD", 0)) != 1: continue
                spcd = int(float(r.get("SPCD", 0)))
            except Exception:
                continue
            sp = SPCD_TO_LANDIS.get(spcd)
            if sp is None: continue
            age = age_class(r.get("DIA"))
            if age is None: continue
            try:
                dry = float(r.get("DRYBIO_AG") or 0); tpa = float(r.get("TPA_UNADJ") or 0)
            except Exception:
                continue
            if dry <= 0 or tpa <= 0: continue
            cohort[(cn, sp, age)] += dry * tpa * LBS_ACRE_TO_G_M2

    os.makedirs(args.out, exist_ok=True)
    summary, nonempty = [], 0
    for cn, m in meta.items():
        d = os.path.join(args.out, f"plot_{m['plot_id']}")
        os.makedirs(d, exist_ok=True)
        pc = [(sp, age, bio) for (k, sp, age), bio in cohort.items() if k == cn]
        with open(os.path.join(d, "initial_communities.csv"), "w", newline="") as f:
            w = csv.writer(f); w.writerow(["MapCode", "SpeciesName", "CohortAge", "CohortBiomass"])
            for sp, age, bio in sorted(pc):
                w.writerow([1, sp, age, round(bio)])
        tot = sum(b for _, _, b in pc)
        summary.append({"plt_cn": cn, "plot_id": m["plot_id"], "invyr": m["invyr"],
                        "n_cohorts": len(pc), "total_biomass_g_m2": round(tot),
                        "total_biomass_Mg_ha": round(tot/100, 2)})
        if pc: nonempty += 1
    with open(os.path.join(args.out, "_summary.csv"), "w", newline="") as f:
        if summary:
            w = csv.DictWriter(f, fieldnames=list(summary[0].keys()))
            w.writeheader(); w.writerows(summary)
    print(f"Wrote {len(meta)} ICs ({nonempty} non-empty)", file=sys.stderr)

if __name__ == "__main__":
    main()
