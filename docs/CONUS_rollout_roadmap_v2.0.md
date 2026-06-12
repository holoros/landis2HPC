# CONUS PERSEUS rollout roadmap (v2.0)

**Date:** 2026-06-06
**Status:** 8 of 48 states calibrated. Scenario projection engine validated on WA via pilot job 11315259 after three generator defects were fixed.
**Scope:** full 48 state (lower 48) PERSEUS calibration plus the 3 climate x 4 management scenario matrix, feeding the CONUS atlas and the scenario/methods papers.
**Supersedes planning in:** CONUS_expansion_plan.md, conus_ecoregion_clusters.md, multistate_readiness_matrix.md (consolidated and made actionable here).

---

## 1. Headline status

Eight states carry Tier 2 production theta on Cardinal and are confirmed on disk: ME, WA, GA, MN, WI, MI, IN, OH. (Note: the 2026-06-02 handoff text says "nine states" but both its own table and the `theta_best_production.csv` inventory show eight. Reconcile before the methods table is updated.)

The scenario projection step, the thing that actually produces "projections," had never run successfully for any state. The WA factorial built on 2026-05-02 failed in all 12 cells at scenario load. The 2026-06-06 pilot fixed the cause and is running statewide over 100 years. This means the path from a calibrated state to a finished 12 condition projection set is now demonstrated, not just designed.

## 2. Immediate engineering blocker (gates every projection run, all 48 states)

`tools/scenario_factorial.sh` generates scenario directories that the current LANDIS-II v8 container rejects. Three defects, all found and fixed by hand in the pilot, must be patched into the generator before any further state is run:

1. **Wind extension name.** The generator writes `"Base Wind"`. The `landis-ii_v8_allext_v1.0.sif` container registers no extension by that name; the v8 name is `"Original Wind"` (the container also offers `LinearWind`, `Hurricane`). This is the exact "Error reading input value for Extension" failure at line 12 of scenario.txt. Fix: emit `"Original Wind"`.
2. **Uncalibrated parameters.** The generator copies the literature Tier 0 `SppEcoregionData.csv` (for WA, Douglas fir ANPPmax 1850, BiomassMax 75000) rather than the calibrated production vector (ANPPmax 430, BiomassMax 39510). Every cell would have produced wrong carbon even if it ran. Fix: inject the state's `*_calibrated.csv` SppEcoregionData (the file produced by the statewide calibration harvest).
3. **Missing initial-communities text file.** `biomass-succession.txt` references `initial-communities.csv` but the generator never writes it into the cell. Fix: copy or symlink the state IC text file (`states/<ST>/inputs/initial_communities.txt`) to `initial-communities.csv` in each cell.

A fourth item needs validation, not yet proven: the harvest cells (baseline, increased, perseus) must wire the `"Biomass Harvest"` extension (`BiomassHarvest-v6` is registered) plus `biomass-harvest.txt` with the PartialHarvest and PerseusBA50 prescriptions. Only the `none` cell is proven so far. Validate one harvest cell before fanning out.

Until the generator is patched, every state added downstream inherits these defects. This is the single highest leverage fix in the rollout.

## 3. The 48 state assignment matrix

Cluster scheme and reference states follow conus_ecoregion_clusters.md. "Ref theta" means a frozen `cluster_<N>_reference_theta.csv` exists in `tools/state_templates/` to warmstart new members. Cost is human setup days per the hybrid warmstart estimate.

| State | Cluster | Ref theta exists | Calib status | Gating dependency | Est. days |
|---|---|---|---|---|---|
| ME | N1 | yes | done | none | 0 |
| WA | P3 | yes | done | none | 0 |
| GA | S1 | yes | done | none | 0 |
| MN | N2 | yes | done | none | 0 |
| WI | N2 | yes | done | none | 0 |
| MI | N2 | yes | done | none | 0 |
| IN | N3 | yes | done (weak, LL -1.31) | optional re-warmstart (IN_v2 staged) | 0 |
| OH | N3 | yes | done | none | 0 |
| NH | N1 | yes | pending | FIA download | 2 |
| VT | N1 | yes | pending | FIA download | 2 |
| CT | N1/N4 | partial | pending | FIA + N4 blend ref | 2.5 |
| MA | N1/N4 | partial | pending | FIA + N4 blend ref | 2.5 |
| RI | N1/N4 | partial | pending | FIA + N4 blend ref | 2.5 |
| NY | N1/N4 | partial | pending | FIA + N4 blend ref | 2.5 |
| IA | N2/N3 | yes | pending | FIA download | 1.5 |
| IL | N3 | yes | pending | FIA download | 1.5 |
| MO | N3 | yes | pending | FIA download | 1.5 |
| KY | N3/S2 | partial | pending | FIA + S2 blend ref | 2.5 |
| TN | N3/S2 | partial | pending | FIA + S2 blend ref | 2.5 |
| PA | N4 | no | pending | N4 blend ref (IN + ME) | 2.5 |
| NJ | N4 | no | pending | N4 blend ref | 2.5 |
| MD | N4 | no | pending | N4 blend ref | 2.5 |
| DE | N4 | no | pending | N4 blend ref | 2.5 |
| VA | N4/S2 | no | pending | N4 + S2 blend refs | 3 |
| WV | N4/S2 | no | pending | N4 + S2 blend refs | 3 |
| FL | S1 | yes | pending | FIA download | 1.5 |
| AL | S1/S2 | partial | pending | FIA + S2 blend ref | 2.5 |
| MS | S1 | yes | pending | FIA download | 1.5 |
| LA | S1 | yes | pending | bottomland hardwood params | 2 |
| AR | S1/N3 | yes | pending | FIA download | 2 |
| SC | S1/S2 | partial | pending | S2 blend ref | 2.5 |
| NC | S1/S2 | partial | pending | S2 blend ref | 2.5 |
| KS | P1 | no | pending | P1 ref + arid oak species | 3 |
| NE | P1 | no | pending | P1 ref + arid oak species | 3 |
| OK | P1 | no | pending | P1 ref + arid oak species | 3 |
| TX | P1 | no | pending | P1 ref + arid oak species | 3.5 |
| ND | P2 | no | pending | P2 ref + sparse cover tuning | 3 |
| SD | P2 | no | pending | P2 ref + sparse cover tuning | 3 |
| MT | R1 | no | pending | R1 ref (WA ext) + Rockies species | 3 |
| ID | R1 | no | pending | R1 ref + Rockies species | 2.5 |
| WY | R1 | no | pending | R1 ref + Rockies species | 3 |
| CO | R2 | no | pending | R2 ref + pinyon-juniper | 3.5 |
| UT | R2 | no | pending | R2 ref + pinyon-juniper | 3.5 |
| NM | R2 | no | pending | R2 ref + pinyon-juniper | 3.5 |
| AZ | R2/R3 | no | pending | R2/R3 ref + arid species | 3.5 |
| NV | R3 | no | pending | R3 ref (sparse, deferred) | 3 |
| OR | P3 | yes | pending | shares WA pool + 2 species | 2 |
| CA | P4 | no | pending | P4 ref + many endemics | 5 |

