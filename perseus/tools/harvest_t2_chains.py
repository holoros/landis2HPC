#!/usr/bin/env python3
"""harvest_t2_chains.py — select the production Tier 2 vector from a finished CMA-ES chain.

Operationalizes the v1.0 selection lesson AND its v1.x correction.

Three calibration degeneracy modes can make the CMA-ES-reported xbest (lowest negLL)
the WRONG production vector:
  (1) active-growth degeneracy  — guarded upstream in the driver
  (2) empty-aggregator degeneracy — guarded upstream in the driver
  (3) sample-size degeneracy     — a candidate evaluated on FEW plots has a trivially
                                   small total negLL. The active settling check is meant
                                   to hold every candidate to a near-complete plot set,
                                   but the settling check can TIME OUT under node
                                   contention (observed: GA iter5_cand10 ran on only
                                   240/779 plots -> n=398 paired obs -> spuriously low
                                   total negLL=367 that is actually a mediocre per-plot fit).

The robust production rule (this script) is therefore:
  - read the TRUE paired-observation count n and signed LL from each candidate's
    launch.log line  'n=NNN mean=.. sd=.. LL=..'  (identical print format across all
    state runners, GA inline-LL and MN/WI/MI alike). per_plot.csv row count is only a
    fallback presence signal.
  - require n >= max(MIN_N_PAIRS, NEAR_FULL_FRAC * max_n_in_chain)  (near-full settling)
  - among those, select the highest PER-PLOT LL (LL / n)
  - copy that candidate's theta.csv to <bayesian>/theta_best_production.csv

This corrects the prior cma_history.csv fallback, which trusted the settling check to
guarantee comparable n and so could pick a settling-timeout artifact.

Usage:
  python3 harvest_t2_chains.py --bayesian-dir <dir> --state MN [--min-n-pairs 300]
  python3 harvest_t2_chains.py --all   # scan all known chains
"""
import argparse, glob, os, re, shutil, sys

KNOWN = {
    "GA": "/fs/scratch/PUOM0008/crsfaaron/landis2/states/GA/perseus/bayesian/ga_t2_v2",
    "MN": "/fs/scratch/PUOM0008/crsfaaron/landis2/states/MN/perseus/bayesian/mn_t2_v1",
    "WI": "/fs/scratch/PUOM0008/crsfaaron/landis2/states/WI/perseus/bayesian/wi_t2_v1",
    "MI": "/fs/scratch/PUOM0008/crsfaaron/landis2/states/MI/perseus/bayesian/mi_t2_v1",
}

NEAR_FULL_FRAC = 0.85  # candidate must have run on >= 85% of the chain's max plot set

# matches e.g. "n=1255 mean=-0.1031 sd=0.6096 LL=-1113.29"
_LL_LINE = re.compile(r"^n=(\d+)\s+mean=.*\bLL=(-?\d+(?:\.\d+)?)", re.MULTILINE)


def n_ll_from_launchlog(d):
    """Return (n, signed_LL) parsed from the LAST 'n=.. LL=..' line in launch.log,
    or (None, None) if not present."""
    log_f = os.path.join(d, "launch.log")
    if not os.path.exists(log_f):
        return None, None
    try:
        txt = open(log_f, errors="replace").read()
    except Exception:
        return None, None
    matches = _LL_LINE.findall(txt)
    if not matches:
        return None, None
    n_s, ll_s = matches[-1]
    try:
        return int(n_s), float(ll_s)
    except ValueError:
        return None, None


def n_ll_fallback(d):
    """Fallback for chains that persist per_plot.csv + log_likelihood.txt but whose
    launch.log lacks the summary line. n = per_plot.csv row count (proxy)."""
    ll_f = os.path.join(d, "log_likelihood.txt")
    pp_f = os.path.join(d, "per_plot.csv")
    if not os.path.exists(ll_f):
        return None, None
    try:
        ll = float(open(ll_f).read().strip())
    except Exception:
        return None, None
    n = 0
    if os.path.exists(pp_f):
        try:
            with open(pp_f) as f:
                n = max(sum(1 for _ in f) - 1, 0)
        except Exception:
            n = 0
    return n, ll


