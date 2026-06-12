# Harmonized session handoff — 2026-06-07L

**Repo:** github.com/holoros/landis2HPC
**Chains from:** SESSION_HANDOFF_2026-06-07k
**Focus:** all four Daigneault scenarios produced for LANDIS via deterministic expected-value harvest.

---

## 1. Four-scenario harmonized LANDIS table (WA, MN, IN, OH)

`harmonized/harmonized_landis_4scenario.csv`. Built with `apply_harvest_scenarios.R`, the chosen deterministic expected-value method: harvest is a removal flux on the anchored reserve dynamics, integrated annually, with no new LANDIS runs.

   dB/dt = g_reserve(t) - h*f*B,  h = HCS per-state rate * multiplier,  f = removal fraction

Driver is the CALIBRATED per-state HCS rate (`hcs_harvest_rate_by_state.csv`), not the raw 0.9 propensity raster. Multipliers reserve 0, BAU 1, conservation 0.6 (partial), intensive 2 (clearcut). Removal fractions f_clearcut 0.85, f_partial 0.45 (documented defaults, sensitivity-checkable); BAU blends by each state's clearcut fraction.

Live AGC 2100 (Tg C), reserve / conservation / BAU / intensive (all start at the FIA anchor at 2025):

| State | rate %/yr | reserve | conservation | BAU | intensive |
|---|---|---|---|---|---|
| MN | 0.335 | 704 | 668 | 618 | 508 |
| IN | 0.136 | 706 | 693 | 674 | 627 |
| OH | 0.106 | 967 | 952 | 930 | 881 |
| WA | 0.010 | 1670 | 1667 | 1663 | 1653 |

Ordering is monotonic (reserve > conservation > BAU > intensive) in every state, and the spread scales with the calibrated harvest rate: MN (0.34 %/yr) shows the widest reserve-to-intensive gap (28%), WA (0.01 %/yr) is essentially flat. Anchor SE is carried on each value. This is a coherent, defensible scenario set.

## 2. A substantive finding

At the HCS-calibrated harvest rates, management has a modest effect on standing live carbon over 75 years for these states (largest, MN intensive, is a ~28% reduction vs reserve; WA is negligible because its HCS rate is ~0.01 %/yr). That is itself a result of the harmonized comparison and worth checking against expectations: the low HCS rates, especially WA at 0.01 %/yr, deserve a sanity check against known timber output for those states.

## 3. Method caveats

The expected-value removal is first-order: harvested area is assumed to resume growth at the reserve increment (no explicit from-age-0 regrowth curve), and f_clearcut / f_partial are defaults. These are transparent and easy to vary in a sensitivity pass. The numbers are the anchored state-level expectation; they do not carry harvest-event stochasticity (by design, per the deterministic choice).

## 4. Status

The full harmonized LANDIS pipeline now runs end to end and produces all four scenarios for four states (WA, MN, IN, OH), anchored to FIA with SE. Remaining: extend to the other calibrated states once the IN/OH/WI/MI statewide resumes finish and the WI/MI zero-paint is fixed; build ME and GA; address full painting coverage via the ecoregion/neighbor-constrained donor imputation; bring the other four models onto the pipeline.

## 5. Next steps (priority order)

1. Re-harvest reserve + re-run scenarios for all calibrated states once the statewide resumes complete and WI/MI paint is fixed.
2. Implement the ecoregion/neighbor-constrained donor imputation for full painting coverage.
3. Sanity-check the HCS per-state rates (WA 0.01 %/yr looks low) against FIA timber product output.
4. Optionally add a from-age-0 regrowth curve to refine the expected-value harvest beyond first order.
5. Bring FVS, CEM, CBM, yield curves onto the pid-keyed pipeline and the same scenario method for the cross-model comparison.

## 6. Files created or changed this session

Repo: `harmonized/apply_harvest_scenarios.R`, `harmonized/harmonized_landis_4scenario.csv`, `harmonized/extract_hcs_plot_prob.R`, `docs/SESSION_HANDOFF_2026-06-07L.md`. Cardinal: `FIA/apply_harvest_scenarios.R`, `FIA/harmonized_landis_4scenario.csv`, `landis2/tools/plot_hcs_prob.csv`.
