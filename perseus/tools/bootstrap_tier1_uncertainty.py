#!/usr/bin/env python3
"""bootstrap_tier1_uncertainty.py — Bootstrap CI on the Tier 1 optimum θ.

For each bootstrap iteration:
  1. Resample plots with replacement.
  2. Construct paired residuals from the resampled plot set across the existing
     ladder of θ values (θ ∈ {0.30, 0.40, 0.45, 0.50, 0.65, 0.75, 0.85, 1.00}).
  3. Fit a parabola to the (θ, LL) ladder and identify the optimum θ*.
  4. Record θ*.

After 1000 iterations, the empirical distribution of θ* gives the 95% CI for
the Tier 1 optimum. This addresses the reviewer concern "how confident are you
that θ ≈ 0.40 vs θ ≈ 0.35 vs θ ≈ 0.45?".

For this to work, we need per-plot LL contributions at each θ. We compute
these by reading each θ's per_plot.csv, computing the log-residual at each
paired cell, and grouping by plot_id.

Usage:
  python3 bootstrap_tier1_uncertainty.py \\
    --state WA \\
    --pred-pattern 'wa_t1_{theta}.csv' \\
    --thetas '0.50,0.65,0.75,0.85,1.00' \\
    --obs untreated_plots_WA.csv \\
    --summary _summary.csv \\
    --n-boot 1000 \\
    --out wa_t1_bootstrap_ci.csv
"""
import argparse, csv, math, random
from collections import defaultdict

def load_resids_per_plot(pred_path, obs_data, pid_to_cn, cn_to_invyr):
    plot_resids = defaultdict(list)
    for r in csv.DictReader(open(pred_path)):
        pid = r["plot_id"]; cn = pid_to_cn.get(pid)
        if not cn or cn not in obs_data: continue
        invyr = cn_to_invyr.get(cn, 0)
        if invyr <= 0: continue
        for k, v in r.items():
            if not k.startswith("BIOM_yr"): continue
            try:
                y = int(k[7:]); p = float(v)
            except: continue
            obs = obs_data[cn].get(invyr + y)
            if obs and obs > 0 and p > 0:
                plot_resids[pid].append(math.log(p) - math.log(obs))
    return plot_resids

def ll_of_residuals(resids):
    if not resids: return None
    n = len(resids); m = sum(resids) / n
    var = sum((r-m)**2 for r in resids) / max(n-1, 1)
    sd = math.sqrt(var) if var > 0 else 1e-6
    return sum(-0.5*((r-m)/sd)**2 - math.log(sd) - 0.5*math.log(2*math.pi) for r in resids)

