#!/usr/bin/env python3
"""patch_dense_pairing.py — densify the predicted-vs-observed pairing in a PERSEUS
run_param_set_<ST>_t2.sh likelihood block.

Original pairing only matches observed biomass at 5-year LANDIS output steps
(invyr + {0,5,...,30}), which starved the IN chain at n=201 paired obs (< the
harvester's 300 floor). This rewrites the inner loop to linearly interpolate the
predicted trajectory and pair against EVERY observed year inside the 0..max predicted
window, raising IN's potential n from 201 to ~747.

Idempotent: skips a file already containing DENSE_PAIRING.
Usage: python3 patch_dense_pairing.py <run_param_set_X_t2.sh> [...]
"""
import sys, pathlib

OLD = """    for y_landis, p in pred.items():
        o = obs[cn].get(invyr + y_landis)
        if o and o > 0 and p > 0:
            resids.append(math.log(p) - math.log(o))"""

NEW = """    pys = sorted(pred)  # DENSE_PAIRING: interpolate to every observed year in window
    if len(pys) < 2: continue
    for obs_year, o in obs[cn].items():
        off = obs_year - invyr
        if off < pys[0] or off > pys[-1] or not o or o <= 0: continue
        if off in pred:
            p = pred[off]
        else:
            hi = min(y for y in pys if y > off); lo = max(y for y in pys if y < off)
            p = pred[lo] + (pred[hi] - pred[lo]) * (off - lo) / (hi - lo)
        if p > 0:
            resids.append(math.log(p) - math.log(o))"""

def main(argv):
    if not argv:
        print("no files given", file=sys.stderr); return 1
    rc = 0
    for f in argv:
        p = pathlib.Path(f)
        txt = p.read_text()
        if "DENSE_PAIRING" in txt:
            print(f"unchanged {f} (already densified)"); continue
        if OLD not in txt:
            print(f"SKIP {f}: expected pairing block not found", file=sys.stderr); rc = 2; continue
        p.write_text(txt.replace(OLD, NEW, 1))
        print(f"patched   {f}")
    return rc

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
