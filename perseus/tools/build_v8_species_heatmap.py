#!/usr/bin/env python3
"""build_v8_species_heatmap.py — final 3-state heatmap for v1.0 final release.

ME: T2 per-species (final, manuscript-grade)
WA: T2 per-species iter1_cand11 (n=805 plots, per-plot LL=-0.217)
GA: T1 uniform theta=0.30 (T2 attempted but failed pipeline sample size; see GA_T2_failure_memo.md)
"""
import csv
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from pathlib import Path

base = Path("/sessions/dazzling-peaceful-darwin/mnt/outputs/t2_final")

def load_theta(fp):
    d = {}
    with open(fp) as f:
        rdr = csv.DictReader(f)
        for r in rdr:
            param = r["param"]; v = float(r["value"])
            kind, spp = param.split("_", 1)
            d.setdefault(spp, {})[kind] = v
    return d

me = load_theta("/sessions/dazzling-peaceful-darwin/mnt/outputs/t2_progress/ME_T2_theta.csv")
wa = load_theta(base / "WA_T2_best_perplot_normalized_theta.csv")
# GA: uniform theta=0.30 applied across all species
GA_THETA_UNIFORM = 0.30
GA_SPP = ["AE","BC","BE","BG","BO","BSW","CO","EH","ERC","HK","LL","LO","MG","PO",
          "RM","RO","SL","SM","SO","SP","SY","TT","VP","WAO","WAS","WO","YB"]
ga = {s: {"ANPP": GA_THETA_UNIFORM, "BMAX": GA_THETA_UNIFORM} for s in GA_SPP}

print(f"ME: {len(me)} species, T2 per-species final")
print(f"WA: {len(wa)} species, T2 per-species iter1_cand11")
print(f"GA: {len(ga)} species, T1 uniform theta={GA_THETA_UNIFORM}")

ME_LABELS = {"BF":"Balsam fir","SM":"Sugar maple","BE":"American beech","RS":"Red spruce",
             "WS":"White spruce","BS":"Black spruce","CE":"Northern white cedar",
             "YB":"Yellow birch","RM":"Red maple","IH":"Intolerant hardwoods",
             "PINE":"Pine spp.","ASH":"Ash spp.","HE":"Eastern hemlock"}
WA_LABELS = {"DF":"Douglas-fir","WH":"Western hemlock","WC":"Western redcedar",
             "PSF":"Pacific silver fir","GF":"Grand fir","NF":"Noble fir",
             "SS":"Sitka spruce","ES":"Engelmann spruce","AF":"Subalpine fir",
             "WF":"White fir","LP":"Lodgepole pine","PP":"Ponderosa pine",
             "WP":"Western white pine","WBP":"Whitebark pine","MH":"Mountain hemlock",
             "WL":"Western larch","IC":"Incense cedar","PY":"Pacific yew",
             "BM":"Bigleaf maple","RA":"Red alder","PM":"Pacific madrone",
             "PB":"Paper birch","QA":"Quaking aspen","BCW":"Black cottonwood",
             "GO":"Oregon white oak"}
GA_LABELS = {"AE":"American elm","BC":"Black cherry","BE":"American beech","BG":"Blackgum",
             "BO":"Black oak","BSW":"Black tupelo","CO":"Chestnut oak","EH":"Eastern hemlock",
             "ERC":"Eastern redcedar","HK":"Hickory spp.","LL":"Longleaf pine","LO":"Live oak",
             "MG":"Magnolia","PO":"Post oak","RM":"Red maple","RO":"Red oak",
             "SL":"Sweetgum","SM":"Sweet bay","SO":"Scarlet oak","SP":"Shortleaf pine",
             "SY":"Sycamore","TT":"Tupelo","VP":"Virginia pine","WAO":"White oak",
             "WAS":"Water oak","WO":"Winged elm","YB":"Yellow birch"}

def panel_data(d):
    species = sorted(d.keys(), key=lambda s: -(d[s].get("ANPP", 0) + d[s].get("BMAX", 0)))
    anpp = np.array([d[s].get("ANPP", np.nan) for s in species])
    bmax = np.array([d[s].get("BMAX", np.nan) for s in species])
    mat = np.column_stack([anpp, bmax])
    return species, mat

def draw_panel(ax, d, title, labels, all_min, all_max):
    spp, mat = panel_data(d)
    full = [labels.get(s, s) for s in spp]
    im = ax.imshow(mat, cmap="RdBu_r", vmin=all_min, vmax=all_max, aspect="auto")
    ax.set_xticks([0, 1]); ax.set_xticklabels(["ANPP", "BMAX"], fontsize=10)
    ax.set_yticks(range(len(spp)))
    ax.set_yticklabels([f"{s} - {n}" for s, n in zip(spp, full)], fontsize=8)
    ax.set_title(title, fontsize=11, fontweight="bold", pad=8)
    for i in range(mat.shape[0]):
        for j in range(mat.shape[1]):
            v = mat[i, j]
            if not np.isnan(v):
                color = "white" if (v > 1.4 or v < 0.6) else "black"
                ax.text(j, i, f"{v:.2f}", ha="center", va="center", color=color, fontsize=7.5)
    return im

all_vals = []
for d in [me, wa, ga]:
    for spp in d.values():
        all_vals.extend([v for v in spp.values()])
all_vals = np.array(all_vals)
v_range = max(abs(1.0 - all_vals.min()), abs(all_vals.max() - 1.0)) + 0.05
vmin = 1.0 - v_range; vmax = 1.0 + v_range
print(f"Color scale: [{vmin:.2f}, {vmax:.2f}]")

fig, axes = plt.subplots(1, 3, figsize=(13, 9))
im = draw_panel(axes[0], me,
                "Maine — T2 per-species (final)\n26 params, 13 species\nLL=+34.2 over n=612",
                ME_LABELS, vmin, vmax)
draw_panel(axes[1], ga,
           "Georgia — T1 uniform theta=0.30 (final)\n54 species at uniform 0.30\nLL=+5.26 over n=218 (T2 attempt failed; see memo)",
           GA_LABELS, vmin, vmax)
draw_panel(axes[2], wa,
           "Washington — T2 per-species iter1_cand11 (final)\n50 params, 25 species\nLL=-174.4 over n=805 (per-plot=-0.217)",
           WA_LABELS, vmin, vmax)

cbar = fig.colorbar(im, ax=axes, location="bottom", shrink=0.45, pad=0.06,
                    label="Multiplier on default LANDIS-II value (1.0 = unchanged)")
cbar.ax.axvline(1.0, color="black", lw=1)

plt.suptitle("PERSEUS production calibrations — three-state comparison (v1.0 final, 2026-05-17)\n"
             "ME and WA Tier 2 per-species; GA Tier 1 uniform (Tier 2 deferred pending pipeline diagnostic)",
             fontsize=13, fontweight="bold", y=0.99)
out = base / "production_calibrations_3state_v1.0_final.png"
plt.savefig(out, dpi=180, bbox_inches="tight")
print(f"Wrote {out}")
