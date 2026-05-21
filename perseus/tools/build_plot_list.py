#!/usr/bin/env python3
"""build_plot_list.py — state-agnostic FIA multi-cycle untreated-plot list builder.

Generalizes build_ga_plot_list.py so any state can be processed with the same
logic. Two improvements over the GA-specific version:

1. Works from COND alone for plot grouping (no separate PLOT table required).
   COND carries STATECD/UNITCD/COUNTYCD/PLOT/INVYR/PLT_CN, sufficient to group
   remeasured cycles of the same plot.

2. Optional Jenkins (2003) national allometric biomass estimation from DIA + SPCD
   when the TREE table lacks DRYBIO_AG (some reduced FIA exports omit it).

Output: untreated_plots_{ST}.csv with columns PLOT, FIRST_PLTCN, FIRST_INVYR,
PUB_LAT, PUB_LONG, COUNTYCD, N_CYCLES, BIOM_{INVYR}_Mgha...

Usage:
  python3 build_plot_list.py --cond MN_COND.csv --tree MN_TREE.csv \
      --out untreated_plots_MN.csv --min-cycles 2 [--plot MN_PLOT.csv]
"""
import argparse, csv, sys
from collections import defaultdict

LBS_ACRE_TO_G_M2 = 0.112085  # lb/acre -> g/m^2

# Jenkins et al. (2003) generalized AG biomass: bm(kg) = exp(b0 + b1*ln(DIA_cm))
# Coarse species-group parameters keyed by FIA SPCD ranges. Used only as a
# fallback when DRYBIO_AG is absent. These are deliberately conservative
# national defaults; production calibration should use the FIA DRYBIO_AG field.
JENKINS_GROUPS = {
    "aspen_alder_cottonwood_willow": (-2.2094, 2.3867),
    "soft_maple_birch":              (-1.9123, 2.3651),
    "hard_maple_oak_hickory_beech":  (-2.0127, 2.4342),
    "mixed_hardwood":                (-2.4800, 2.4835),
    "cedar_larch":                   (-2.0336, 2.2592),
    "douglas_fir":                   (-2.2304, 2.4435),
    "true_fir_hemlock":              (-2.5384, 2.4814),
    "pine":                          (-2.5356, 2.4349),
    "spruce":                        (-2.0773, 2.3323),
}

