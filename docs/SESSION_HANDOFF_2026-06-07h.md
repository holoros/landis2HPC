# Harmonized session handoff — 2026-06-07h

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-07g
**Focus:** physical-plot join wired into the painter, and the data-availability finding that bounds the multi-state LANDIS result.

---

## 1. Physical-plot crosswalk built and wired in

`cn2pid.csv` (1,985,373 rows: CN, pid = STATECD_COUNTYCD_PLOT, STATECD) was built once from `ENTIRE_PLOT.csv`. `harmonized_aggregate.R` now joins model output and TreeMap area on the physical plot (pid) rather than the raw control number, which fixes the inventory-cycle CN mismatch (LANDIS 010497 vs TreeMap 010661) and removes the need to read per-state PLOT files. WA painting coverage improved from 48 to 447 physical plots (2.17M ha, about 24% of WA forest). The aggregator runs as a SLURM job (`submit_harm.slurm`) because loading the 2M-row crosswalk exceeds the interactive shell limit.

## 2. WA harmonized LANDIS reserve result (stands)

`harmonized/harmonized_landis_6state.csv` (WA only; see below) gives the WA reserve trajectory, anchored to the FIA design total at year 0 (818.67 +/- 8.27 Tg C) via the corrected physical-plot join, projecting to 1,976 Tg by 2100 (+141% under no harvest), with the FIA SE propagated and post-anchor year-0 agreement = 1.

## 3. Finding: only WA has a calibrated statewide projection

The six-state batch produced output for WA only. Cause: the adapter auto-selects the `*_calibrated` statewide chain, and only WA has one (`wa_t2v2_calibrated`). MN, WI, MI, IN, OH have statewide runs named `<st>_statewide_t0`, `_t1`, `_t0_v2`, which are Tier 0 / Tier 1 (literature and intermediate theta), not the production Tier 2 calibrated theta. So a true harmonized LANDIS table at calibrated theta currently exists only for WA.

Implication: extending harmonized LANDIS to the other seven calibrated states requires running each state's statewide per-plot projection with its production Tier 2 theta (the calibration is done; the statewide projection at that theta is not, except for WA). Mixing tiers across states would break the apples-to-apples comparison, so this should not be shortcut.

## 4. Two bounding issues for full LANDIS coverage

First, the calibrated statewide projections must be run for the other states (above). Second, even with the physical-plot join, WA coverage is about 24%, because TreeMap imputes pixels from its own donor-plot pool and the LANDIS calibration plots overlap it only partially. Full spatial coverage needs the model run on the TreeMap donor plot universe (or donor trajectories imputed from the most similar run plot). The anchored trajectories are valid in level and shape regardless, since the FIA anchor fixes the level; the open item is spatial completeness and the representativeness of the covered subset.

## 5. Decision point for the next session

Two choices set the path and are worth the user's steer:
1. Plot universe. Run LANDIS (and every model) on the full TreeMap donor set per state (clean, complete coverage, more compute), versus impute unrun donor plots from similar run plots (cheaper, adds an imputation assumption).
2. Statewide projections. Launch the calibrated Tier 2 statewide per-plot runs for ME, GA (need the per-plot runs at all), MN, WI, MI, IN, OH (need the calibrated-theta variant), so all eight states can enter the harmonized table.

## 6. Next steps (priority order)

1. Run the calibrated Tier 2 statewide per-plot projection for the seven non-WA calibrated states (reserve first), so the adapter can produce all eight.
2. Decide the plot universe (donor-set runs vs imputation) and, if donor-set, regenerate the per-plot run list from the TreeMap donor CNs.
3. Run the other three scenarios (BAU, conservation, intensive) per plot with the HCS per-state harvest rate.
4. Rerun LANDIS output at 5-year intervals to match the harmonized step.
5. Bring FVS, CEM, CBM, yield curves onto the same pid-keyed pipeline.

## 7. Files created or changed this session

Repo: `harmonized/harmonized_aggregate.R` (physical-plot join via cn2pid), `harmonized/harmonized_landis_6state.csv` (WA), `docs/SESSION_HANDOFF_2026-06-07h.md`. Cardinal: `FIA/cn2pid.csv` (CN to physical-plot crosswalk), `FIA/submit_harm.slurm`, `FIA/harmonized_aggregate.R`.
