#!/usr/bin/env python3
"""harvest_t2_chains.py — select the production Tier 2 vector from a finished CMA-ES chain.

Operationalizes the v1.0 selection lesson: the CMA-ES-reported xbest can be a
sample-size-degeneracy artifact (few plots -> trivially small total LL). The correct
production vector is the candidate with the highest PER-PLOT LL among candidates that
meet the minimum sample-size threshold (n_pairs >= MIN_N_PAIRS).

For each chain it:
  1. scans candidate dirs for per_plot.csv row counts (n_pairs) and log_likelihood.txt
  2. filters to candidates with n_pairs >= MIN_N_PAIRS
  3. selects the one with the highest per-plot LL (LL / n_pairs)
  4. copies that candidate's theta.csv to <bayesian>/theta_best_production.csv
  5. prints a one-line production-table row

Usage:
  python3 harvest_t2_chains.py --bayesian-dir <dir> --state MN [--min-n-pairs 300]
  python3 harvest_t2_chains.py --all   # scan all known chains
"""
import argparse, csv, glob, os, shutil, sys

KNOWN = {
    "GA": "/fs/scratch/PUOM0008/crsfaaron/landis2/states/GA/perseus/bayesian/ga_t2_v2",
    "MN": "/fs/scratch/PUOM0008/crsfaaron/landis2/states/MN/perseus/bayesian/mn_t2_v1",
    "WI": "/fs/scratch/PUOM0008/crsfaaron/landis2/states/WI/perseus/bayesian/wi_t2_v1",
    "MI": "/fs/scratch/PUOM0008/crsfaaron/landis2/states/MI/perseus/bayesian/mi_t2_v1",
}

def n_pairs(per_plot_csv):
    if not os.path.exists(per_plot_csv): return 0
    try:
        with open(per_plot_csv) as f:
            return sum(1 for _ in f) - 1
    except Exception:
        return 0

def harvest(bay, state, min_n):
    cands = []
    for d in sorted(glob.glob(os.path.join(bay, "*_iter*_cand*"))):
        ll_f = os.path.join(d, "log_likelihood.txt")
        pp_f = os.path.join(d, "per_plot.csv")
        if not os.path.exists(ll_f): continue
        try: ll = float(open(ll_f).read().strip())
        except Exception: continue
        n = n_pairs(pp_f)
        cands.append((d, ll, n))
    if not cands:
        print(f"{state}: no candidates with log_likelihood.txt found in {bay}", file=sys.stderr)
        return None
    eligible = [(d, ll, n) for d, ll, n in cands if n >= min_n]
    if not eligible:
        # No per_plot.csv present (e.g., the GA inline-LL runner that does not
        # persist per_plot.csv but uses the v1.0.1 settling check, which guarantees
        # a near-complete plot set for every candidate). In that case total LL is
        # comparable across candidates, so fall back to cma_history.csv and select
        # the best (lowest) negLL, excluding DEGEN penalties (>=1e5) and LL=0 artifacts.
        hist = os.path.join(bay, "cma_history.csv")
        if os.path.exists(hist):
            best_row = None
            with open(hist) as f:
                for r in csv.DictReader(f):
                    try: neg = float(r["negLL"])
                    except Exception: continue
                    if neg >= 1e5 or abs(neg) < 1e-6:  # skip DEGEN + LL=0 artifacts
                        continue
                    if best_row is None or neg < best_row[1]:
                        best_row = (r.get("tag", "?"), neg)
            if best_row:
                tag, neg = best_row
                print(f"{state}\t{tag}\tLL={-neg:.1f}\tn_pairs=cma_history\t"
                      f"per_plot_LL=n/a\t(cma_history.csv selection; no per_plot.csv)")
                return {"state": state, "tag": tag, "LL": -neg, "n_pairs": None,
                        "per_plot_LL": None, "theta": os.path.join(bay, tag, "theta.csv"),
                        "n_eligible": None, "n_total": len(cands), "via": "cma_history"}
        best_n = max(cands, key=lambda r: r[2])
        print(f"{state}: NO candidate met n_pairs>={min_n} (max n={best_n[2]}) and no "
              f"usable cma_history.csv. Chain likely degenerate or still running.", file=sys.stderr)
        return None
    # Select by highest per-plot LL
    best = max(eligible, key=lambda r: r[1] / r[2])
    d, ll, n = best
    tag = os.path.basename(d)
    src_theta = os.path.join(d, "theta.csv")
    out_theta = os.path.join(bay, "theta_best_production.csv")
    if os.path.exists(src_theta):
        shutil.copy(src_theta, out_theta)
    per_plot_ll = ll / n
    print(f"{state}\t{tag}\tLL={ll:.1f}\tn_pairs={n}\tper_plot_LL={per_plot_ll:.4f}\t-> {out_theta}")
    return {"state": state, "tag": tag, "LL": ll, "n_pairs": n,
            "per_plot_LL": per_plot_ll, "theta": out_theta,
            "n_eligible": len(eligible), "n_total": len(cands)}

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--bayesian-dir")
    p.add_argument("--state")
    p.add_argument("--min-n-pairs", type=int, default=300)
    p.add_argument("--all", action="store_true")
    args = p.parse_args()
    results = []
    print("state\tbest_tag\ttotal_LL\tn_pairs\tper_plot_LL\tproduction_vector")
    if args.all:
        for st, bay in KNOWN.items():
            if os.path.isdir(bay):
                r = harvest(bay, st, args.min_n_pairs)
                if r: results.append(r)
    else:
        if not args.bayesian_dir or not args.state:
            p.error("provide --bayesian-dir and --state, or use --all")
        r = harvest(args.bayesian_dir, args.state, args.min_n_pairs)
        if r: results.append(r)
    if results:
        print("\n=== production calibration table (per-plot LL selection, n_pairs >= "
              f"{args.min_n_pairs}) ===", file=sys.stderr)
        for r in results:
            if r.get("per_plot_LL") is None:
                print(f"  {r['state']}: total LL {r['LL']:+.1f} (cma_history selection; "
                      f"settling check guarantees comparable n)", file=sys.stderr)
            else:
                print(f"  {r['state']}: per-plot LL {r['per_plot_LL']:+.4f} over n={r['n_pairs']} "
                      f"({r['n_eligible']}/{r['n_total']} candidates eligible)", file=sys.stderr)

if __name__ == "__main__":
    main()
