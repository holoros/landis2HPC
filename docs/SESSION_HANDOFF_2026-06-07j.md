# Harmonized session handoff — 2026-06-07j

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-07i
**Focus:** first multi-state harmonized LANDIS reserve table, anchored to FIA with SEs.

---

## 1. Result: four-state harmonized LANDIS reserve projection

`harmonized/harmonized_landis_8state.csv`. LANDIS reserve (no harvest), live AGC Tg C, anchored to the FIA design total at year 0 with the FIA sampling SE propagated:

| State | 2025 (anchor) | 2100 | factor | anchor CV |
|---|---|---|---|---|
| WA | 818.7 | 1669.5 | x2.0 | 1.01% |
| MN | 308.8 | 703.7 | x2.3 | 0.89% |
| OH | 250.9 | 966.6 | x3.9 | 1.96% |
| IN | 178.8 | 706.4 | x4.0 | 2.30% |

Year-0 anchored values equal the FIA design anchors and post-anchor year-0 agreement is exactly 1. The full chain (calibrated statewide LANDIS to per-plot adapter to physical-plot paint to FIA anchor to SE) now runs end to end on real model output for four states.

## 2. Caveats (important)

These are reserve (no harvest) only; the other three Daigneault scenarios are not yet run. Painted coverage is the TreeMap-donor subset of each state's LANDIS plots: WA 447, MN 306, OH 73, IN 51 physical plots. WA and MN rest on solid samples; IN and OH (51 and 73 plots) are sparse, so their dynamics, including the strong x3.9 to x4.0 accumulation, should be treated as provisional and sanity-checked against expected eastern-hardwood growth (no-harvest, no-disturbance LANDIS over 75 years tends to accumulate strongly). The anchored year-0 level is reliable regardless because it is the FIA estimate.

WI and MI dropped out of the table entirely (zero painted plots), even though their statewide runs produced trajectories. Their LANDIS plot CNs apparently do not resolve to TreeMap-donor physical plots; this needs a targeted check (CN format / cn2pid resolution for the MN-family states).

## 3. Jobs in flight

The IN, OH, WI, MI statewide drivers were resumed (jobs 11366734/35/36/37) to fill incomplete plots (the first pass left IN ~25%, OH ~20%, MI ~47%, WI ~76% complete; MN finished 1147/1147). After they finish, re-harvest to improve coverage. The runner skips already-done plots, so resuming is cheap.

## 4. Why states completed partially

The first-pass drivers exited with incomplete plot sets (IN/OH especially low). IN chunk error logs are empty, indicating plots exited cleanly without producing a trajectory (the runner does `build_plot_scenario || exit 0`), i.e. silent build skips for many eastern plots, plus settling-loop timeout while arrays were queued behind MN. Worth confirming build_plot_scenario_{IN,OH}.sh succeeds for the bulk of plots.

## 5. Next steps (priority order)

1. Re-harvest the table after the four resumes complete; investigate WI/MI zero-paint (cn2pid resolution for MN-family CNs).
2. Address low TreeMap-donor coverage for IN/OH: either run LANDIS on the TreeMap donor universe, or impute donor trajectories from similar run plots; decide the donor-universe approach.
3. Run the three remaining scenarios (BAU, conservation, intensive) per plot with the HCS per-state harvest rate.
4. Build ME and GA statewide runs (no per-plot runs yet).
5. Bring FVS, CEM, CBM, yield curves onto the pid-keyed pipeline for the cross-model comparison.

## 6. Files created or changed this session

Repo: `harmonized/harmonized_landis_8state.csv`, `harmonized/landis_{MN,WI,MI,IN,OH}_reserve.csv` (where produced), `docs/SESSION_HANDOFF_2026-06-07j.md`. Cardinal: `FIA/submit_landis_harvest8.slurm`; resumed driver jobs 11366734/35/36/37.
