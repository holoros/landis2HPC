#!/usr/bin/env python3
"""build_plot_ics_N3.py — Eastern Hardwood Central (cluster N3: IN, OH) per-plot IC
builder from the FIA tree list. Adapts build_plot_ics_MN.py with an N3-specific FIA
SPCD -> LANDIS species map.

v2 (2026-06-02): species pool extended from 23 to 25 to address the IN per-plot LL
outlier (-1.31 vs OH's -0.86 in the same cluster). The bottomland-to-upland lumping of
silver maple (317) -> RM and eastern cottonwood (742) -> QA systematically underpredicted
biomass on Indiana's extensive Ohio/Wabash/White River bottomland plots. Added new
LANDIS species COTT (eastern cottonwood) and SIM (silver maple); rerouted SPCD 742 and
317 to these new species. See docs/indiana_ll_outlier_analysis.md for the full audit.

The remaining congener lumping is unchanged from v1: green ash -> WAS; bigtooth aspen
-> QA (a defensible same-genus lump); slippery elm -> AE; pignut/bitternut/generic
hickory -> MOK_HK; chestnut/chinkapin oak -> WO; blackjack oak -> BO; Shumard -> NRO;
boxelder -> RM (kept since boxelder is a small upland species).

LANDIS N3 species (25): WO NRO BO POST SHO SHA_HK MOK_HK SM RM YP BE WAS BAS BSW WALN
SWEETGUM BLACKGUM SYC SASSAFRAS DOGWOOD EWP QA AE COTT SIM.
"""
import argparse, csv, os, sys
from collections import defaultdict

SPCD_TO_LANDIS = {
    # --- oaks ---
    802: "WO",                              # white oak
    833: "NRO",                             # northern red oak
    837: "BO",                              # black oak
    835: "POST",                            # post oak
    817: "SHO",                             # shingle oak
    832: "WO", 826: "WO", 804: "WO", 823: "WO",   # chestnut/chinkapin/swamp white/bur -> white-oak group
    806: "BO", 812: "BO", 813: "BO",        # blackjack/southern red/cherrybark -> black-oak group
    834: "NRO",                             # Shumard -> red oak
    # --- maples ---
    318: "SM",                              # sugar maple
    316: "RM", 313: "RM",                   # red, boxelder -> red maple group
    317: "SIM",                             # silver maple (v2 split out from RM)
    # --- hickories ---
    407: "SHA_HK", 408: "SHA_HK",           # shagbark / shellbark
    409: "MOK_HK", 400: "MOK_HK", 402: "MOK_HK", 403: "MOK_HK",  # mockernut/generic/bitternut/pignut
    # --- ashes ---
    541: "WAS", 544: "WAS", 545: "WAS",     # white / green / blue ash -> white-ash group
    543: "BAS",                             # black ash
    # --- elms ---
    972: "AE", 975: "AE", 971: "AE", 977: "AE",  # American/slippery/winged/rock
    # --- aspen + poplar ---
    746: "QA", 743: "QA", 741: "QA",        # quaking/bigtooth/balsam aspen-poplar
    742: "COTT",                            # eastern cottonwood (v2 split out from QA)
    # --- 1:1 ---
    621: "YP",        # yellow-poplar
    531: "BE",        # American beech
    602: "WALN",      # black walnut
    611: "SWEETGUM",  # sweetgum
    693: "BLACKGUM",  # blackgum
    731: "SYC",       # American sycamore
    931: "SASSAFRAS", # sassafras
    491: "DOGWOOD",   # flowering dogwood
    129: "EWP",       # eastern white pine
    951: "BSW",       # American basswood
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
    p.add_argument("--plot-list", required=True, help="CSV with FIRST_PLTCN/PLT_CN and PLOT columns")
    p.add_argument("--out", required=True)
    p.add_argument("--subset", default=None, help="optional newline list of PLOT ids to restrict to")
    args = p.parse_args()

    keep = None
    if args.subset and os.path.exists(args.subset):
        keep = set()
        with open(args.subset) as f:
            for line in f:
                s = line.strip()
                if s and s.lower() != "plot":
                    keep.add(s)
        print(f"subset: restricting to {len(keep)} PLOT ids", file=sys.stderr)

    meta = {}
    with open(args.plot_list) as f:
        for row in csv.DictReader(f):
            cn = str(row.get("FIRST_PLTCN") or row.get("PLT_CN", "")).strip()
            plot = str(row.get("PLOT", "")).strip()
            if not cn or not plot:
                continue
            if keep is not None and plot not in keep:
                continue
            meta[cn] = {"plot_id": plot, "invyr": row.get("FIRST_INVYR") or row.get("INVYR")}
    print(f"Loaded {len(meta)} plots", file=sys.stderr)

    cohort = defaultdict(float)
    n_seen = n_mapped = 0
    with open(args.tree) as f:
        for r in csv.DictReader(f):
            cn = r.get("PLT_CN", "").strip()
            if cn not in meta: continue
            try:
                if int(float(r.get("STATUSCD", 0))) != 1: continue
                spcd = int(float(r.get("SPCD", 0)))
            except: continue
            n_seen += 1
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
            n_mapped += 1

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
                        "n_cohorts": len(pc), "total_biomass_g_m2": round(tot),
                        "total_biomass_Mg_ha": round(tot/100, 2)})
        if pc: nonempty += 1
    with open(os.path.join(args.out, "_summary.csv"), "w", newline="") as f:
        if summary:
            w = csv.DictWriter(f, fieldnames=list(summary[0].keys()))
            w.writeheader(); w.writerows(summary)
    cov = 100.0 * n_mapped / max(n_seen, 1)
    print(f"Wrote {len(meta)} ICs ({nonempty} non-empty); live trees on these plots: "
          f"{n_seen}, mapped to a modeled species: {n_mapped} ({cov:.1f}%)", file=sys.stderr)

if __name__ == "__main__":
    main()
