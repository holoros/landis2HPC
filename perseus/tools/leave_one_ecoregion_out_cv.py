#!/usr/bin/env python3
"""leave_one_ecoregion_out_cv.py — leave-one-ecoregion-out cross-validation.

Tests spatial transferability of the calibration. For each ecoregion in a state,
holds out all plots in that ecoregion and computes the held-out LL using the
calibration that was fit on the remaining ecoregions.

Shortcut implementation: rather than re-fitting Tier 2 for each held-out fold
(which would require N_eco × full CMA-ES runs), this script uses the full-data
Tier 2 θ vector and evaluates LL on each ecoregion subset. This isolates whether
the calibration's per-ecoregion fit is uniform across ecoregions or whether
some ecoregions have systematically worse fit, which is the policy-relevant
question.

Usage:
  python3 leave_one_ecoregion_out_cv.py \\
    --pred wa_t2_per_plot.csv \\
    --obs untreated_plots_WA.csv \\
    --summary _summary.csv \\
    --plot-to-eco plot_to_ecoregion_WA.csv \\
    --out wa_t2_leave_eco_out.csv
"""
import argparse, csv, math
from collections import defaultdict

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--pred", required=True)
    p.add_argument("--obs", required=True)
    p.add_argument("--summary", required=True)
    p.add_argument("--plot-to-eco", required=True)
    p.add_argument("--out", required=True)
    args = p.parse_args()

    pid_to_eco = {r["plot_id"]: int(r["eco"].strip()) for r in csv.DictReader(open(args.plot_to_eco)) if r["eco"].strip().isdigit()}
    pid_to_cn = {r["plot_id"]: r["plt_cn"].strip() for r in csv.DictReader(open(args.summary))}
    cn_to_invyr = {}
    cn_to_obs = {}
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
        if cn and d: cn_to_obs[cn] = d

    # Build residuals by ecoregion
    by_eco_resids = defaultdict(list)
    for r in csv.DictReader(open(args.pred)):
        pid = r["plot_id"]
        cn = pid_to_cn.get(pid)
        eco = pid_to_eco.get(pid)
        if not cn or cn not in cn_to_obs or eco is None: continue
        invyr = cn_to_invyr.get(cn, 0)
        if invyr <= 0: continue
        for k, v in r.items():
            if not k.startswith("BIOM_yr"): continue
            try:
                y_landis = int(k[7:]); pred = float(v)
            except: continue
            obs = cn_to_obs[cn].get(invyr + y_landis)
            if not obs or obs <= 0 or pred <= 0: continue
            by_eco_resids[eco].append(math.log(pred) - math.log(obs))

    # For each ecoregion: hold it out, fit (mean, sd) on remaining, score held-out LL
    rows = []
    ecos = sorted(by_eco_resids.keys())
    all_resids = [r for eco in ecos for r in by_eco_resids[eco]]

    for eco in ecos:
        train = [r for e in ecos if e != eco for r in by_eco_resids[e]]
        test = by_eco_resids[eco]
        if len(train) < 30 or len(test) < 10:
            print(f"  eco {eco}: too few cells, skip"); continue
        n_t = len(train)
        mean_t = sum(train) / n_t
        sd_t = math.sqrt(sum((r-mean_t)**2 for r in train) / max(n_t-1, 1))
        # Test LL with held-out residuals against train (mean, sd)
        test_LL = sum(-0.5*((r-mean_t)/sd_t)**2 - math.log(sd_t) - 0.5*math.log(2*math.pi) for r in test)
        # Compute test residual stats independently
        n_h = len(test)
        mean_h = sum(test)/n_h
        sd_h = math.sqrt(sum((r-mean_h)**2 for r in test) / max(n_h-1, 1))
        rows.append({
            "eco_held_out": eco,
            "n_train": n_t,
            "n_test": n_h,
            "train_mean": round(mean_t, 4),
            "train_sd": round(sd_t, 4),
            "test_mean": round(mean_h, 4),
            "test_sd": round(sd_h, 4),
            "test_LL": round(test_LL, 2),
            "test_LL_per_cell": round(test_LL / n_h, 4),
        })
        print(f"  eco {eco}: train n={n_t} mean={mean_t:+.3f} sd={sd_t:.3f}; "
              f"test n={n_h} mean={mean_h:+.3f} sd={sd_h:.3f}; LL/cell={test_LL/n_h:+.3f}")

    with open(args.out, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()) if rows else [])
        w.writeheader(); w.writerows(rows)
    print(f"\nWrote {args.out}")

if __name__ == "__main__":
    main()
