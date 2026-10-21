#!/usr/bin/env python3
"""s41 OSM gate exploration d: how OSM treats per record Stems. Synthetic stand only (no FIA data)."""
import sqlite3, subprocess, tempfile, csv, collections
from pathlib import Path
OSM = "/users/PUOM0008/crsfaaron/OSM/v2.26.1/OSMv2.26.1_Linux64/OSM.ConsoleApp"
w = Path(tempfile.mkdtemp(prefix="osmd_", dir="/tmp"))
trees = [("BF", 5.0, 5.0, 185.2425), ("BF", 5.0, 5.0, 18.5), ("BF", 15.0, 12.0, 185.2425), ("BF", 15.0, 12.0, 14.87),
         ("RM", 11.0, 10.0, 100.0), ("RM", 2.6, 3.0, 185.2425), ("RM", 30.0, 20.0, 14.87), ("RS", 8.0, 7.0, 40.0), ("RS", 12.6, 10.0, 185.2425),
         ("RS", 13.0, 10.0, 185.2425)]
for zone in ["ME", "NB"]:
    db = w / f"d_{zone}.sqlite"; c = sqlite3.connect(db)
    c.execute("CREATE TABLE OSM_StandList (SurveyID INT, Plots INT, Zone TEXT, Management TEXT, BGI INT, PoorSite SMALLINT)")
    c.execute("CREATE TABLE OSM_TreeList (SurveyID INT, Species TEXT, DBH REAL, HT REAL, Stems REAL)")
    c.execute("INSERT INTO OSM_StandList VALUES (1,1,?,'None',4000,0)", (zone,))
    for t in trees:
        c.execute("INSERT INTO OSM_TreeList VALUES (1,?,?,?,?)", t)
    c.commit(); c.close()
    oc = w / f"r_{zone}.osmc"
    oc.write_text(f'SIMULATION\n YEARS 10\n YPC 5\n\nINPUTS.SOURCE "{db}"\n\nOUTPUTS\n Messages TRUE\n StandSummary.ConsoleOn FALSE\n'
                  f' StandSummary.FilePath "{w}/ss_{zone}.csv"\n TreeList.FilePath "{w}/tl_{zone}.csv"\n\nSIMULATION.Scenario BASE\nSIMULATE 1\n')
    r = subprocess.run([OSM, "Acadian", str(oc)], capture_output=True, text=True, cwd=w)
    print(f"===== zone {zone} rc {r.returncode}"); print("\n".join(l for l in r.stdout.splitlines()[14:80]))
    print(open(w / f"ss_{zone}.csv").read())
    rows = list(csv.DictReader(open(w / f"tl_{zone}.csv")))
    cnt = collections.Counter((x["Cycle"], x["TreeID"]) for x in rows)
    print("rows", len(rows), "max rows per (Cycle, TreeID)", max(cnt.values()))
    for x in rows:
        print(x["Cycle"], x["TreeID"], x["Species"], x["DBH"], x["HT"], x["Stems"], x["ToDie"], x["Origin"], x["List"], x["Born"])
