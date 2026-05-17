#!/usr/bin/env python3
"""tier15_per_ecoregion_refit.py — per-ecoregion θ from existing ladder.

For each ecoregion, identifies the θ value (from the existing ladder) that
maximizes per-ecoregion LL. Produces a Tier 1.5 calibration vector without
requiring any new LANDIS runs.

Usage:
  python3 tier15_per_ecoregion_refit.py \\
    --state WA \\
    --pred-pattern 'wa_t1_{theta}.csv' \\
    --thetas '0.40,0.50,0.65,0.75,0.85,1.00' \\
    --obs untreated_plots_WA.csv \\
    --summary _summary.csv \\
    --plot-to-eco plot_to_ecoregion_WA.csv \\
    --out wa_t15_per_eco.csv
"""
import argparse, csv, math
from collections import defaultdict

TAG_MAP = {0.10:"t0_10", 0.15:"t0_15", 0.20:"t0_20", 0.25:"t0_25",
           0.30:"t0_30", 0.40:"t0_40", 0.45:"t0_45", 0.50:"t0_50",
           0.65:"t0_65", 0.75:"t0_75", 0.85:"t0_85", 1.00:"t1_00"}

def ll_normal(resids):
    if not resids: return None
    n = len(resids); m = sum(resids) / n
    var = sum((r-m)**2 for r in resids) / max(n-1, 1)
    sd = math.sqrt(var) if var > 0 else 1e-6
    return sum(-0.5*((r-m)/sd)**2 - math.log(sd) - 0.5*math.log(2*math.pi) for r in resids)

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--state", required=True)
    p.add_argument("--pred-pattern", required=True)
    p.add_argument("--thetas", required=True)
    p.add_argument("--obs", required=True)
    p.add_argument("--summary", required=True)
    p.add_argument("--plot-to-eco", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()

    thetas = [float(t) for t in args.thetas.split(",")]
    pid_to_cn = {r["plot_id"]: r["plt_cn"].strip() for r in csv.DictReader(open(args.summary))}
    pid_to_eco = {r["plot_id"]: int(r["eco"].strip()) for r in csv.DictReader(open(args.plot_to_eco)) if r["eco"].strip().isdigit()}

    cn_to_invyr = {}; obs_data = {}
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

    # Per-θ, per-ecoregion residuals
    by_theta_eco = {t: defaultdict(list) for t in thetas}
    for t in thetas:
        path = args.pred_pattern.format(theta=TAG_MAP[t])
        for r in csv.DictReader(open(path)):
            pid = r["plot_id"]; cn = pid_to_cn.get(pid); eco = pid_to_eco.get(pid)
            if not cn or cn not in obs_data or eco is None: continue
            invyr = cn_to_invyr.get(cn, 0)
            if invyr <= 0: continue
            for k, v in r.items():
                if not k.startswith("BIOM_yr"): continue
                try:
                    y = int(k[7:]); pred = float(v)
                except: continue
                obs = obs_data[cn].get(invyr + y)
                if obs and obs > 0 and pred > 0:
                    by_theta_eco[t][eco].append(math.log(pred) - math.log(obs))

    # For each ecoregion, find the θ that maximizes LL
    all_ecos = sorted(set(e for d in by_theta_eco.values() for e in d.keys()))
    print(f"\nTier 1.5 per-ecoregion calibration for {args.state}\n")
    print(f"{'eco':>4s} | {'n_cells':>7s} | " + " | ".join(f"{'θ=':>4s}{t:.2f}_LL/c" for t in thetas) + " | best_θ | gain_vs_state")
    print("-" * (16 + 13*len(thetas) + 24))

    state_best = sorted(thetas, key=lambda t: -ll_normal([r for e in by_theta_eco[t].values() for r in e]) / max(1, sum(len(e) for e in by_theta_eco[t].values())))[0]
    state_best_lls = {e: ll_normal(by_theta_eco[state_best].get(e, [])) for e in all_ecos}

    rows = []
    for eco in all_ecos:
        n = len(by_theta_eco[thetas[0]].get(eco, []))
        if n < 10: continue
        per_t = {t: ll_normal(by_theta_eco[t].get(eco, [])) for t in thetas}
        valid = {t: v for t, v in per_t.items() if v is not None}
        best_t = max(valid, key=valid.get)
        best_ll = valid[best_t]
        gain = best_ll - (state_best_lls.get(eco) or 0)
        rows.append({"eco": eco, "n_cells": n, "best_theta": best_t,
                     "best_LL_per_cell": round(best_ll / n, 4),
                     "state_theta_LL_per_cell": round((state_best_lls[eco] or 0) / n, 4),
                     "gain_LL_per_cell": round((best_ll - (state_best_lls[eco] or 0))/n, 4)})
        per_t_str = " | ".join(f"{(per_t[t] or 0)/max(n,1):>9.3f}" for t in thetas)
        print(f"{eco:>4d} | {n:>7d} | {per_t_str} | {best_t:>6.2f} | {gain:>+10.1f}")

    print(f"\nState-wide best θ = {state_best:.2f}")
    total_gain = sum(r["gain_LL_per_cell"] * r["n_cells"] for r in rows)
    total_n = sum(r["n_cells"] for r in rows)
    print(f"Total LL gain from per-eco vs state-wide: {total_gain:.1f} ({total_gain/total_n:.4f} per cell)")

    with open(args.out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()) if rows else [])
        w.writeheader(); w.writerows(rows)
    print(f"\nWrote {args.out}")

if __name__ == "__main__":
    main()
