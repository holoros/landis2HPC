#!/usr/bin/env python3
# Fix run_statewide_buildfresh.sh: (1) the skip check treated header-only (failed)
# trajectory stubs as complete, so resubmits never retried failed plots; require a
# data row. (2) bump per-task wall time to reduce timeouts under array concurrency.
f = "/fs/scratch/PUOM0008/crsfaaron/landis2/tools/run_statewide_buildfresh.sh"
s = open(f).read()
old = 'if [ -f "\\$PD/biomass_trajectory.csv" ]; then exit 0; fi'
new = ('if [ -f "\\$PD/biomass_trajectory.csv" ] && '
       '[ "\\$(wc -l < "\\$PD/biomass_trajectory.csv")" -gt 1 ]; then exit 0; fi')
if "wc -l" in s:
    print("skip check already patched")
else:
    assert old in s, "skip line not found"
    s = s.replace(old, new, 1); print("skip check patched")
if "--time=00:20:00" in s:
    s = s.replace("--time=00:20:00", "--time=01:00:00"); print("walltime bumped to 1h")
open(f, "w").write(s)
print("done")