def jenkins_group_for_spcd(spcd):
    """Very coarse SPCD -> Jenkins group mapping (US FIA species codes)."""
    try:
        s = int(spcd)
    except (TypeError, ValueError):
        return "mixed_hardwood"
    # Softwoods are SPCD < 300
    if s < 300:
        if s in (202,):                       return "douglas_fir"
        if s in (241, 242):                   return "cedar_larch"   # cedars
        if s in (260, 261, 262, 263, 264):    return "true_fir_hemlock"
        if 90 <= s <= 130:                    return "spruce"        # spruce/fir region
        if 10 <= s <= 99:                     return "pine"          # pines
        return "pine"
    # Hardwoods
    if s in (740, 741, 742, 743, 744, 745, 746, 747, 375, 376):
        return "aspen_alder_cottonwood_willow"
    if s in (310, 311, 312, 313, 314, 315, 316, 317, 318, 319, 371, 372, 373, 374):
        return "soft_maple_birch"
    if s in (316, 318, 802, 833, 802, 835, 837, 832, 806, 531):
        return "hard_maple_oak_hickory_beech"
    return "mixed_hardwood"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--cond", required=True)
    p.add_argument("--tree", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--plot", default=None, help="Optional PLOT table; if absent, group from COND")
    p.add_argument("--min-cycles", type=int, default=2)
    p.add_argument("--limit", type=int, default=0)
    p.add_argument("--jenkins-fallback", action="store_true",
                   help="Estimate AG biomass from DIA via Jenkins if DRYBIO_AG absent")
    args = p.parse_args()

    # 1. Plot records: prefer PLOT table, else reconstruct from COND
    plot_records = defaultdict(list)
    if args.plot:
        src = args.plot
        with open(src) as f:
            for r in csv.DictReader(f):
                try:
                    pl = int(r["PLOT"]); invyr = int(r.get("INVYR", 0))
                    cn = r.get("CN", "").strip()
                    if not cn or invyr < 1990: continue
                    key = (r.get("STATECD"), r.get("UNITCD"), r.get("COUNTYCD"), pl)
                    plot_records[key].append({
                        "invyr": invyr, "plt_cn": cn,
                        "lat": r.get("LAT") or r.get("PUB_LAT") or "",
                        "lon": r.get("LON") or r.get("PUB_LONG") or "",
                        "countycd": r.get("COUNTYCD")})
                except (KeyError, ValueError):
                    continue
        print(f"Loaded {len(plot_records)} plot keys from PLOT table", file=sys.stderr)
    else:
        # Reconstruct plot grouping from COND (one record per PLT_CN)
        seen_cn = set()
        with open(args.cond) as f:
            for r in csv.DictReader(f):
                cn = r.get("PLT_CN", "").strip()
                if not cn or cn in seen_cn: continue
                seen_cn.add(cn)
                try:
                    pl = int(r.get("PLOT") or 0); invyr = int(r.get("INVYR") or 0)
                except: continue
                if invyr < 1990: continue
                key = (r.get("STATECD"), r.get("UNITCD"), r.get("COUNTYCD"), pl)
                plot_records[key].append({
                    "invyr": invyr, "plt_cn": cn,
                    "lat": r.get("LAT") or r.get("PUB_LAT") or "",
                    "lon": r.get("LON") or r.get("PUB_LONG") or "",
                    "countycd": r.get("COUNTYCD")})
        print(f"Reconstructed {len(plot_records)} plot keys from COND", file=sys.stderr)

    # 2. COND forested + untreated status per PLT_CN
    cond_status = defaultdict(lambda: {"forested": False, "treated": False})
    with open(args.cond) as f:
        for r in csv.DictReader(f):
            cn = r.get("PLT_CN", "").strip()
            if not cn: continue
            try: csc = int(r.get("COND_STATUS_CD") or 0)
            except: csc = 0
            if csc == 1: cond_status[cn]["forested"] = True
            for fld in ("TRTCD1", "TRTCD2", "TRTCD3", "ALL_TRTCD"):
                v = r.get(fld) or ""
                try:
                    if int(v) > 0: cond_status[cn]["treated"] = True; break
                except: pass
    print(f"COND status for {len(cond_status)} plt_cn", file=sys.stderr)

    # 3. TREE biomass per PLT_CN (DRYBIO_AG preferred; Jenkins fallback optional)
    tree_bio = defaultdict(float)
    n_tree_rows = 0; used_jenkins = False
    with open(args.tree) as f:
        rdr = csv.DictReader(f)
        has_drybio = rdr.fieldnames and "DRYBIO_AG" in rdr.fieldnames
        for r in rdr:
            cn = r.get("PLT_CN", "").strip()
            if not cn: continue
            try:
                if int(r.get("STATUSCD", 0)) != 1: continue
                tpa = float(r.get("TPA_UNADJ") or 0)
            except: continue
            if tpa <= 0: continue
            if has_drybio:
                try: dry = float(r.get("DRYBIO_AG") or 0)
                except: dry = 0
                if dry <= 0: continue
                tree_bio[cn] += dry * tpa * LBS_ACRE_TO_G_M2 / 100.0
            elif args.jenkins_fallback:
                used_jenkins = True
                try: dia_cm = float(r.get("DIA") or 0) * 2.54
                except: dia_cm = 0
                if dia_cm <= 0: continue
                import math
                b0, b1 = JENKINS_GROUPS[jenkins_group_for_spcd(r.get("SPCD"))]
                bm_kg = math.exp(b0 + b1 * math.log(dia_cm))
                # kg/tree * trees/acre -> kg/acre -> Mg/ha
                tree_bio[cn] += bm_kg * tpa * 0.00112085
            n_tree_rows += 1
    print(f"TREE rows used: {n_tree_rows}; biomass for {len(tree_bio)} plt_cn"
          f"{' (Jenkins fallback)' if used_jenkins else ' (DRYBIO_AG)'}", file=sys.stderr)

    # 4. First forested + untreated + has-biomass cycle, require >= min_cycles
    rows_out = []
    for key, recs in plot_records.items():
        valid = []
        for rec in sorted(recs, key=lambda x: x["invyr"]):
            cn = rec["plt_cn"]
            cs = cond_status.get(cn, {"forested": False, "treated": False})
            if not cs["forested"] or cs["treated"]: continue
            bio = tree_bio.get(cn, 0)
            if bio <= 0: continue
            valid.append({**rec, "biom_Mgha": bio})
        if len(valid) < args.min_cycles: continue
        first = valid[0]
        out = {"PLOT": key[3], "FIRST_PLTCN": first["plt_cn"],
               "FIRST_INVYR": first["invyr"], "PUB_LAT": first["lat"],
               "PUB_LONG": first["lon"], "COUNTYCD": first["countycd"],
               "N_CYCLES": len(valid)}
        for rec in valid:
            out[f"BIOM_{rec['invyr']}_Mgha"] = round(rec["biom_Mgha"], 3)
        rows_out.append(out)

    rows_out.sort(key=lambda r: (-r["N_CYCLES"], int(r["PLOT"])))
    if args.limit > 0: rows_out = rows_out[:args.limit]
    print(f"Plots passing filters: {len(rows_out)}", file=sys.stderr)

    cycle_cols = sorted({k for r in rows_out for k in r if k.startswith("BIOM_")})
    base_cols = ["PLOT", "FIRST_PLTCN", "FIRST_INVYR", "PUB_LAT", "PUB_LONG",
                 "COUNTYCD", "N_CYCLES"]
    with open(args.out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=base_cols + cycle_cols)
        w.writeheader(); w.writerows(rows_out)
    print(f"Wrote {args.out} ({len(rows_out)} plots)", file=sys.stderr)

if __name__ == "__main__":
    main()
