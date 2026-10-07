# Session 36, 6 Oct 2026. EVALIDator live tree AGB stock (snum 10, trees >= 1 inch, forest land) for ME MN GA WA NH,
# evaluation groups 2018 to 2024, as external references for the earlier statewide anchored LANDIS runs. Tg = short tons x 0.90718474e-6.
import json, urllib.request, urllib.parse, csv, time
ST = {"ME": "23", "MN": "27", "GA": "13", "WA": "53", "NH": "33"}
rows = []
for st, f in ST.items():
    for y in range(2018, 2025):
        wc = f + str(y)
        url = "https://apps.fs.usda.gov/fiadb-api/fullreport?" + urllib.parse.urlencode({"snum": 10, "wc": wc, "rselected": "None", "cselected": "None", "outputFormat": "NJSON"})
        r = {"state": st, "eval_grp": wc}
        for attempt in range(2):
            try:
                e = json.load(urllib.request.urlopen(url, timeout=60))["estimates"][0]
                r.update({"Tg": round(e["ESTIMATE"] * 0.90718474e-6, 3), "se_pct": round(e["SE_PERCENT"], 3), "plots": e["PLOT_COUNT"]}); break
            except Exception as ex:
                r["error"] = str(ex)[:120]; time.sleep(2)
        rows.append(r); time.sleep(0.4)
with open("evalidator_stock_fivestate_2018_2024_20261006.csv", "w", newline="") as fh:
    w = csv.DictWriter(fh, fieldnames=["state","eval_grp","Tg","se_pct","plots","error"]); w.writeheader(); [w.writerow(x) for x in rows]
for x in rows: print(x)
