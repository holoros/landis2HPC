#!/usr/bin/env python3
"""build_cma_convergence_figure.py — CMA-ES convergence trajectories for WA + GA T2."""
import csv
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

base = Path("/sessions/dazzling-peaceful-darwin/mnt/outputs/t2_progress")

def load(fp):
    rows = []
    with open(fp) as f:
        rdr = csv.DictReader(f)
        for r in rdr:
            try:
                rows.append({"iter": int(r["iter"]), "cand": int(r["candidate"]),
                             "negLL": float(r["negLL"])})
            except: pass
    return rows

wa = load(base / "WA_T2_cma_history.csv")
ga = load(base / "GA_T2_cma_history.csv")

print(f"WA: {len(wa)} candidates, degen-flagged: {sum(1 for r in wa if r['negLL'] >= 1e5)}")
print(f"GA: {len(ga)} candidates, degen-flagged: {sum(1 for r in ga if r['negLL'] >= 1e5)}, "
      f"LL=0 (empty agg): {sum(1 for r in ga if abs(r['negLL']) < 0.01)}")

def best_per_iter(rows):
    by_iter = {}
    for r in rows:
        if r["negLL"] >= 1e5: continue  # skip DEGEN penalty
        by_iter.setdefault(r["iter"], []).append(r["negLL"])
    iters = sorted(by_iter)
    best = [min(by_iter[i]) for i in iters]
    cumbest = []
    cur = float("inf")
    for v in best:
        cur = min(cur, v)
        cumbest.append(cur)
    return iters, best, cumbest

# Filter out DEGEN candidates for scatter
wa_valid = [r for r in wa if r["negLL"] < 1e5]
ga_valid = [r for r in ga if r["negLL"] < 1e5]
wa_iters, wa_best, wa_cum = best_per_iter(wa)
ga_iters, ga_best, ga_cum = best_per_iter(ga)

fig, (ax_wa, ax_ga) = plt.subplots(2, 1, figsize=(9, 7.5))

# WA panel
ax_wa.scatter([r["iter"] for r in wa_valid], [r["negLL"] for r in wa_valid],
              alpha=0.35, s=20, c="#1f78b4", label="candidates")
ax_wa.plot(wa_iters, wa_cum, "o-", c="#08306b", lw=1.6, ms=6, label="cumulative best")
ax_wa.axhline(50.01, ls="--", c="darkred", alpha=0.5)
ax_wa.text(0.5, 45, "best so far: negLL=50.01 (LL=-50.0)",
           c="darkred", fontsize=9)
ax_wa.set_title(f"Washington T2 (resumed with patched driver) — "
                f"{len(wa)} candidates, {sum(1 for r in wa if r['negLL']>=1e5)} DEGEN flagged",
                fontweight="bold")
ax_wa.set_xlabel("CMA-ES iteration")
ax_wa.set_ylabel("negLL (lower is better)")
ax_wa.legend(loc="upper right")
ax_wa.grid(alpha=0.3)

# GA panel
ax_ga.scatter([r["iter"] for r in ga_valid], [r["negLL"] for r in ga_valid],
              alpha=0.35, s=20, c="#33a02c", label="candidates")
ax_ga.plot(ga_iters, ga_cum, "o-", c="#00441b", lw=1.6, ms=6, label="cumulative best")
ax_ga.axhline(-15.75, ls="--", c="darkred", alpha=0.5)
ax_ga.text(0.5, -17, "best so far: negLL=-15.75 (LL=+15.75)",
           c="darkred", fontsize=9)
ax_ga.set_title(f"Georgia T2 (original driver) — "
                f"{len(ga)} candidates, "
                f"{sum(1 for r in ga if abs(r['negLL'])<0.01)} LL=0 (empty aggregator), "
                f"{sum(1 for r in ga if r['negLL']>=1e5)} DEGEN flagged",
                fontweight="bold")
ax_ga.set_xlabel("CMA-ES iteration")
ax_ga.set_ylabel("negLL (lower is better)")
ax_ga.legend(loc="upper right")
ax_ga.grid(alpha=0.3)

plt.suptitle("PERSEUS T2 CMA-ES convergence trajectories (snapshot 2026-05-17 11:18 EDT)",
             fontsize=12, fontweight="bold", y=1.00)
plt.tight_layout()
out = base / "t2_cma_convergence_2026-05-17.png"
plt.savefig(out, dpi=180, bbox_inches="tight")
print(f"Wrote {out}")
