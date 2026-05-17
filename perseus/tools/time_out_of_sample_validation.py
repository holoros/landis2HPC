#!/usr/bin/env python3
"""time_out_of_sample_validation.py — temporal hold-out validation.

Split the multi-cycle FIA paired observations into train (2001-2015) and test
(2016-2022) sets. For a fixed calibration θ vector (e.g., Tier 2 best), compute
LL on both sets. If test LL/cell is comparable to train LL/cell, the model
generalizes across the inventory cycle; if not, it's exploiting time-period-
specific patterns.

Usage:
  python3 time_out_of_sample_validation.py \\
    --pred wa_t2_per_plot.csv \\
    --obs untreated_plots_WA.csv \\
    --summary _summary.csv \\
    --train-cutoff 2015 \\
    --out wa_t2_time_oos.json
"""
import argparse, csv, json, math

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--pred", required=True)
    p.add_argument("--obs", required=True)
    p.add_argument("--summary", required=True)
    p.add_argument("--train-cutoff", type=int, default=2015)
    p.add_argument("--out", default=None)
    args = p.parse_args()

    # Load plot_id → plt_cn → invyr
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

    # Build paired cells, separately for train + test
    train_resids = []
    test_resids = []
    for r in csv.DictReader(open(args.pred)):
        pid = r["plot_id"]
        cn = pid_to_cn.get(pid)
        if not cn or cn not in cn_to_obs: continue
        invyr = cn_to_invyr.get(cn, 0)
        if invyr <= 0: continue
        for k, v in r.items():
            if not k.startswith("BIOM_yr"): continue
            try:
                y_landis = int(k[7:]); pred = float(v)
            except: continue
            cal = invyr + y_landis
            obs = cn_to_obs[cn].get(cal)
            if not obs or obs <= 0 or pred <= 0: continue
            resid = math.log(pred) - math.log(obs)
            if cal <= args.train_cutoff:
                train_resids.append((pid, cal, pred, obs, resid))
            else:
                test_resids.append((pid, cal, pred, obs, resid))

    def stats(resids, label):
        if not resids: return None
        rs = [r[4] for r in resids]
        n = len(rs)
        mean = sum(rs) / n
        var = sum((r - mean)**2 for r in rs) / max(n-1, 1)
        sd = math.sqrt(var) if var > 0 else 1e-6
        # LL using SAME (mean, sd) for both train and test means we're testing
        # whether the test set residuals look like the train residuals (a fair test).
        # For honest hold-out, the test LL uses train (mean, sd):
        return {"label": label, "n": n, "mean": mean, "sd": sd}

    train_stats = stats(train_resids, "train")
    test_stats = stats(test_resids, "test")

    # Honest hold-out LL: use train (mean, sd) to compute test LL
    if train_stats and test_stats:
        m, s = train_stats["mean"], train_stats["sd"]
        train_LL = sum(-0.5*((r-m)/s)**2 - math.log(s) - 0.5*math.log(2*math.pi)
                       for _,_,_,_,r in train_resids)
        test_LL = sum(-0.5*((r-m)/s)**2 - math.log(s) - 0.5*math.log(2*math.pi)
                      for _,_,_,_,r in test_resids)
        train_stats["LL"] = round(train_LL, 2)
        train_stats["LL_per_cell"] = round(train_LL / train_stats["n"], 4)
        test_stats["LL"] = round(test_LL, 2)
        test_stats["LL_per_cell"] = round(test_LL / test_stats["n"], 4)

    print(f"Train (≤{args.train_cutoff}): {train_stats}")
    print(f"Test  (>{args.train_cutoff}): {test_stats}")

    if test_stats and train_stats:
        ratio = test_stats["LL_per_cell"] / train_stats["LL_per_cell"]
        print(f"Test/Train LL-per-cell ratio: {ratio:.3f}")
        print(f"Interpretation: {'no temporal extrapolation issue' if abs(ratio - 1.0) < 0.20 else 'CHECK temporal extrapolation' }")

    if args.out:
        with open(args.out, "w") as f:
            json.dump({"train": train_stats, "test": test_stats,
                       "train_cutoff": args.train_cutoff}, f, indent=2)
        print(f"Wrote {args.out}")

if __name__ == "__main__":
    main()
