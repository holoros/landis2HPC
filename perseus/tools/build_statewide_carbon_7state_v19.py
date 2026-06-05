#!/usr/bin/env python3
"""Build statewide_carbon_7state.png — v1.9 addition of IN and OH panels.

Adds Indiana and Ohio to the 5-state figure from v1.8. IN+OH trajectories from the
v1.9 statewide carbon runs (jobs 11262262/63/64) with the v18b-hardened runner.
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import sys

C_FRAC = 0.47
YEARS = [0, 25, 50, 75, 100]

trajectories = {
    "WA": {
        "literature": [75.8, 200.0, 380.0, 480.0, 561.7],
        "calibrated": [127.19, 198.44, 246.30, 279.07, 306.13],
        "n_calibrated": 1195,
        "region": "West",
    },
    "MN": {
        "literature": [45.64, 171.68, 224.95, 254.23, 279.64],
        "calibrated": [45.64, 98.56, 131.96, 152.58, 166.61],
        "n_calibrated": 1035,
        "region": "Great Lakes",
    },
    "WI": {
        "literature": [59.79, 226.05, 290.85, 340.11, 376.43],
        "calibrated": [59.79, 153.68, 203.22, 228.70, 250.46],
        "n_calibrated": 635,
        "region": "Great Lakes",
    },
    "MI": {
        "literature": [98.39, 247.88, 308.92, 350.42, 381.01],
        "calibrated": [98.39, 154.62, 186.88, 207.38, 223.97],
        "n_calibrated": 400,
        "region": "Great Lakes",
    },
    "ME": {
        "literature": [75.8, 118.2, 162.0, 192.7, 219.3],
        "calibrated": [75.8, 136.2, 193.7, 243.1, 288.9],
        "n_calibrated": 1220,
        "region": "Northeast",
    },
    "IN": {
        "literature": [95.49, 370.00, 484.47, 580.62, 657.32],
        "calibrated": [96.28, 247.87, 304.59, 350.43, 403.33],
        "n_calibrated": 193,
        "region": "Eastern Hardwood (N3)",
    },
    "OH": {
        "literature": [92.42, 344.88, 451.57, 539.16, 617.48],
        "calibrated": [93.90, 219.12, 283.13, 324.93, 365.71],
        "n_calibrated": 173,
        "region": "Eastern Hardwood (N3)",
    },
}

panel_order = ["WA", "MN", "WI", "MI", "ME", "IN", "OH"]
colors = {
    "WA": "#1565C0", "MN": "#0277BD", "WI": "#00838F",
    "MI": "#00695C", "ME": "#2E7D32",
    "IN": "#5D4037", "OH": "#6D4C41",
}

fig, axes = plt.subplots(1, 7, figsize=(21, 4), sharey=True)
fig.suptitle("Statewide median above-ground biomass carbon (Mg C ha$^{-1}$), 100 yr LANDIS — v1.9 (7 states)",
             fontsize=12, y=1.02)

for i, st in enumerate(panel_order):
    ax = axes[i]
    t = trajectories[st]
    lit_c = [v * C_FRAC for v in t["literature"]]
    cal_c = [v * C_FRAC for v in t["calibrated"]]

    ax.plot(YEARS, lit_c, "--", color="#555555", lw=2, label="literature")
    ax.plot(YEARS, cal_c, "-", color=colors[st], lw=2.5, label="calibrated")

    y100_lit = lit_c[-1]
    y100_cal = cal_c[-1]
    ratio = y100_cal / y100_lit
    ax.text(0.05, 0.95, f"{st}\n{t['region']}\nratio = {ratio:.2f}\nn={t['n_calibrated']}",
            transform=ax.transAxes, fontsize=8, verticalalignment="top",
            bbox=dict(boxstyle="round,pad=0.3", facecolor="white",
                      edgecolor="#cccccc", alpha=0.85))
    ax.annotate(f"{y100_cal:.0f}", xy=(100, y100_cal), xytext=(72, y100_cal - 8),
                fontsize=7, color=colors[st])
    ax.annotate(f"{y100_lit:.0f}", xy=(100, y100_lit), xytext=(72, y100_lit + 5),
                fontsize=7, color="#555555")

    ax.set_xlabel("Year")
    if i == 0:
        ax.set_ylabel("Above-ground C (Mg ha$^{-1}$)")
    ax.set_xlim(-2, 102)
    ax.set_xticks([0, 25, 50, 75, 100])
    ax.grid(True, alpha=0.3)
    if i == 0:
        ax.legend(loc="lower right", fontsize=7, frameon=True)

ymax = max(max([v * C_FRAC for v in t["literature"]]) for t in trajectories.values()) * 1.1
for ax in axes:
    ax.set_ylim(0, ymax)

fig.text(0.5, -0.05,
         "Three regimes confirmed across 7 states: West (WA) ~half; Great Lakes (MN/WI/MI) 1.5 to 1.7-fold cut; "
         "Northeast (ME) +32 percent; Eastern Hardwood (IN/OH) 1.6 to 1.7-fold cut. "
         "IN and OH n much lower than others (~170-193 vs 400-1415) — bottomland plot failures from current SPCD lumping. v1.10 will retest with COTT+SIM extension.",
         ha="center", fontsize=8, style="italic", color="#555555")

plt.tight_layout()
out = sys.argv[1] if len(sys.argv) > 1 else "statewide_carbon_7state.png"
plt.savefig(out, dpi=140, bbox_inches="tight", facecolor="white")
print(f"wrote {out}")

print("\n=== year-100 carbon table (Mg C/ha) ===")
print(f"{'State':<6} {'Region':<24} {'Lit':>6} {'Cal':>6} {'Ratio':>7} {'n':>5}")
for st in panel_order:
    t = trajectories[st]
    lit = t["literature"][-1] * C_FRAC
    cal = t["calibrated"][-1] * C_FRAC
    r = cal / lit
    print(f"{st:<6} {t['region']:<24} {lit:>6.0f} {cal:>6.0f} {r:>7.3f} {t['n_calibrated']:>5}")
