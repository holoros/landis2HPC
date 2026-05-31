#!/usr/bin/env python3
"""cma_es_optimize_GA.py — 54-dim per-species CMA-ES Tier 2 for Georgia.

Initial seed: log(0.30) (best Tier 1 ladder θ for GA).
"""
import argparse, csv, math, pickle, subprocess, sys, time
from pathlib import Path
try:
    import cma
except ImportError:
    sys.stderr.write("Install: pip install --user cma\n"); raise

SPECIES = ["AE", "BC", "BE", "BG", "BO", "BSW", "CO", "EH", "ERC", "HK",
           "LL", "LO", "MG", "PO", "RM", "RO", "SL", "SM", "SO", "SP",
           "SY", "TT", "VP", "WAO", "WAS", "WO", "YB"]
PARAM_NAMES = [f"ANPP_{s}" for s in SPECIES] + [f"BMAX_{s}" for s in SPECIES]
N_PARAMS = len(PARAM_NAMES)  # 54

DEGENERACY_PENALTY = 1e6  # large but finite; CMA-ES treats as "bad" without being unbounded
MIN_ACTIVE_GROWTH_FRAC = 0.50  # require >=50% of plots with >5% year-100 growth
MIN_N_PAIRS = 300  # require >=300 paired plots before accepting LL (sample-size guard)

def write_theta_csv(theta_log, path):
    with open(path, "w", newline="") as f:
        w = csv.writer(f); w.writerow(["param", "value"])
        for n, x in zip(PARAM_NAMES, theta_log):
            w.writerow([n, f"{math.exp(x):.6f}"])

def check_active_growth(tag_dir):
    """Fraction of per-plot trajectories with >5% biomass growth over the run.

    Reads biomass_trajectory.csv files under tag_dir/runs/plot_*/. A degenerate
    calibration (CMA-ES pushed theta into zero-growth territory) will show
    n_active near zero, caught here and penalized.
    """
    import glob, csv as _csv
    files = glob.glob(str(tag_dir / "runs" / "plot_*" / "biomass_trajectory.csv"))
    if not files:
        return (0, 0, 0.0)
    n_active = 0
    n_total = 0
    for f in files:
        try:
            with open(f) as fp:
                rdr = _csv.DictReader(fp)
                rows = list(rdr)
            by_year = {}
            for r in rows:
                try:
                    by_year[int(r["year"])] = float(r["TotalBiomass_gm2"])
                except: pass
            y0 = by_year.get(0); ymax = max((y for y in by_year if y >= 25), default=None)
            if y0 is None or ymax is None or y0 <= 0:
                continue
            ratio = by_year[ymax] / y0
            if ratio > 1.05: n_active += 1
            n_total += 1
        except: continue
    frac = n_active / max(n_total, 1)
    return (n_active, n_total, frac)

def evaluate(theta_log, tag, bay, tools):
    tag_dir = bay / tag
    tag_dir.mkdir(parents=True, exist_ok=True)
    theta_csv = tag_dir / "theta.csv"
    write_theta_csv(theta_log, theta_csv)
    runner = tools / "run_param_set_GA_t2.sh"
    try:  # PERSEUS_TIMEOUT_GUARD
        proc = subprocess.run(["bash", str(runner), str(theta_csv), tag],
                          capture_output=True, text=True, timeout=4*3600)
    except subprocess.TimeoutExpired:
        sys.stderr.write(f"TIMEOUT {tag}: runner exceeded the subprocess timeout; penalized\n")
        return 1e6
    except Exception as _e:
        sys.stderr.write(f"FAIL {tag}: runner raised {_e!r}; penalized\n")
        return 1e6
    ll_file = tag_dir / "log_likelihood.txt"
    if not ll_file.exists():
        sys.stderr.write(f"FAIL {tag}: no LL ({proc.stderr[-500:]})\n"); return 1e9
    try:
        ll = float(ll_file.read_text().strip())
    except Exception as e:
        sys.stderr.write(f"FAIL {tag}: {e}\n"); return 1e9

    n_active, n_total, frac = check_active_growth(tag_dir)
    try:
        with open(tag_dir / "active_growth.txt", "w") as f:
            f.write(f"n_active={n_active}\nn_total={n_total}\nfrac={frac:.4f}\n")
    except: pass

    # Empty-aggregator + sample-size check
    per_plot_csv = tag_dir / "per_plot.csv"
    if per_plot_csv.exists():
        try:
            with open(per_plot_csv) as fp:
                n_rows = sum(1 for _ in fp) - 1
        except Exception:
            n_rows = -1
        if n_rows <= 0:
            sys.stderr.write(f"DEGEN {tag}: per_plot.csv empty (rows={n_rows}, LL={ll}); penalized\n")
            return DEGENERACY_PENALTY
        if n_rows < MIN_N_PAIRS:
            sys.stderr.write(f"DEGEN {tag}: per_plot.csv has only {n_rows} pairs < {MIN_N_PAIRS} (LL={ll}); penalized\n")
            return DEGENERACY_PENALTY

    if ll == 0.0 and frac < MIN_ACTIVE_GROWTH_FRAC:
        sys.stderr.write(f"DEGEN {tag}: LL=0 with active_growth_frac={frac:.2f} < {MIN_ACTIVE_GROWTH_FRAC}; penalized\n")
        return DEGENERACY_PENALTY
    if frac < MIN_ACTIVE_GROWTH_FRAC and ll > -100:
        sys.stderr.write(f"DEGEN {tag}: LL={ll:.2f} with active_growth_frac={frac:.2f} < {MIN_ACTIVE_GROWTH_FRAC}; penalized\n")
        return DEGENERACY_PENALTY

    return -ll

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--max-iter", type=int, default=8)
    p.add_argument("--population", type=int, default=14)
    p.add_argument("--sigma0", type=float, default=0.2)
    p.add_argument("--x0-uniform", type=float, default=math.log(0.30), help="Init at log(0.30) ≈ -1.20")
    p.add_argument("--tag-prefix", default="ga_t2")
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
        print(f"Resumed (evals: {es.countevals})", flush=True)
    else:
        x0 = [args.x0_uniform] * N_PARAMS
        opts = {"popsize": args.population, "maxiter": args.max_iter,
                "bounds": [[-2.0]*N_PARAMS, [1.0]*N_PARAMS], "verbose": -9}
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
            fits.append(negLL)
            print(f"iter{it} cand{k} {tag} negLL={negLL:.2f} ({time.time()-t0:.0f}s)", flush=True)
            with open(hist_path, "a", newline="") as f:
                csv.writer(f).writerow([it, k, tag, f"{negLL:.2f}"] +
                                       [f"{math.exp(v):.4f}" for v in x])
        es.tell(cands, fits)
        with open(pickle_path, "wb") as f: pickle.dump(es, f)
        print(f"iter{it} best negLL: {min(fits):.2f}", flush=True)

    print("Done.")
    best = es.result.xbest
    write_theta_csv(best, bay / "theta_best.csv")

if __name__ == "__main__":
    main()
