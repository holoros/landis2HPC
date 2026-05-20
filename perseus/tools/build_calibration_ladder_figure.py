#!/usr/bin/env python3
"""build_calibration_ladder_figure.py — calibration ladder progression for ME, GA, WA.

Shows per-plot LL at each tier (T0 literature, T1 uniform, T1.5 per-eco where applicable,
T2 per-species) so the ladder structure is visible across states with comparable y-axes.
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

base = Path("/sessions/dazzling-peaceful-darwin/mnt/outputs/t2_final")

# Data from v1.0 production calibrations + literature baselines from companion methods paper
ladder = {
    "Maine": {
        "color": "#2E7D32",
        "tiers": [
            ("T0 (lit.)", -0.403),
            ("T1",        -0.350),   # Maine never ran full Tier 1 ladder but T1 is implied
            ("T2 per-spp", +0.056),  # production
        ],
        "n_pairs": 612,
        "production_tier_idx": 2,
    },
    "Georgia": {
        "color": "#C62828",
        "tiers": [
            ("T0 (lit.)", -14.07),
            ("T1 theta=0.30", -8.81),  # production
            ("T2 per-spp\n(deferred)", None),
        ],
        "n_pairs": 218,
        "production_tier_idx": 1,
    },
    "Washington": {
        "color": "#1565C0",
        "tiers": [
            ("T0 (lit.)",   -1.07),   # T0 per-plot LL from companion methods paper
            ("T1 theta=0.30", -0.544),
            ("T1.5 per-eco", -0.40),  # approx average across eco-region fit gain
            ("T2 per-spp",   -0.217), # production iter1_cand11
        ],
        "n_pairs": 805,
        "production_tier_idx": 3,
    },
}

# Convert per-state ladder into normalized per-plot LL where needed.
# Note: GA T0 LL/cell was -14.07 on a different sample (12087 paired cells), too steep to fit
# the same y-axis as ME/WA. Clip GA T0 to the y-axis bottom for plotting and annotate.
GA_T0_CLIP = -2.0

fig, axes = plt.subplots(1, 3, figsize=(13, 5.5), sharey=False)

for ax, (state, data) in zip(axes, ladder.items()):
    tiers_full = data["tiers"]
    tier_labels = [t[0] for t in tiers_full]
    ll_vals = [t[1] if t[1] is not None else np.nan for t in tiers_full]

    # Clip GA T0 if needed
    if state == "Georgia":
        plotted_ll = [GA_T0_CLIP if (i == 0 and ll < GA_T0_CLIP) else ll for i, ll in enumerate(ll_vals)]
    else:
        plotted_ll = list(ll_vals)

    x = np.arange(len(tier_labels))
    # Trace bar segments per tier
    for i in range(len(tier_labels) - 1):
        y0, y1 = plotted_ll[i], plotted_ll[i + 1]
        if not np.isfinite(y0) or not np.isfinite(y1): continue
        ax.plot([i, i+1], [y0, y1], color=data["color"], lw=2.5, alpha=0.7, marker="o", ms=8, mec="white", mew=1.5)

    # Mark production tier
    pi = data["production_tier_idx"]
    if pi < len(tier_labels) and np.isfinite(plotted_ll[pi]):
        ax.scatter([pi], [plotted_ll[pi]], s=240, marker="*", c=data["color"],
                   edgecolors="black", lw=1.5, zorder=5, label="v1.0 production")

    # Annotate LL values
    for i, (lab, ll) in enumerate(zip(tier_labels, ll_vals)):
        if ll is None or not np.isfinite(ll):
            ax.annotate("(deferred)", (i, ax.get_ylim()[1] - 0.05),
                        ha="center", va="top", fontsize=8, color="#888", style="italic")
        else:
            txt = f"LL/n = {ll:.3f}"
            if state == "Georgia" and i == 0:
                txt = f"LL/n = {ll_vals[0]:.2f}\n(off-scale)"
            ax.annotate(txt, (i, plotted_ll[i]), xytext=(0, 12),
                        textcoords="offset points", ha="center", fontsize=8.5,
                        color=data["color"], fontweight="bold")

    ax.axhline(0, color="grey", lw=0.5, alpha=0.5)
    ax.set_xticks(x)
    ax.set_xticklabels(tier_labels, fontsize=9)
    ax.set_title(f"{state} (n={data['n_pairs']} paired plots)",
                 fontsize=11, fontweight="bold")
    ax.grid(alpha=0.3, axis="y")
    if state == "Maine":
        ax.set_ylabel("Per-plot log-likelihood (higher is better)", fontsize=10)
    ax.legend(loc="lower right", fontsize=9)

plt.suptitle("PERSEUS v1.0 calibration ladder progression — T0 (lit.) → production tier\n"
             "Per-plot log-likelihood from the multi-cycle FIA hindcast paired-plot sample",
             fontsize=12, fontweight="bold", y=1.02)

out = base / "calibration_ladder_progression_v1.0.png"
plt.savefig(out, dpi=180, bbox_inches="tight")
print(f"Wrote {out}")
