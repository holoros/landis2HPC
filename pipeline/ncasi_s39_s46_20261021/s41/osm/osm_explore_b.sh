#!/bin/bash
# s41 OSM gate exploration b: docs, prior parsers, YPC test. All output redacted of 12+ digit numbers (PLT_CN) and no LAT/LON printed.
O=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/osm
A=$HOME/OSM/work/acd_full
B=$HOME/OSM/v2.26.1/OSMv2.26.1_Linux64/OSM.ConsoleApp
{
echo "== downloads"; ls -laR $HOME/OSM/downloads | head -60
echo "== benchmark"; ls -la $A/benchmark; cat $A/agg.log $A/aggregate.log; head -60 $A/osm_run.log
echo "== Demo05 R"; cat $HOME/OSM/demo/Acadian/Demo05-R/OSM_Grow.r | head -120
echo "== other work dirs"; ls $HOME/OSM/work
echo "== find scripts that parse TreeListProjections"; grep -rl --include=*.py --include=*.R -i "TreeListProjections\|TreeList.FilePath" $HOME/OSM $HOME/fvs-acd $HOME/repos 2>/dev/null | head -30
echo "== stand list projections 3 rows"; head -4 $A/acd_StandListProjections.csv
echo "== Help docs in html?"; find $HOME/OSM -iname '*.htm*' | head
echo "== strings in binary for TreeList columns"; strings -n 6 $B | grep -iE "^(Scenario,|TreeList|StandSummary\.|YPC|Recruit|InGrow|TreeID|Stems|MortRate|PlotID)" | sort -u | head -150
echo "== strings with comma lists"; strings -n 30 $B | grep -E "Scenario,SurveyID" | head -10
echo "== strings OUTPUTS keywords"; strings -n 5 $B | grep -E "^(TreeList|StandSummary|Messages|Ingrowth|INGROWTH|Regen|REGEN|Recruitment|SIMULATION|OUTPUTS|INPUTS)[A-Za-z.]*$" | sort -u | head -100
} 2>&1 | sed -E 's/[0-9]{12,}/<redacted>/g' > $O/explore_b.txt
echo done
