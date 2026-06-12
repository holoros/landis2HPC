#!/usr/bin/env python3
# extract_me_reserve.py
#
# ME was run on the older full-landscape per-plot harness, not the MN-family
# single-cell harness, so it has no biomass_trajectory.csv for landis_adapter.R.
# But every ME per-plot run already wrote a LANDIS spp-biomass-log.csv with
# per-timestep aboveground biomass by species. This reads the baseline (current
# climate, no harvest = reserve) runs, sums species to a per-plot total biomass
# trajectory, converts to carbon per ha, maps plot_id -> PLT_CN, and emits the
# common reserve schema (model,scenario,PLT_CN,year,agc_MgC_ha) that
# build_landis_reserve_perha.R consumes. No LANDIS re-run needed.
#
#   agc_MgC_ha = sum_species(AboveGroundBiomass) [g/m2] * 0.01 (g/m2 -> Mg/ha) * 0.5 (carbon)
#   year       = 2025 + Time, kept through 2100 (harmonized horizon)

import csv, glob, os

ME   = "/fs/scratch/PUOM0008/crsfaaron/landis2/states/ME/perseus"
RUNS = os.path.join(ME, "round2_runs_eco_v2")
SUMM = os.path.join(ME, "round2_plot_ics", "_summary.csv")
OUT  = "/fs/scratch/PUOM0008/crsfaaron/FIA/landis_ME_reserve.csv"
CFRAC = 0.5

p2cn = {str(r["plot_id"]): str(r["plt_cn"]) for r in csv.DictReader(open(SUMM))}

rows, used, miss_cn, miss_log = [], 0, 0, 0
for d in glob.glob(os.path.join(RUNS, "*__clim_baseline_harv_none")):
    pid = os.path.basename(d).split("__")[0].replace("plot_", "")
    cn = p2cn.get(pid)
    if cn is None:
        miss_cn += 1; continue
    f = os.path.join(d, "spp-biomass-log.csv")
    if not os.path.exists(f):
        miss_log += 1; continue
    rdr = csv.DictReader(open(f))
    agb_cols = [c for c in (rdr.fieldnames or []) if c and c.strip().startswith("AboveGroundBiomass_")]
    by_t = {}
    for row in rdr:
        try:
            t = int(row["Time"].strip())
        except Exception:
            continue
        nas = (row.get("NumActiveSites") or "0").strip()
        if nas in ("0", "", "NaN"):
            continue                      # inactive ecoregion row for this single-cell plot
        s, ok = 0.0, False
        for c in agb_cols:
            v = (row[c] or "").strip()
            if v and v != "NaN":
                try:
                    s += float(v); ok = True
                except ValueError:
                    pass
        if ok:
            by_t[t] = by_t.get(t, 0.0) + s
    for t, tot in sorted(by_t.items()):
        yr = 2025 + t
        if yr > 2100:
            continue
        rows.append(("LANDIS", "reserve", cn, yr, round(tot * 0.01 * CFRAC, 4)))
    used += 1

with open(OUT, "w", newline="") as o:
    w = csv.writer(o)
    w.writerow(["model", "scenario", "PLT_CN", "year", "agc_MgC_ha"])
    w.writerows(rows)

print(f"ME reserve: plots_used={used} missing_cn={miss_cn} missing_log={miss_log} rows={len(rows)} -> {OUT}")
