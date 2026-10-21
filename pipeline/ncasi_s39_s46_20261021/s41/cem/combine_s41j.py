#!/usr/bin/env python3
"""s41 step J: stack the step I gate and diagnostic CSVs (state aggregates only)
into two tables, and stack the hindcast summaries."""
import csv, glob, os
W = "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem"
O = os.path.join(W, "out")
rows, diags = [], []
for t in ["s41gate", "f1gate", "f2gate", "m1gate"]:
    sfx = "20261016d" if t == "s41gate" else "20261016e"
    for s in ["ME", "NH", "VT", "MI", "WI", "MN"]:
        for r in csv.DictReader(open(os.path.join(O, f"cem_gate_{s}_{t}_{sfx}.csv"))):
            r["run"] = t; rows.append(r)
        d = next(csv.DictReader(open(os.path.join(O, f"cem_gate_diag_{s}_{t}_{sfx}.csv"))))
        d["run"] = t; diags.append(d)
def write(fn, rs):
    keys = ["run"] + [k for k in rs[0].keys() if k != "run"]
    with open(os.path.join(O, fn), "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=keys, extrasaction="ignore"); w.writeheader(); w.writerows(rs)
write("cem_fix_gate_table_20261016.csv", rows)
write("cem_fix_gate_diag_20261016.csv", diags)
hs = []
for t in ["h0hind", "h1hind", "h2hind", "m1hind"]:
    for s in ["ME", "MN"]:
        for fn in glob.glob(os.path.join(W, f"hind_{t}_{s}", "output", "hindcast", "HINDCAST_*.csv")):
            for r in csv.DictReader(open(fn)):
                r["run"] = t; r["state"] = s; hs.append(r)
write("cem_fix_hindcast_years_20261016.csv", hs)
print(len(rows), len(diags), len(hs))
