#!/usr/bin/env python3
# Insert an IC-existence filter into run_statewide_buildfresh.sh so the statewide
# plotlist skips plots that have no per-plot initial_communities.csv (the cause of
# the silent IN/OH/WI/MI build failures).
f = "/fs/scratch/PUOM0008/crsfaaron/landis2/tools/run_statewide_buildfresh.sh"
s = open(f).read()
ins = ('\nwhile read p; do [ -f "$PERSEUS/plot_ics_full/plot_${p}/initial_communities.csv" ] '
       '&& echo "$p"; done < "$PLOT_LIST" > "${PLOT_LIST}.f" && mv "${PLOT_LIST}.f" "$PLOT_LIST"\n')
if "plot_ics_full/plot_" in s:
    print("already patched")
else:
    anchor = "> $PLOT_LIST\n"
    assert anchor in s, "anchor not found"
    s = s.replace(anchor, anchor + ins, 1)
    open(f, "w").write(s)
    print("patched")
