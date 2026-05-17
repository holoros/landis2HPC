#!/usr/bin/env python3
"""cma_es_optimize_WA.py — per-species CMA-ES Tier 2 for Washington.

50-dim search: [ANPP_DF..ANPP_GO, BMAX_DF..BMAX_GO]
Parameterization: log-space multipliers (apply exp() before passing to apply_theta_WA_perspecies.py).
"""
import argparse, csv, math, os, pickle, subprocess, sys, time
from pathlib import Path
try:
    import cma
except ImportError:
    sys.stderr.write("Install: pip install --user --break-system-packages cma\n"); raise

SPECIES = ["DF", "WH", "WC", "PSF", "GF", "NF", "SS", "ES", "AF", "WF",
           "LP", "PP", "WP", "WBP", "MH", "WL", "IC", "PY", "BM", "RA",
           "PM", "PB", "QA", "BCW", "GO"]
PARAM_NAMES = [f"ANPP_{s}" for s in SPECIES] + [f"BMAX_{s}" for s in SPECIES]
N_PARAMS = len(PARAM_NAMES)  # 50

def write_theta_csv(theta_log, path):
    """Convert log-space vector to linear multipliers, write param,value CSV."""
    with open(path, "w", newline="") as f:
        w = csv.writer(f); w.writerow(["param", "value"])
        for n, x in zip(PARAM_NAMES, theta_log):
            w.writerow([n, f"{math.exp(x):.6f}"])

def evaluate(theta_log, tag, bay_dir, tools_dir):
    """Apply theta, run sweep, read log-likelihood, return -LL (CMA-ES minimizes)."""
    tag_dir = bay_dir / tag
    tag_dir.mkdir(parents=True, exist_ok=True)
    theta_csv = tag_dir / "theta.csv"
    write_theta_csv(theta_log, theta_csv)
    runner = tools_dir / "run_param_set_WA_t2.sh"
    proc = subprocess.run(["bash", str(runner), str(theta_csv), tag],
                          capture_output=True, text=True, timeout=4*3600)
    ll_file = tag_dir / "log_likelihood.txt"
    if not ll_file.exists():
        sys.stderr.write(f"FAIL {tag}: no log_likelihood.txt (stderr: {proc.stderr[-500:]})\n")
        return 1e9
    try:
        ll = float(ll_file.read_text().strip())
        return -ll
    except Exception as e:
        sys.stderr.write(f"FAIL {tag}: cannot parse LL ({e})\n"); return 1e9

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--max-iter", type=int, default=10)
    p.add_argument("--population", type=int, default=14)
    p.add_argument("--sigma0", type=float, default=0.15)
    p.add_argument("--x0-uniform", type=float, default=math.log(0.65), help="Init all species at this log-multiplier (default log(0.65)≈-0.43)")
    p.add_argument("--tag-prefix", default="wa_t2")
    p.add_argument("--bayesian-dir", required=True)
    p.add_argument("--tools-dir", default="/fs/scratch/PUOM0008/crsfaaron/landis2/tools")
    p.add_argument("--resume", action="store_true")
    args = p.parse_args()
    bay = Path(args.bayesian_dir); bay.mkdir(parents=True, exist_ok=True)
    tools = Path(args.tools_dir)
    pickle_path = bay / "es.pickle"
    hist_path = bay / "cma_history.csv"

    if args.resume and pickle_path.exists():
        with open(pickle_path, "rb") as f: es = pickle.load(f)
        print(f"Resumed from {pickle_path}, evals so far: {es.countevals}", flush=True)
    else:
        x0 = [args.x0_uniform] * N_PARAMS
        opts = {"popsize": args.population, "maxiter": args.max_iter,
                "bounds": [[-1.5]*N_PARAMS, [1.5]*N_PARAMS],
                "verbose": -9}
        es = cma.CMAEvolutionStrategy(x0, args.sigma0, opts)

    if not hist_path.exists():
        with open(hist_path, "w", newline="") as f:
            csv.writer(f).writerow(["iter", "candidate", "tag", "negLL"] + PARAM_NAMES)

    while not es.stop():
        it = es.countiter
        cands = es.ask()
        fits = []
        for k, x in enumerate(cands):
            tag = f"{args.tag_prefix}_iter{it}_cand{k}"
            t0 = time.time()
            negLL = evaluate(x, tag, bay, tools)
            elapsed = time.time() - t0
            fits.append(negLL)
            print(f"iter{it} cand{k} tag={tag} negLL={negLL:.2f} ({elapsed:.0f}s)", flush=True)
            with open(hist_path, "a", newline="") as f:
                csv.writer(f).writerow([it, k, tag, f"{negLL:.2f}"] + [f"{math.exp(v):.4f}" for v in x])
        es.tell(cands, fits)
        with open(pickle_path, "wb") as f: pickle.dump(es, f)
        print(f"iter{it} best negLL: {min(fits):.2f}", flush=True)

    print("CMA-ES complete.")
    best = es.result.xbest
    write_theta_csv(best, bay / "theta_best.csv")
    print(f"Wrote {bay / 'theta_best.csv'}")

if __name__ == "__main__":
    main()