Totals: 8 done, 40 pending. Sum of pending setup is roughly 115 human days, about 100 days net with the warmstart savings already baked in.

## 4. Cluster reference readiness

Frozen and ready to warmstart from: **N1 (ME), N2 (MN), N3 (IN), S1 (GA), P3 (WA)**.

Not yet frozen, and the true bottleneck for 24 of the 40 pending states: **N4, S2, P1, P2, R1, R2, R3, P4**. Each needs (a) a reference theta chosen by blending or extending existing production vectors, and (b) literature ANPP and BiomassMax defaults for the extension species not present in any calibrated state (bur oak, eastern redcedar, post oak, lodgepole pine, subalpine fir, pinyon, juniper, coast redwood, giant sequoia, blue oak, and so on). Compute is not the constraint; this curation is.

## 5. Phase sequencing and concrete first actions

**Phase 0, now, one to two weeks.** Patch `scenario_factorial.sh` per Section 2. Let the WA pilot (job 11315259) finish, extract its `state_trajectory.csv`, and confirm the year 100 carbon is consistent with the calibrated statewide value (306 Mg/ha). Validate one WA harvest cell. Then regenerate and submit the full WA 12 cell matrix as the first complete projection set. Run the same 12 cell matrix for the other seven calibrated states (ME, GA, MN, WI, MI, IN, OH); their calibrations are done, so this is pure compute, roughly 600 CPU hours per state.

**Phase 1, one to three months.** Freeze the N4 and S2 blend references. Pilot the warmstart path with NH, VT, NY off N1, using the patched `add_state.sh`, then fan out the eastern and midwestern infill (about 20 states sharing N1, N2, N3, S1, plus the new N4 and S2 refs). Run their scenario matrices as each lands.

**Phase 2, two to four months.** Plains and Mountain (14 states). This is where the new literature parameterization dominates. Build P1, P2, R1, R2, R3 references and extension species CSVs first, cap each cluster at two days of curation, then add states.

**Phase 3, one month.** Pacific. OR off P3 (cheap), then CA off P4 (the most expensive single state).

**Phase 4, ongoing under a rolling window.** As each state's calibration lands, immediately run its 12 cell matrix and archive the trajectory tables, then delete intermediate tifs to hold storage near the 25 TB peak ceiling rather than above it.

**Phase 5, two to three months.** CONUS synthesis: 48 state atlas cards, the national year 100 carbon maps under each scenario, and the regional gradient extension (West, Lake States, Northeast already quantified; add Southeast, Plains, Rockies, Pacific regimes).

## 6. Compute and storage envelope

Calibration for the 40 remaining states is roughly 19,000 CPU hours. The scenario matrix across all 48 states is roughly 29,000 CPU hours per pass, three passes for the baseline plus near term plus long term ensemble, so on the order of 90,000 to 110,000 CPU hours total. Peak storage near 25 TB on OSC scratch, which requires the rolling window discipline in Phase 4. Wall clock with four concurrent calibration chains and 150 scenario array slots is on the order of 12 to 14 months, queue contention permitting.

## 7. Risk register

The binding constraint is human literature curation for the eight unfrozen clusters, not compute. The matched-n harvester floor (n at least max(300, 0.85 x max_n)) may be too tight for low FIA coverage western states and may need a state specific minimum. CONUS scale validation needs a held out, multi region evaluation set; FVS outputs at FIA plots plus consensus with FIA biomass equations are the proposed integrity check. Queue contention with other OSC accounts already throttled v1.3; the flock serializer and SLURM wrapper handle it, but a CONUS sweep may warrant an OSC priority allocation conversation. Finally, the generator defects in Section 2 will silently corrupt results if not patched, since a failed cell is obvious but an uncalibrated cell that runs is not.

## 8. Tracking

This is a v2.0 milestone (research framework to national operational tool). Recommend a GitHub v2.0 milestone with Phase 0 through 5 as separate issues, Phase 0 (generator patch plus eight state matrices) gating everything after it.
