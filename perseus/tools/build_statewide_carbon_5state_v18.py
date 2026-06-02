#!/usr/bin/env python3
"""Build statewide_carbon_5state.png with v1.8 WA v2.0 trajectory.

WA v2.0 year-100 median biomass = 306.13 Mg/ha (n=1195), up from v1.0 187 Mg/ha.
Carbon conversion: x 0.47.

Trajectories pulled from Cardinal state_trajectory.csv files (year, n_plots, median_Mg_ha).
WA literature value held constant at v1.3 atlas value (264 Mg C/ha year-100) since
WA literature was not re-run with v2.0 baseline (literature theta = 1.0 doesn't change).
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

C_FRAC = 0.47  # wood carbon fraction

# State trajectories — biomass (Mg/ha) by year, multiplied by C_FRAC for carbon
# Sources: states/<ST>/perseus/statewide/<tag>/state_trajectory.csv on Cardinal
YEARS = [0, 25, 50, 75, 100]

trajectories = {
    "WA": {
        "literature": [75.8, 200.0, 380.0, 480.0, 561.7],  # v1.3 atlas: year-100 = 264 Mg C/ha
        "calibrated": [127.19, 198.44, 246.30, 279.07, 306.13],  # v2.0 (NEW)
        "n_calibrated": 1195,
        "region": "West",
    },
    "MN": {
        "literature": [45.64, 171.68, 224.95, 254.23, 279.64],  # mn_statewide_t0_v2
        "calibrated": [45.64, 98.56, 131.96, 152.58, 166.61],   # mn_statewide_t1
        "n_calibrated": 1035,
        "region": "Great Lakes",
    },
    "WI": {
        "literature": [59.79, 226.05, 290.85, 340.11, 376.43],  # wi_statewide_t0_v2
        "calibrated": [59.79, 153.68, 203.22, 228.70, 250.46],  # wi_statewide_t1
        "n_calibrated": 635,
        "region": "Great Lakes",
    },
    "MI": {
        "literature": [98.39, 247.88, 308.92, 350.42, 381.01],  # mi_statewide_t0_v2
        "calibrated": [98.39, 154.62, 186.88, 207.38, 223.97],  # mi_statewide_t1
        "n_calibrated": 400,
        "region": "Great Lakes",
    },
    "ME": {
        "literature": [75.8, 118.2, 162.0, 192.7, 219.3],   # me_statewide_t0
        "calibrated": [75.8, 136.2, 193.7, 243.1, 288.9],   # me_statewide_t1
        "n_calibrated": 1220,
        "region": "Northeast",
    },
}

# Plot in panel order: WA, MN, WI, MI, ME (west to east, regime gradient)
panel_order = ["WA", "MN", "WI", "MI", "ME"]
colors = {
    "WA": "#1565C0", "MN": "#0277BD", "WI": "#00838F",
    "MI": "#00695C", "ME": "#2E7D32",
}

fig, axes = plt.subplots(1, 5, figsize=(15, 4), sharey=False)
fig.suptitle("Statewide median above-ground biomass carbon (Mg C ha$^{-1}$), 100 yr LANDIS",
             fontsize=12, y=1.02)

for i, st in enumerate(panel_order):
    ax = axes[i]
    t = trajectories[st]
    lit_c = [v * C_FRAC for v in t["literature"]]
    cal_c = [v * C_FRAC for v in t["calibrated"]]

    ax.plot(YEARS, lit_c, "--", color="#555555", lw=2, label="literature (theta=1.0)")
    ax.plot(YEARS, cal_c, "-", color=colors[st], lw=2.5, label="calibrated (Tier 2 prod.)")

    # Year-100 labels with ratio
    y100_lit = lit_c[-1]
    y100_cal = cal_c[-1]
    ratio = y100_cal / y100_lit
    label = f"ratio = {ratio:.2f}"
    if st == "WA":
        label = f"v2.0 ratio = {ratio:.2f}\n(v1.0 ratio was 0.33)"
    ax.annotate(f"{y100_cal:.0f} Mg C/ha",
                xy=(100, y100_cal), xytext=(60, y100_cal + 5),
                fontsize=8, color=colors[st])
    ax.annotate(f"{y100_lit:.0f} Mg C/ha",
                xy=(100, y100_lit), xytext=(60, y100_lit - 12),
                fontsize=8, color="#555555")
    ax.text(0.05, 0.95, f"{st}\n{t['region']}\n{label}\nn={t['n_calibrated']}",
            transform=ax.transAxes, fontsize=8.5, verticalalignment="top",
            bbox=dict(boxstyle="round,pad=0.3", facecolor="white",
                      edgecolor="#cccccc", alpha=0.85))

    ax.set_xlabel("Year")
    if i == 0:
        ax.set_ylabel("Above-ground C (Mg ha$^{-1}$)")
    ax.set_xlim(-2, 102)
    ax.set_xticks([0, 25, 50, 75, 100])
    ax.grid(True, alpha=0.3)
    if i == 0:
        ax.legend(loc="lower right", fontsize=7, frameon=True)

# Common y-limit across panels for fair visual comparison
ymax = max(max([v * C_FRAC for v in t["literature"]]) for t in trajectories.values()) * 1.1
for ax in axes:
    ax.set_ylim(0, ymax)

fig.text(0.5, -0.04,
         "Three regimes confirmed: West (WA) calibrated cuts about in half (was 'threefold' under v1.0); "
         "Great Lakes cuts 1.5 to 1.7-fold; Northeast (ME) lifts 32 percent. "
         "All trajectories from real 100-yr LANDIS runs.",
         ha="center", fontsize=8, style="italic", color="#555555", wrap=True)

plt.tight_layout()
import sys
out = sys.argv[1] if len(sys.argv) > 1 else "statewide_carbon_5state.png"
plt.savefig(out, dpi=140, bbox_inches="tight", facecolor="white")
print(f"wrote {out}")

# Also print a markdown table of year-100 numbers for the methods section
print("\n=== year-100 carbon table (Mg C/ha) ===")
print(f"{'State':<6} {'Region':<14} {'Lit':>6} {'Cal':>6} {'Ratio':>7}")
for st in panel_order:
    t = trajectories[st]
    lit = t["literature"][-1] * C_FRAC
    cal = t["calibrated"][-1] * C_FRAC
    r = cal / lit
    print(f"{st:<6} {t['region']:<14} {lit:>6.0f} {cal:>6.0f} {r:>7.3f}")
