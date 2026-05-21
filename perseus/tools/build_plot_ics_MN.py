#!/usr/bin/env python3
"""build_plot_ics_MN.py — Minnesota per-plot IC builder from FIA tree-list.

Adapts build_plot_ics_WA.py with an MN-specific FIA SPCD -> LANDIS species map.
MN LANDIS species (24): BF TAM WS BS RS JP RP WP CE HE RM SM YB PB BE
WAS BAS QA BA WO RO BO BSW AE. Minor congeners are lumped to the nearest
LANDIS species (silver/boxelder/mountain maple -> RM; green ash -> WAS;
cottonwood/balsam poplar -> QA; slippery/rock elm -> AE; black oak -> RO).
"""
import argparse, csv, os, sys
from collections import defaultdict

SPCD_TO_LANDIS = {
    12: "BF",                          # balsam fir
    71: "TAM",                         # tamarack (eastern larch)
    94: "WS",                          # white spruce
    95: "BS",                          # black spruce
    97: "RS",                          # red spruce (rare in MN)
    105: "JP",                         # jack pine
    125: "RP",                         # red pine
    129: "WP",                         # eastern white pine
    241: "CE",                         # northern white-cedar
    261: "HE",                         # eastern hemlock (rare in MN)
    313: "RM", 316: "RM", 317: "RM", 319: "RM",  # boxelder/red/silver/mountain maple
    318: "SM",                         # sugar maple
    371: "YB",                         # yellow birch
    375: "PB",                         # paper birch
    531: "BE",                         # American beech (rare in MN)
    541: "WAS", 544: "WAS",            # white ash + green ash
    543: "BAS",                        # black ash
    741: "QA", 742: "QA", 746: "QA",   # balsam poplar/cottonwood/quaking aspen
    743: "BA",                         # bigtooth aspen
    802: "WO",                         # white oak
    823: "BO",                         # bur oak
    833: "RO", 837: "RO",              # northern red oak + black oak
    951: "BSW",                        # American basswood
    971: "AE", 972: "AE", 975: "AE",   # rock/American/slippery elm
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
                if int(float(r.get("STATUSCD", 0))) != 1: continue
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