def harvest(bay, state, min_n):
    cands = []  # (dir, n, ll, source)
    for d in sorted(glob.glob(os.path.join(bay, "*_iter*_cand*"))):
        n, ll = n_ll_from_launchlog(d)
        src = "launch.log"
        if n is None:
            n, ll = n_ll_fallback(d)
            src = "per_plot.csv"
        if n is None or ll is None:
            continue
        cands.append((d, n, ll, src))

    if not cands:
        print(f"{state}: no candidates with a parsable n/LL found in {bay}", file=sys.stderr)
        return None

    max_n = max(n for _, n, _, _ in cands)
    floor = max(min_n, int(NEAR_FULL_FRAC * max_n))
    eligible = [(d, n, ll) for d, n, ll, _ in cands if n >= floor]

    if not eligible:
        best_n = max(cands, key=lambda r: r[1])
        print(f"{state}: NO candidate met n>={floor} (= max({min_n}, {NEAR_FULL_FRAC:.2f}*"
              f"{max_n})). Best available n={best_n[1]}. Chain likely degenerate or "
              f"still settling.", file=sys.stderr)
        return None

    # Select highest per-plot LL (least-negative LL/n) among near-full-n candidates.
    best = max(eligible, key=lambda r: r[2] / r[1])
    d, n, ll = best
    tag = os.path.basename(d)
    per_plot_ll = ll / n
    src_theta = os.path.join(d, "theta.csv")
    out_theta = os.path.join(bay, "theta_best_production.csv")
    wrote = False
    if os.path.exists(src_theta):
        shutil.copy(src_theta, out_theta)
        wrote = True
    print(f"{state}\t{tag}\tLL={ll:.1f}\tn={n}\tper_plot_LL={per_plot_ll:.4f}\t"
          f"max_n={max_n}\tfloor={floor}\t-> {out_theta if wrote else '(theta.csv MISSING)'}")
    return {"state": state, "tag": tag, "LL": ll, "n": n, "max_n": max_n,
            "floor": floor, "per_plot_LL": per_plot_ll, "theta": out_theta,
            "wrote": wrote, "n_eligible": len(eligible), "n_total": len(cands)}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--bayesian-dir")
    p.add_argument("--state")
    p.add_argument("--min-n-pairs", type=int, default=300)
    p.add_argument("--all", action="store_true")
    args = p.parse_args()
    results = []
    print("state\tbest_tag\ttotal_LL\tn\tper_plot_LL\tmax_n\tfloor\tproduction_vector")
    if args.all:
        for st, bay in KNOWN.items():
            if os.path.isdir(bay):
                r = harvest(bay, st, args.min_n_pairs)
                if r:
                    results.append(r)
    else:
        if not args.bayesian_dir or not args.state:
            p.error("provide --bayesian-dir and --state, or use --all")
        r = harvest(args.bayesian_dir, args.state, args.min_n_pairs)
        if r:
            results.append(r)
    if results:
        print(f"\n=== production calibration table (per-plot LL among near-full-n: "
              f"n >= max({args.min_n_pairs}, {NEAR_FULL_FRAC:.2f}*max_n)) ===", file=sys.stderr)
        for r in results:
            flag = "" if r["wrote"] else "  [WARN: theta.csv missing]"
            print(f"  {r['state']}: per-plot LL {r['per_plot_LL']:+.4f} over n={r['n']} "
                  f"(near-full floor {r['floor']}/{r['max_n']}; "
                  f"{r['n_eligible']}/{r['n_total']} candidates eligible){flag}", file=sys.stderr)


if __name__ == "__main__":
    main()
