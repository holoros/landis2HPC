#!/usr/bin/env python3
"""Python clone of build_synthetic_cmip6.R that outputs wide-eco Variable
format compatible with LANDIS Biomass Succession ClimateFile parameter.
Reads PRISM_<ST>_l3.csv, applies IPCC AR6 endpoint deltas via linear ramp."""
import csv, statistics, sys
from collections import defaultdict

DELTA = {
    'ssp245': dict(dT=2.5, dP_pct=5.0),
    'ssp370': dict(dT=3.5, dP_pct=7.0),
    'ssp585': dict(dT=4.5, dP_pct=10.0),
}

def build(prism_path, scenario, out_path, y0=2010, y1=2100):
    if scenario not in DELTA:
        sys.exit(f'unknown scenario: {scenario}')
    dT_end = DELTA[scenario]['dT']
    dP_end = DELTA[scenario]['dP_pct']

    with open(prism_path) as f:
        rdr = csv.reader(f)
        header = next(rdr)
        ecos = header[3:]
        rows = list(rdr)

    # Compute (Month, Variable) -> {eco: mean over all PRISM years}
    avg = defaultdict(lambda: defaultdict(list))
    for r in rows:
        try: m = int(r[1])
        except: continue
        var = r[2]
        for i, eco in enumerate(ecos):
            try: avg[(m, var)][eco].append(float(r[3+i]))
            except: pass
    avg_mean = {k: {e: (statistics.mean(v) if v else None) for e, v in d.items()} for k, d in avg.items()}

    out_rows = []
    for yr in range(y0, y1+1):
        ramp = max(0, min(1, (yr - y0) / (y1 - y0)))
        dT = ramp * dT_end
        dPf = 1 + (ramp * dP_end / 100)
        for m in range(1, 13):
            for var in ('maxtemp', 'mintemp', 'precip'):
                base = avg_mean.get((m, var), {})
                row = [yr, m, var]
                for eco in ecos:
                    v = base.get(eco)
                    if v is None:
                        # fallback to mean of available ecos this (month,var)
                        vals=[x for x in base.values() if x is not None]
                        v = sum(vals)/len(vals) if vals else 0.0
                    if var in ('mintemp', 'maxtemp'): v = v + dT
                    elif var == 'precip': v = v * dPf
                    row.append(round(v, 4))
                out_rows.append(row)
    with open(out_path, 'w', newline='') as fo:
        w = csv.writer(fo)
        w.writerow(['Year','Month','Variable'] + ecos)
        w.writerows(out_rows)
    print(f'  wrote {out_path}: {len(out_rows)} rows, {len(ecos)} ecos, {scenario} (dT={dT_end}, dP={dP_end}%)')

# ---- firebreather adaptation (scripts_20260929): the hardcoded GA/MN/IN/OH/WA loop is replaced by
# argv use; baseline table is the Daymet 1991-2020 historic table instead of PRISM; outputs never overwrite.
import os
def beside(p, tag='20260929'):
    if not os.path.exists(p): return p
    stem, ext = os.path.splitext(p); p2 = f'{stem}_{tag}{ext}'
    if os.path.exists(p2): sys.exit(f'dated variant exists: {p2}')
    print(f'NOTE target exists, writing dated variant: {p2}'); return p2
if __name__ == '__main__':
    ST = sys.argv[1]
    FB = os.path.expanduser('~/landis2_fb')
    src = sys.argv[2] if len(sys.argv) > 2 else f'{FB}/states/{ST}/inputs/Daymet_{ST}_l3.csv'
    for scen in ('ssp245', 'ssp585'):
        dst = beside(f'{FB}/states/{ST}/inputs/HadGEM3_{scen}_{ST}_l3.csv')
        build(src, scen, dst)
