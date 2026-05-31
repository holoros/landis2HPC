#!/usr/bin/env python3
"""cma_es_optimize_cluster.py — generalized, warmstart-capable Tier 2 CMA-ES driver
for the PERSEUS hybrid CONUS expansion (docs/conus_ecoregion_clusters.md).

Replaces the per-state cma_es_optimize_<ST>.py copies with one state-parameterized
driver. The species list is read from the state's SpeciesData.csv, so no per-state code
edit is needed to add a state. The warmstart x0 comes from a cluster reference theta
(cluster_<N>_reference_theta.csv); species absent from the reference fall back to a cold
mid-range multiplier. add_state.sh invokes this as:

    cma_es_optimize_cluster.py --state <ST> --tag <TAG> --warmstart <reference_theta.csv>

Design notes vs. the legacy per-state drivers:
  * Timeout guard built in from the start (PERSEUS_TIMEOUT_GUARD): a runner that hangs
    past --runner-timeout-h is scored as the degeneracy penalty, never crashes the chain.
    This is the bug that killed the 2026-05-29 IN/OH chains.
  * Warmstart from a calibrated neighbor (hybrid architecture C) instead of a cold
    uniform x0, which converges ~30-40% faster (the WI/MI-from-MN pattern).
  * Same three degeneracy guards (active-growth, empty-aggregator, MIN_N_PAIRS) as the
    production WA/GA/MN drivers.
"""
import argparse, csv, math, os, pickle, subprocess, sys, time
from pathlib import Path
try:
    import cma
except ImportError:
    sys.stderr.write("Install: pip install --user --break-system-packages cma\n"); raise

DEGENERACY_PENALTY = 1e6
MIN_ACTIVE_GROWTH_FRAC = 0.50
MIN_N_PAIRS = 300
COLD_MULT = 0.60  # fallback multiplier for species absent from the warmstart reference

LANDIS_DEFAULT = "/fs/scratch/PUOM0008/crsfaaron/landis2"


def read_species(state, landis):
    """Species codes, in SpeciesData.csv order, for the state."""
    spp_file = Path(landis) / "states" / state / "inputs" / "SpeciesData.csv"
    if not spp_file.exists():
        sys.stderr.write(f"FATAL: {spp_file} not found; cannot determine species list\n")
        sys.exit(2)
    species = []
    with open(spp_file) as f:
        for row in csv.DictReader(f):
            code = (row.get("SpeciesCode") or "").strip()
            if code:
                species.append(code)
    if not species:
        sys.stderr.write(f"FATAL: no species parsed from {spp_file}\n"); sys.exit(2)
    return species


def read_warmstart(path, param_names):
    """Return log-space x0 aligned to param_names; missing params get log(COLD_MULT)."""
    mult = {}
    if path:
        with open(path) as f:
            for row in csv.DictReader(f):
                try:
                    mult[row["param"]] = float(row["value"])
                except (KeyError, ValueError):
                    pass
    x0, n_hit = [], 0
    for p in param_names:
        if p in mult and mult[p] > 0:
            x0.append(math.log(mult[p])); n_hit += 1
        else:
            x0.append(math.log(COLD_MULT))
    sys.stderr.write(f"warmstart: {n_hit}/{len(param_names)} params seeded from reference, "
                     f"{len(param_names)-n_hit} cold at {COLD_MULT}\n")
    return x0


def write_theta_csv(theta_log, param_names, path):
    with open(path, "w", newline="") as f:
        w = csv.writer(f); w.writerow(["param", "value"])
        for n, x in zip(param_names, theta_log):
            w.writerow([n, f"{math.exp(x):.6f}"])


def check_active_growth(tag_dir):
    import glob, csv as _csv
    files = glob.glob(str(tag_dir / "runs" / "plot_*" / "biomass_trajectory.csv"))
    if not files:
        return (0, 0, 0.0)
    n_active = n_total = 0
    for fpath in files:
        try:
            with open(fpath) as fp:
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


