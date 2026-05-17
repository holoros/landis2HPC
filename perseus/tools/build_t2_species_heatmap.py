#!/usr/bin/env python3
"""build_t2_species_heatmap.py — 3-panel T2 species multiplier heatmap (ME final + WA/GA RC1)."""
import csv
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

base = Path("/sessions/dazzling-peaceful-darwin/mnt/outputs/t2_progress")

def load_theta(fp):
    """Read param,value CSV and return dict {species: {ANPP: x, BMAX: y}}."""
    d = {}
    with open(fp) as f:
        rdr = csv.DictReader(f)
        for r in rdr:
            param = r["param"]; v = float(r["value"])
            kind, spp = param.split("_", 1)
            d.setdefault(spp, {})[kind] = v
    return d

me = load_theta(base / "ME_T2_theta.csv")
wa = load_theta(base / "WA_T2_rc1_theta.csv")
ga = load_theta(base / "GA_T2_rc1_theta.csv")

print(f"ME: {len(me)} species")
print(f"WA: {len(wa)} species")
print(f"GA: {len(ga)} species")

ME_LABELS = {
    "BF": "Balsam fir", "SM": "Sugar maple", "BE": "American beech",
    "RS": "Red spruce", "WS": "White spruce", "BS": "Black spruce",
    "CE": "Northern white cedar", "YB": "Yellow birch", "RM": "Red maple",
    "IH": "Intolerant hardwoods", "PINE": "Pine spp.", "ASH": "Ash spp.",
    "HE": "Eastern hemlock"
}
WA_LABELS = {
    "DF": "Douglas-fir", "WH": "Western hemlock", "WC": "Western redcedar",
    "PSF": "Pacific silver fir", "GF": "Grand fir", "NF": "Noble fir",
    "SS": "Sitka spruce", "ES": "Engelmann spruce", "AF": "Subalpine fir",
    "WF": "White fir", "LP": "Lodgepole pine", "PP": "Ponderosa pine",
    "WP": "Western white pine", "WBP": "Whitebark pine", "MH": "Mountain hemlock",
    "WL": "Western larch", "IC": "Incense cedar", "PY": "Pacific yew",
    "BM": "Bigleaf maple", "RA": "Red alder", "PM": "Pacific madrone",
    "PB": "Paper birch", "QA": "Quaking aspen", "BCW": "Black cottonwood",
    "GO": "Oregon white oak"
}
GA_LABELS = {
    "AE": "American elm", "BC": "Black cherry", "BE": "American beech",
    "BG": "Blackgum", "BO": "Black oak", "BSW": "Black tupelo / sweetgum",
    "CO": "Chestnut oak", "EH": "Eastern hemlock", "ERC": "Eastern redcedar",
    "HK": "Hickory spp.", "LL": "Longleaf pine", "LO": "Live oak",
    "MG": "Magnolia", "PO": "Post oak", "RM": "Red maple", "RO": "Red oak",
    "SL": "Sweetgum / loblolly", "SM": "Sweetgum / maple", "SO": "Scarlet oak",
    "SP": "Shortleaf pine", "SY": "Sycamore", "TT": "Tupelo",
    "VP": "Virginia pine", "WAO": "White oak", "WAS": "Water oak",
    "WO": "Winged elm / WO", "YB": "Yellow birch"
}

def panel_data(d):
    species = sorted(d.keys(), key=lambda s: -(d[s].get("ANPP", 0) + d[s].get("BMAX", 0)))
    anpp = np.array([d[s].get("ANPP", np.nan) for s in species])
    bmax = np.array([d[s].get("BMAX", np.nan) for s in species])
    mat = np.column_stack([anpp, bmax])
    return species, mat

def draw_panel(ax, d, title, labels, all_min, all_max):
    spp, mat = panel_data(d)
    full_names = [labels.get(s, s) for s in spp]
    # Color map: diverging around 1.0
    im = ax.imshow(mat, cmap="RdBu_r", vmin=all_min, vmax=all_max, aspect="auto")
    ax.set_xticks([0, 1]); ax.set_xticklabels(["ANPP", "BMAX"], fontsize=10)
    ax.set_yticks(range(len(spp)))
    ax.set_yticklabels([f"{s} - {n}" for s, n in zip(spp, full_names)], fontsize=8)
    ax.set_title(title, fontsize=11, fontweight="bold", pad=8)
    # Annotate cells
    for i in range(mat.shape[0]):
        for j in range(mat.shape[1]):
            v = mat[i, j]
            if not np.isnan(v):
                color = "white" if (v > 1.4 or v < 0.6) else "black"
                ax.text(j, i, f"{v:.2f}", ha="center", va="center",
                        color=color, fontsize=7.5)
    return im

# Compute common color scale
all_vals = []
for d in [me, wa, ga]:
    for spp in d.values():
        all_vals.extend([v for v in spp.values() if v is not None])
all_vals = np.array(all_vals)
vmin, vmax = max(0.1, all_vals.min() - 0.05), min(3.0, all_vals.max() + 0.05)
# Center diverging palette at 1.0
v_range = max(abs(1.0 - vmin), abs(vmax - 1.0))
vmin = 1.0 - v_range; vmax = 1.0 + v_range
print(f"Color scale: [{vmin:.2f}, {vmax:.2f}], centered at 1.0")

fig, axes = plt.subplots(1, 3, figsize=(13, 9))
im = draw_panel(axes[0], me,
                "Maine (T2 final)\n26 params, 13 species\nbest negLL: -34.2 (LL=+34.2)",
                ME_LABELS, vmin, vmax)
draw_panel(axes[1], ga,
           "Georgia (T2 rc1)\n54 params, 27 species\nbest negLL: -15.75 (LL=+15.75)",
           GA_LABELS, vmin, vmax)
draw_panel(axes[2], wa,
           "Washington (T2 rc1)\n50 params, 25 species\nbest negLL: 50.01 (LL=-50.0)",
           WA_LABELS, vmin, vmax)

cbar = fig.colorbar(im, ax=axes, location="bottom", shrink=0.45, pad=0.06,
                    label="Multiplier on default LANDIS-II value (1.0 = unchanged)")
cbar.ax.axvline(1.0, color="black", lw=1)

plt.suptitle("PERSEUS Tier 2 per-species multipliers — three-state comparison\n"
             "(Maine final · Georgia & Washington v1.0-rc1 snapshot 2026-05-17)",
             fontsize=13, fontweight="bold", y=0.99)
out = base / "t2_species_heatmap_3state_2026-05-17.png"
plt.savefig(out, dpi=180, bbox_inches="tight")
print(f"Wrote {out}")
