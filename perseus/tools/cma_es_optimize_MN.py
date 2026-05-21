#!/usr/bin/env python3
"""cma_es_optimize_MN.py — per-species CMA-ES Tier 2 for Minnesota.

48-dim search: [ANPP_BF..ANPP_AE, BMAX_BF..BMAX_AE] for 24 MN species.
Parameterization: log-space multipliers (apply exp() before passing to apply_theta_MN_perspecies.py).

v2.0 driver: inherits all three v1.0 degeneracy guards (active-growth,
empty-aggregator, MIN_N_PAIRS) from the WA/GA production drivers.
Requires untreated_plots_MN.csv (multi-cycle FIA hindcast) and the MN
plot_ics_full/ subset to be staged first — see docs/v2.0_data_acquisition_checklist.md.
"""
import argparse, csv, math, os, pickle, subprocess, sys, time
from pathlib import Path
try:
    import cma
except ImportError:
    sys.stderr.write("Install: pip install --user --break-system-packages cma\n"); raise

# MN SpeciesData.csv order (24 species)
SPECIES = ["BF", "TAM", "WS", "BS", "RS", "JP", "RP", "WP", "CE", "HE",
           "RM", "SM", "YB", "PB", "BE", "WAS", "BAS", "QA", "BA", "WO",
           "RO", "BO", "BSW", "AE"]
PARAM_NAMES = [f"ANPP_{s}" for s in SPECIES] + [f"BMAX_{s}" for s in SPECIES]
N_PARAMS = len(PARAM_NAMES)  # 48

DEGENERACY_PENALTY = 1e6
MIN_ACTIVE_GROWTH_FRAC = 0.50
MIN_N_PAIRS = 300

def write_theta_csv(theta_log, path):
    with open(path, "w", newline="") as f:
        w = csv.writer(f); w.writerow(["param", "value"])
        for n, x in zip(PARAM_NAMES, theta_log):
            w.writerow([n, f"{math.exp(x):.6f}"])

def check_active_growth(tag_dir):
    import glob, csv as _csv
    files = glob.glob(str(tag_dir / "runs" / "plot_*" / "biomass_trajectory.csv"))
    if not files:
        return (0, 0, 0.0)
    n_active = 0; n_total = 0
    for f in files:
        try:
            with open(f) as fp:
                rows = list(_csv.DictReader(fp))
            by_year = {}
            for r in rows:
                try: by_year[int(r["year"])] = float(r["TotalBiomass_gm2"])
                except: pass
            y0 = by_year.get(0); ymax = max((y for y in by_year if y >= 25), default=None)
            if y0 is None or ymax is None or y0 <= 0: continue
            if by_year[ymax] / y0 > 1.05: n_active += 1
            n_total += 1
        except: continue
    return (n_active, n_total, n_active / max(n_total, 1))

def evaluate(theta_log, tag, bay_dir, tools_dir):
    tag_dir = bay_dir / tag
    tag_dir.mkdir(parents=True, exist_ok=True)
    theta_csv = tag_dir / "theta.csv"
    write_theta_csv(theta_log, theta_csv)
    runner = tools_dir / "run_param_set_MN_t2.sh"
    proc = subprocess.run(["bash", str(runner), str(theta_csv), tag],
                          capture_output=True, text=True, timeout=4*3600)
    ll_file = tag_dir / "log_likelihood.txt"
    if not ll_file.exists():
        sys.stderr.write(f"FAIL {tag}: no log_likelihood.txt (stderr: {proc.stderr[-500:]})\n")
        return 1e9
    try:
        ll = float(ll_file.read_text().strip())
    except Exception as e:
        sys.stderr.write(f"FAIL {tag}: cannot parse LL ({e})\n"); return 1e9

    n_active, n_total, frac = check_active_growth(tag_dir)
    try:
        with open(tag_dir / "active_growth.txt", "w") as f:
            f.write(f"n_active={n_active}\nn_total={n_total}\nfrac={frac:.4f}\n")
    except: pass

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
    p.add_argument("--sigma0", type=float, default=0.15)
    p.add_argument("--x0-uniform", type=float, default=math.log(0.65),
                   help="Init all species at this log-multiplier (default log(0.65))")
    p.add_argument("--tag-prefix", default="mn_t2_v1")
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
                "bounds": [[-1.5]*N_PARAMS, [1.5]*N_PARAMS], "verbose": -9}
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
            print(f"iter{it} cand{k} tag={tag} negLL={negLL:.2f} ({time.time()-t0:.0f}s)", flush=True)
            with open(hist_path, "a", newline="") as f:
                csv.writer(f).writerow([it, k, tag, f"{negLL:.2f}"] + [f"{math.exp(v):.4f}" for v in x])
        es.tell(cands, fits)
        with open(pickle_path, "wb") as f: pickle.dump(es, f)
        print(f"iter{it} best negLL: {min(fits):.2f}", flush=True)

    print("CMA-ES complete.")
    write_theta_csv(es.result.xbest, bay / "theta_best.csv")
    print(f"Wrote {bay / 'theta_best.csv'}")

if __name__ == "__main__":
    main()