def parabola_minimum(thetas, lls):
    # Fit quadratic y = a*x^2 + b*x + c and return -b/(2a)
    n = len(thetas)
    if n < 3: return None
    sx = sum(thetas); sy = sum(lls)
    sx2 = sum(t*t for t in thetas); sx3 = sum(t**3 for t in thetas); sx4 = sum(t**4 for t in thetas)
    sxy = sum(t*l for t,l in zip(thetas, lls))
    sx2y = sum(t*t*l for t,l in zip(thetas, lls))
    # Normal equations
    import numpy as np
    A = np.array([[sx4, sx3, sx2], [sx3, sx2, sx], [sx2, sx, n]])
    b = np.array([sx2y, sxy, sy])
    try: a, bcoef, c = np.linalg.solve(A, b)
    except: return None
    if a >= 0: return None  # not a minimum (LL is concave-up → minimum)
    return -bcoef / (2*a)

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True)
    p.add_argument("--pred-pattern", required=True, help="e.g., wa_t1_{theta}.csv with {theta} = t0_50 etc.")
    p.add_argument("--thetas", required=True, help="comma-separated θ values")
    p.add_argument("--obs", required=True)
    p.add_argument("--summary", required=True)
    p.add_argument("--n-boot", type=int, default=1000)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", required=True)
    args = p.parse_args()

    thetas = [float(t) for t in args.thetas.split(",")]
    rng = random.Random(args.seed)

    # Load obs
    cn_to_invyr = {}
    obs_data = {}
    for r in csv.DictReader(open(args.obs)):
        cn = (r.get("FIRST_PLTCN") or r.get("PLT_CN", "")).strip()
        try: cn_to_invyr[cn] = int(r.get("FIRST_INVYR") or 0)
        except: pass
        d = {}
        for k, v in r.items():
            if k.startswith("BIOM_") and k.endswith("_Mgha") and v not in ("", None):
                try:
                    yr = int(k.split("_")[1]); b = float(v)
                    if b > 0: d[yr] = b
                except: pass
        if cn and d: obs_data[cn] = d
    pid_to_cn = {r["plot_id"]: r["plt_cn"].strip() for r in csv.DictReader(open(args.summary))}

    # Load per-θ per-plot residuals
    per_theta_resids = {}
    for t in thetas:
        tag = f"t{int(t*100):02d}_{int(t*100)%100:02d}".replace("t100_00", "t1_00")
        # Simpler: map by index
        tag_map = {0.30:"t0_30", 0.40:"t0_40", 0.45:"t0_45", 0.50:"t0_50",
                   0.65:"t0_65", 0.75:"t0_75", 0.85:"t0_85", 1.00:"t1_00"}
        path = args.pred_pattern.format(theta=tag_map[t])
        per_theta_resids[t] = load_resids_per_plot(path, obs_data, pid_to_cn, cn_to_invyr)
        n_plots = len(per_theta_resids[t])
        n_cells = sum(len(v) for v in per_theta_resids[t].values())
        print(f"θ={t}: {n_plots} plots, {n_cells} cells")

    # Plots present in all θs
    common_plots = set.intersection(*[set(d.keys()) for d in per_theta_resids.values()])
    print(f"Common plots across all θ: {len(common_plots)}")

    # Bootstrap
    opt_thetas = []
    argmin_thetas = []  # fallback: argmin θ across ladder
    common_list = list(common_plots)
    for b in range(args.n_boot):
        sample = [rng.choice(common_list) for _ in range(len(common_list))]
        # Build LL vs θ
        lls = []
        for t in thetas:
            all_resids = [r for pid in sample for r in per_theta_resids[t].get(pid, [])]
            lls.append(ll_of_residuals(all_resids) if all_resids else None)
        # Filter out None
        valid = [(t, l) for t, l in zip(thetas, lls) if l is not None]
        if len(valid) < 3:
            continue
        ts, ls = zip(*valid)
        # Argmax LL across ladder
        argmin_idx = max(range(len(ls)), key=lambda i: ls[i])
        argmin_thetas.append(ts[argmin_idx])
        # Parabola fit (only valid if minimum is in interior)
        opt = parabola_minimum(list(ts), list(ls))
        if opt is not None and 0.1 <= opt <= 1.5:
            opt_thetas.append(opt)
        if (b+1) % 100 == 0:
            n_par = len(opt_thetas); n_arg = len(argmin_thetas)
            print(f"  iter {b+1}: parabola n={n_par}, argmin n={n_arg}")

    opt_thetas.sort()
    argmin_thetas.sort()

    if len(opt_thetas) >= 50:
        ci_lo = opt_thetas[int(len(opt_thetas)*0.025)]
        median = opt_thetas[len(opt_thetas)//2]
        ci_hi = opt_thetas[int(len(opt_thetas)*0.975)]
        print(f"\n{args.state} Tier 1 optimum θ (parabola): {median:.3f} (95% CI {ci_lo:.3f} – {ci_hi:.3f}, n={len(opt_thetas)} valid)")
    else:
        print(f"\nParabola insufficient: only {len(opt_thetas)} valid bootstraps")

    if len(argmin_thetas) >= 50:
        from collections import Counter
        cnt = Counter(argmin_thetas)
        modal = max(cnt, key=cnt.get)
        print(f"{args.state} Tier 1 optimum θ (argmin LL across ladder):")
        for t in sorted(cnt.keys()):
            pct = 100*cnt[t]/len(argmin_thetas)
            print(f"  θ={t}: {cnt[t]} bootstraps ({pct:.1f}%){'  ← modal' if t==modal else ''}")

    with open(args.out, "w") as f:
        f.write("bootstrap_iter,theta_star_parabola,theta_argmin\n")
        n = max(len(opt_thetas), len(argmin_thetas))
        for i in range(n):
            p = opt_thetas[i] if i < len(opt_thetas) else ""
            a = argmin_thetas[i] if i < len(argmin_thetas) else ""
            f.write(f"{i},{p},{a}\n")
    print(f"Wrote {args.out}")

if __name__ == "__main__":
    main()
