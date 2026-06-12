# Harmonized session handoff — 2026-06-07i

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-07h
**Focus:** launched the calibrated statewide LANDIS projections for the five non-WA calibrated states (the gate to an eight-state harmonized table).

---

## 1. Calibrated statewide projections launched (running on Cardinal)

`run_statewide_buildfresh.sh <STATE> <THETA_CSV> <TAG>` is the runner that produced WA's `wa_t2v2_calibrated` per-plot set. It stratifies plots (<=200 per ecoregion), applies the production theta to the state SppEcoregionData baseline, and runs LANDIS per plot for 100 years. It was previously run only for WA; the other states had only Tier 0/1 statewide runs.

This session launched it at production Tier 2 theta for all five remaining calibrated states, each wrapped in a driver SLURM job (so it survives login-node reaping; nested SLURM submission from the compute node is confirmed working):

| State | driver job | theta | tag |
|---|---|---|---|
| MN | 11356993 | mn_t2_v1 | mn_t2_calibrated (array 11356994 running, 1147 plots) |
| IN | 11357145 | in_t2_v3 | in_t2_calibrated |
| OH | 11357146 | oh_t2_v2 | oh_t2_calibrated |
| WI | 11357147 | wi_t2_v1 | wi_t2_calibrated |
| MI | 11357148 | mi_t2_v1 | mi_t2_calibrated |

WI and MI lack their own `apply_theta_{ST}` so I symlinked `apply_theta_{WI,MI}_perspecies.py -> apply_theta_MN_perspecies.py` (MN family shares the baseline and species list); they run with their own plot_to_ecoregion and theta. The runner self-throttles via its squeue>100 gate, so the five drivers serialize gracefully rather than overrunning the queue.

## 2. How to harvest the eight-state table (next session)

When the drivers finish (check `squeue -u crsfaaron` for drv_sw_* and sw* arrays; each state ~30 to 60 min of array time after queueing), run per state:

```
Rscript landis_adapter.R --state <ST> --scenario reserve --cfrac 0.5 --out landis_<ST>_reserve.csv
```

The adapter auto-selects the `*_calibrated` chain, which now matches the new tags. Concatenate the eight states (WA already done) and run `harmonized_aggregate.R` for the anchored, SE-bearing reserve table across all calibrated states. The physical-plot join (cn2pid) is already wired in.

## 3. Still open

ME and GA have no per-plot statewide runs at all (0 plot dirs); they need plot_ics plus a statewide run built before they can enter. Painting coverage remains partial (WA ~24%) until the plot universe is aligned to TreeMap donors or donor trajectories are imputed; this affects maps, not the anchored state-level numbers. The other three scenarios (BAU, conservation, intensive) and 5-year output remain to be run.

## 4. Next steps (priority order)

1. Harvest the eight-state reserve harmonized table once the five drivers finish (section 2).
2. Build ME and GA per-plot statewide runs at their production theta.
3. Run the three remaining scenarios per plot with the HCS per-state harvest rate.
4. Decide and implement the TreeMap donor-universe alignment for full painting coverage.
5. Bring FVS, CEM, CBM, yield curves onto the pid-keyed pipeline.

## 5. Files created or changed this session

Cardinal: `tools/driver_sw_{MN,IN,OH,WI,MI}.slurm`, `tools/apply_theta_{WI,MI}_perspecies.py` (symlinks), and the five `states/<ST>/perseus/statewide/<st>_t2_calibrated/` run trees (generating). Repo: `docs/SESSION_HANDOFF_2026-06-07i.md`.
