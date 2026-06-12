#!/usr/bin/env python3
"""validate_ic_coverage.py - zero-drop check for an IC SPCD->species map.

Reports, for a state's full FIA TREE table, what fraction of live-tree aboveground
biomass the given cluster map covers, and lists the uncovered species by biomass so
a silent drop (the WI/MI failure class) cannot slip through. Pulls species names
from FIA REF_SPECIES if available.

Usage: validate_ic_coverage.py --tree FILE --map build_plot_ics_N1.py [--ref REF_SPECIES.csv]
"""
import argparse, csv, importlib.util, sys
from collections import defaultdict

def load_map(path):
    spec = importlib.util.spec_from_file_location("m", path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m.SPCD_TO_LANDIS

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--tree", required=True)
    p.add_argument("--map", required=True)
    p.add_argument("--ref")
    args = p.parse_args()
    M = load_map(args.map)
    names = {}
    if args.ref:
        for r in csv.DictReader(open(args.ref)):
            try: names[int(float(r.get("SPCD", 0)))] = r.get("COMMON_NAME", "")
            except Exception: pass
    bio = defaultdict(float)
    for r in csv.DictReader(open(args.tree)):
        try:
            if int(r.get("STATUSCD", 0)) != 1: continue
            spcd = int(float(r.get("SPCD", 0)))
            dry = float(r.get("DRYBIO_AG") or 0); tpa = float(r.get("TPA_UNADJ") or 0)
        except Exception:
            continue
        if dry > 0 and tpa > 0:
            bio[spcd] += dry * tpa
    tot = sum(bio.values())
    cov = sum(b for s, b in bio.items() if s in M)
    unc = sorted([(s, b) for s, b in bio.items() if s not in M], key=lambda x: -x[1])
    print(f"live AGB covered: {100.0*cov/tot:.2f}%  ({len(M)} mapped codes; {len(bio)} species present)")
    print(f"uncovered biomass: {100.0*(tot-cov)/tot:.2f}%  across {len(unc)} species")
    print("top uncovered species (SPCD, %AGB, name):")
    for s, b in unc[:12]:
        print(f"  {s:>4}  {100.0*b/tot:5.2f}%  {names.get(s,'')}")

if __name__ == "__main__":
    main()
