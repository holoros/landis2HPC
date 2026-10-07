# Session 36, 6 Oct 2026. Pulls FIA EVALIDator (fiadb-api fullreport) state totals for live tree
# aboveground biomass: stock (snum 10, EVALID xx01) and average annual gross growth (1311), mortality (335),
# net growth (311), removals (369), net change (2311) (EVALID xx03), forest land, trees >= 1 inch.
# Short tons converted to Tg with 0.90718474e-6. Aggregates only; no plot data touched.
import json, urllib.request, urllib.parse, csv, time, sys
ST = {"NH": "33", "VT": "50", "MI": "26", "WI": "55"}
SN = {"stock": 10, "gross_growth": 1311, "mortality": 335, "net_growth": 311, "removals": 369, "net_change": 2311}
YRS = sys.argv[1:] or ["24"]
rows = []
for st, fips in ST.items():
    for yy in YRS:
        for k, sn in SN.items():
            ev = fips + "20" + yy  # evaluation group (state FIPS + 4 digit year); EVALIDator selects the evaluation type from snum
            q = urllib.parse.urlencode({"snum": sn, "wc": ev, "rselected": "None", "cselected": "None", "outputFormat": "NJSON"})
            url = "https://apps.fs.usda.gov/fiadb-api/fullreport?" + q
            try:
                d = json.load(urllib.request.urlopen(url, timeout=60))
                est = d.get("estimates", [])
                tot = [e for e in est if str(e.get("GRP1", "")).strip().endswith("Total") or len(est) == 1]
                e = tot[0] if tot else (est[0] if est else {})
                rows.append({"state": st, "eval_grp": ev, "quantity": k, "snum": sn,
                             "short_tons": e.get("ESTIMATE"), "se_pct": e.get("SE_PERCENT"),
                             "plot_count": e.get("PLOT_COUNT"), "n_estimates": len(est), "url": url})
            except Exception as ex:
                rows.append({"state": st, "eval_grp": ev, "quantity": k, "snum": sn, "short_tons": None,
                             "se_pct": None, "plot_count": None, "n_estimates": 0, "url": url, "error": str(ex)[:200]})
            time.sleep(0.5)
for r in rows:
    r["Tg"] = round(float(r["short_tons"]) * 0.90718474e-6, 4) if r.get("short_tons") not in (None, "") else None
f = "evalidator_agb_fourstate_%s_20261006.csv" % "_".join(YRS)
with open(f, "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=["state","eval_grp","quantity","snum","short_tons","Tg","se_pct","plot_count","n_estimates","url","error"])
    w.writeheader(); [w.writerow(r) for r in rows]
for r in rows: print(r["state"], r["eval_grp"], r["quantity"], r["Tg"], r["se_pct"], r["plot_count"], r.get("error",""))
