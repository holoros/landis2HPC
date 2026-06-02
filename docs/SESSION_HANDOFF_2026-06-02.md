# PERSEUS full session handoff — 2026-06-02

**Repo:** github.com/holoros/landis2HPC, branch main, in sync with origin
**Tag:** v1.7 (Ohio promoted; nine states)
**Supersedes / chains from:** SESSION_HANDOFF_2026-05-31, -31b, -31c, -06-01.

---

## 1. Headline state

PERSEUS is **nine states** calibrated to Tier 2 production. The full Eastern Hardwood
Central cluster (N3 = IN + OH) is done, added entirely through the hybrid warmstart +
densified-pairing path built over the last few sessions.

| State | Region (cluster) | Production vector | Per-plot LL | n |
|---|---|---|---|---|
| ME | Northeast (N1) | Tier 2 v1.0 | +0.0560 | 612 |
| WA | West (P3) | Tier 2 v2.0 | −0.6254 | 1415 |
| GA | Southeast (S1) | Tier 2 v2.0 | −0.8802 | 1249 |
| MN | Great Lakes (N2) | Tier 2 v1.2 | −0.9325 | 2741 |
| WI | Great Lakes (N2) | Tier 2 v1.2 | −0.6470 | 916 |
| MI | Great Lakes (N2) | Tier 2 v1.2 | −0.1292 | 562 |
| IN | Eastern Hardwood (N3) | Tier 2 v3 (in_t2_v3_iter2_cand11) | −1.3146 | 733 |
| OH | Eastern Hardwood (N3) | Tier 2 v2 (oh_t2_v2_iter6_cand9) | −0.8625 | 713 |

Production thetas: `states/<ST>/perseus/bayesian/<chain>/theta_best_production.csv`.
Both N3 chains read PROMOTED in `check_t2v2_chains.sh`.

## 2. What's running now on Cardinal

| Job | What | Wall-time | Status |
|---|---|---|---|
| 11204375 | `wa_stwide_v3` — WA v2.0 statewide-carbon rerun (v1.4.1 deliverable) | 3-day | submitted (was queue ~31, should run unthrottled) |

No calibration chains are running. The IN/OH drivers have completed.

## 3. How we got the N3 cluster calibrated (method, for reproducibility)

1. **IC builder** `build_plot_ics_N3.py` — FIA SPCD→LANDIS map derived empirically from the
   live-tree histograms of IN_TREE.csv / OH_TREE.csv (23 species 1:1 + nearest-neighbor
   congener lumping; non-pool species dropped). ICs: IN 399 non-empty, OH 902.
2. **Warmstart** via `cma_es_optimize_cluster.py` (generalized, hardened, reads species from
   SpeciesData.csv, x0 from a cluster reference theta). IN warmstarted from the MN-bootstrap
   N3 reference; OH from the now IN-calibrated N3 reference.
3. **Densified likelihood pairing** (`run_param_set_{IN,OH}_t2.sh`, DENSE_PAIRING): the LL
   interpolates the predicted trajectory and pairs against every observed inventory year in
   the 0–30 yr window, not only 5-year steps. This raised IN's matched n from 201 (which the
   harvester rejected) to 733; OH ran at 713. This was the key unblock.
4. **Timeout hardening** (PERSEUS_TIMEOUT_GUARD in every optimizer): a hung per-candidate
   runner is scored as the penalty and the chain continues instead of crashing — observed
   working in production (IN iter0/cand0 hit it and the chain proceeded).
5. **CRLF fix** in `build_plot_scenario_{IN,OH}.sh`: PRISM_OH_l3.csv is CRLF, so the last
   ecoregion column carried a trailing \r and failed the header check; both builders now
   strip \r. Caught by the one-plot smoke test before any chain launch.

The cluster N3 reference (`tools/state_templates/cluster_N3_reference_theta.csv`) is now
frozen from IN's production theta.

## 4. Open items / next steps (priority order)

1. **Verify `wa_stwide_v3` lands and produces trajectories** (job 11204375). Check
   `states/WA/perseus/statewide/wa_t2v2_calibrated/runs/*/biomass_trajectory.csv` count and
   the aggregated state-median carbon. Then refresh `perseus/figures/statewide_carbon_5state.png`
   with WA's v2.0 year-100 number (currently still the v1.0 value) and note the shift in the
   scenario/methods text.
2. **Domain check on IN's calibration.** IN's per-plot LL (−1.31) is the weakest of the nine
   and an outlier within its own cluster (OH is −0.86). First things to inspect: the
   provisional oak/hickory SPCD lumps in `build_plot_ics_N3.py` (chestnut/chinkapin→WO,
   pignut/bitternut→MOK_HK, Shumard→NRO), and whether re-warmstarting IN from OH's vector or
   re-running with more iters helps. The N3 reference could later be re-frozen from whichever
   of IN/OH is the better-fitting reference.
3. **Update Methods Section 3** to the nine-state table (`docs/methods_section3_sixstate_update.md`
   is now stale at six).
4. **Continue CONUS expansion** per `docs/CONUS_expansion_plan.md` using `add_state.sh
   <FIPS> <ST> <CLUSTER>`. The infrastructure is in place: cluster references exist for
   N1/N2/N3/S1/P3; the generalized optimizer, densified runner, hardened timeout, and the
   CRLF-robust builders all work. The gating item for new states remains literature
   parameterization of cluster extension species (blend clusters N4/S2/P*/R* have no frozen
   reference yet). Note: any new state needs a per-cluster IC builder with the right SPCD map
   (build_plot_ics_N3.py is the template for eastern hardwoods).

## 5. Operational notes

- **SSH:** the uploaded `cardinal_key` (registered tertiary key, SHA256 oFxOjmd…c54) works
  directly as the Cardinal identity; the hpc-cardinal skill's `.ssh-keys/` were restored into
  `Documents/Claude/skills/hpc-cardinal/` (the read-only live mount had lost them). The
  2026-05-23 backup path rotates between sessions — don't rely on it.
- **Queue gate:** `run_param_set_*` and `run_statewide_buildfresh.sh` pause while
  `squeue --me > 100`. Chains throttle (not fail) behind large arrays like `c30m_pred`; this
  is expected. Give statewide jobs generous wall-time (the WA carbon job died at 1d12h; 3-day
  is the corrected budget).
- **Monitor:** `bash tools/check_t2v2_chains.sh [chain]` (PROMOTED detection fixed in v1.5).
- **Harvest:** `python3 tools/harvest_t2_chains.py --bayesian-dir <chain> --state <ST>`;
  requires n ≥ max(300, 0.85·max_n).

## 6. Repo state

All work committed and pushed; Cardinal repo fast-forwarded to match origin. Tags through
v1.7. Key files added/changed across these sessions: `build_plot_ics_N3.py`,
`cma_es_optimize_cluster.py` (+ per-cluster symlinks), `run_param_set_{IN,OH}_t2.sh`,
`build_plot_scenario_{IN,OH}.sh`, `check_t2v2_chains.sh`, `state_templates/`,
`patch_optimizer_timeout.py`, `patch_dense_pairing.py`, and the per-day session handoffs.
