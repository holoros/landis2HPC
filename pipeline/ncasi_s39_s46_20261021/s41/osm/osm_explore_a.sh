#!/bin/bash
# s41 OSM gate: read only exploration of the OSM install. Prints no PLT_CN, no BGI per plot, no coordinates.
O=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm
A=$HOME/OSM/work/acd_full
B=$HOME/OSM/v2.26.1/OSMv2.26.1_Linux64
{
echo "== OSM folder"; ls -la $B | head -60
echo "== acd_full"; ls -la $A
echo "== osmc head"; head -c 2500 $A/acd_osm_run.osmc; echo; echo "osmc lines: $(wc -l < $A/acd_osm_run.osmc)"
echo "== lookup header"; head -1 $A/acd_plt_cn_lookup_with_bgi_csi.csv; echo "rows $(wc -l < $A/acd_plt_cn_lookup_with_bgi_csi.csv)"
echo "== acd_plt_cn_lookup header"; head -1 $A/acd_plt_cn_lookup.csv
echo "== StandListProjections header"; head -1 $A/acd_StandListProjections.csv
echo "== TreeListProjections header and 3 rows"; head -4 $A/acd_TreeListProjections.csv
echo "== sqlite schema"; module load sqlite 2>/dev/null; (which sqlite3 && sqlite3 $A/acd_osm_input.sqlite ".schema") || python3 -c "import sqlite3;c=sqlite3.connect('$A/acd_osm_input.sqlite');print([r for r in c.execute('select sql from sqlite_master')])"
python3 -c "import sqlite3;c=sqlite3.connect('$A/acd_osm_input.sqlite');print(c.execute('select * from OSM_StandList limit 3').fetchall());print(c.execute('select * from OSM_TreeList limit 3').fetchall());print(c.execute('select Zone,Management,count(*),min(BGI),max(BGI) from OSM_StandList group by 1,2').fetchall())"
echo "== demo tree"; find $HOME/OSM/demo -maxdepth 3 | head -80
echo "== demo01 osmc"; for f in $(find $HOME/OSM/demo/Acadian/Demo01-Grow -name '*.osmc' | head -3); do echo "--- $f"; cat $f; done
echo "== demo02 osmc"; for f in $(find $HOME/OSM/demo/Acadian/Demo02-Silviculture -name '*.osmc' | head -2); do echo "--- $f"; head -80 $f; done
echo "== demo sqlite schema"; python3 -c "import sqlite3;c=sqlite3.connect('$HOME/OSM/demo/Acadian/AcadianStandData.sqlite');[print(r[0]) for r in c.execute('select sql from sqlite_master') if r[0]]"
echo "== help"; cd /tmp; timeout 60 $B/OSM.ConsoleApp --help 2>&1 | head -150
echo "== help2"; timeout 60 $B/OSM.ConsoleApp 2>&1 | head -80
echo "== strings keywords"; ls $B/*.dll 2>/dev/null | head -40
} > $O/explore_a.txt 2>&1
echo done
