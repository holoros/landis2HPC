#!/bin/bash
# s41 OSM gate exploration c: YPC and cycle tests on the demo stand, TreeList header, zip contents, demo readme text.
# Output redacted of 12+ digit numbers. Demo data only; no FIA data touched.
O=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm
B=$HOME/OSM/v2.26.1/OSMv2.26.1_Linux64/OSM.ConsoleApp
{
echo "== zip listings"; for z in $HOME/OSM/downloads/*.zip; do echo "--- $z"; unzip -l $z | grep -viE "\.dll$" | head -60; done
echo "== DemoReadMe text"; T0=$(mktemp -d /tmp/osmd_XXXX); cd $T0; unzip -o -q $HOME/OSM/demo/DemoReadMe.docx -d rd; python3 -c "
import re;s=open('rd/word/document.xml',encoding='utf8').read();s=re.sub(r'</w:p>','\n',s);s=re.sub(r'<[^>]+>','',s);print(s[:6000])"
echo "== YPC tests on demo stand 6760"
T=$(mktemp -d /tmp/osmt_XXXX); cp $HOME/OSM/demo/Acadian/AcadianStandData.sqlite $T/d.sqlite; cd $T
python3 -c "import sqlite3;c=sqlite3.connect('d.sqlite');print(c.execute('select * from OSM_StandList where SurveyID=6760').fetchall());print(c.execute('select count(*),sum(Stems) from OSM_TreeList where SurveyID=6760').fetchall());print(c.execute('select * from OSM_TreeList where SurveyID=6760 limit 5').fetchall())"
for cfg in "7 7" "7 1" "5 5" "6 3"; do set -- $cfg
printf 'SIMULATION\n YEARS %s\n YPC %s\n\nINPUTS.SOURCE "%s/d.sqlite"\n\nOUTPUTS\n Messages FALSE\n StandSummary.ConsoleOn FALSE\n StandSummary.FilePath "%s/ss_%s_%s.csv"\n TreeList.FilePath "%s/tl_%s_%s.csv"\n\nSIMULATION.Scenario BASE\nSIMULATE 6760\n' $1 $2 $T $T $1 $2 $T $1 $2 > t_$1_$2.osmc
echo "--- YEARS $1 YPC $2"; timeout 120 $B Acadian $T/t_$1_$2.osmc > run_$1_$2.log 2>&1; echo "rc $?"; grep -v "unusually large" run_$1_$2.log | tail -8
cat ss_$1_$2.csv; echo "tl rows $(wc -l < tl_$1_$2.csv)"; head -4 tl_$1_$2.csv; echo "Year,Period counts (cols 3,4):"; cut -d, -f3,4 tl_$1_$2.csv | sort | uniq -c | head
done
} 2>&1 | sed -E 's/[0-9]{12,}/<redacted>/g' > $O/explore_c.txt
echo done