def evaluate(theta_log, tag, param_names, bay_dir, tools_dir, runner_name, timeout_s):
    tag_dir = bay_dir / tag
    tag_dir.mkdir(parents=True, exist_ok=True)
    theta_csv = tag_dir / "theta.csv"
    write_theta_csv(theta_log, param_names, theta_csv)
    runner = tools_dir / runner_name
    try:  # PERSEUS_TIMEOUT_GUARD
        proc = subprocess.run(["bash", str(runner), str(theta_csv), tag],
                              capture_output=True, text=True, timeout=timeout_s)
    except subprocess.TimeoutExpired:
        sys.stderr.write(f"TIMEOUT {tag}: runner exceeded {timeout_s}s; penalized\n")
        return DEGENERACY_PENALTY
    except Exception as _e:
        sys.stderr.write(f"FAIL {tag}: runner raised {_e!r}; penalized\n")
        return DEGENERACY_PENALTY

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
        (tag_dir / "active_growth.txt").write_text(
            f"n_active={n_active}\nn_total={n_total}\nfrac={frac:.4f}\n")
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
        sys.stderr.write(f"DEGEN {tag}: LL=0 with active_growth_frac={frac:.2f}; penalized\n")
        return DEGENERACY_PENALTY
    if frac < MIN_ACTIVE_GROWTH_FRAC and ll > -100:
        sys.stderr.write(f"DEGEN {tag}: LL={ll:.2f} with active_growth_frac={frac:.2f}; penalized\n")
        return DEGENERACY_PENALTY

    return -ll


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True, help="2-letter state code (reads its SpeciesData.csv)")
    p.add_argument("--tag", required=True, help="chain tag, e.g. in_t2_v1")
    p.add_argument("--warmstart", help="cluster reference theta CSV (param,value multipliers)")
    p.add_argument("--landis", default=LANDIS_DEFAULT)
    p.add_argument("--bayesian-dir", help="default: <landis>/states/<ST>/perseus/bayesian/<tag>")
    p.add_argument("--tools-dir", default=None)
    p.add_argument("--max-iter", type=int, default=8)
    p.add_argument("--population", type=int, default=14)
    p.add_argument("--sigma0", type=float, default=0.15)
    p.add_argument("--runner-timeout-h", type=float, default=4.0)
    p.add_argument("--resume", action="store_true")
    args = p.parse_args()

    state = args.state.upper()
    landis = args.landis
    tools = Path(args.tools_dir or os.path.join(landis, "tools"))
    bay = Path(args.bayesian_dir or os.path.join(landis, "states", state, "perseus", "bayesian", args.tag))
    bay.mkdir(parents=True, exist_ok=True)
    runner_name = f"run_param_set_{state}_t2.sh"
    if not (tools / runner_name).exists():
        sys.stderr.write(f"WARN: runner {tools/runner_name} not found; chain will penalize every candidate\n")

    species = read_species(state, landis)
    param_names = [f"ANPP_{s}" for s in species] + [f"BMAX_{s}" for s in species]
    n_params = len(param_names)
    timeout_s = int(args.runner_timeout_h * 3600)
    sys.stderr.write(f"state={state} species={len(species)} params={n_params} "
                     f"runner={runner_name} timeout={timeout_s}s\n")

    pickle_path = bay / "es.pickle"
    hist_path = bay / "cma_history.csv"

    if args.resume and pickle_path.exists():
        with open(pickle_path, "rb") as f: es = pickle.load(f)
        print(f"Resumed from {pickle_path}, evals so far: {es.countevals}", flush=True)
    else:
        x0 = read_warmstart(args.warmstart, param_names)
        opts = {"popsize": args.population, "maxiter": args.max_iter,
                "bounds": [[-1.5]*n_params, [1.5]*n_params], "verbose": -9}
        es = cma.CMAEvolutionStrategy(x0, args.sigma0, opts)

    if not hist_path.exists():
        with open(hist_path, "w", newline="") as f:
            csv.writer(f).writerow(["iter", "candidate", "tag", "negLL"] + param_names)

    while not es.stop():
        it = es.countiter
        cands = es.ask()
        fits = []
        for k, x in enumerate(cands):
            tag = f"{args.tag}_iter{it}_cand{k}"
            t0 = time.time()
            negLL = evaluate(x, tag, param_names, bay, tools, runner_name, timeout_s)
            fits.append(negLL)
            print(f"iter{it} cand{k} tag={tag} negLL={negLL:.2f} ({time.time()-t0:.0f}s)", flush=True)
            with open(hist_path, "a", newline="") as f:
                csv.writer(f).writerow([it, k, tag, f"{negLL:.2f}"] + [f"{math.exp(v):.4f}" for v in x])
        es.tell(cands, fits)
        with open(pickle_path, "wb") as f: pickle.dump(es, f)
        print(f"iter{it} best negLL: {min(fits):.2f}", flush=True)

    print("CMA-ES complete.")
    write_theta_csv(es.result.xbest, param_names, bay / "theta_best.csv")
    print(f"Wrote {bay / 'theta_best.csv'} — run harvest_t2_chains.py to select the production vector.")


if __name__ == "__main__":
    main()
