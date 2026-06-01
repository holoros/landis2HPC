# PERSEUS session handoff (2026-05-31, part 3 — IN landed, densified pairing, in_t2_v3)

**Repo:** github.com/holoros/landis2HPC, branch main, in sync with origin
**Builds on:** `SESSION_HANDOFF_2026-05-31b.md` (N3 unblocked + IN chain launched).

## One paragraph summary

The warmstarted IN chain (`in_t2_v2`) ran all 8 CMA-ES iterations cleanly — validating the
whole hybrid pipeline end to end, including the v1.5 timeout guard (iter0/cand0 hit the
same hang that killed the 2026-05-29 chain, was scored as the penalty, and the chain
continued instead of crashing). But the harvester correctly declined to promote it: the
likelihood paired only **n=201** observations, below its 300-pair floor, because the LL
compared predicted vs observed biomass only at 5-year LANDIS output steps. We densified the
pairing (linear interpolation of the predicted trajectory to every observed inventory year
inside the 0–30 yr window), which raises IN's potential paired sample from 201 to **747**.
The IN chain was relaunched as `in_t2_v3` with the densified runner, warmstarted from
`in_t2_v2`'s own converged theta.

## What `in_t2_v2` showed (now superseded by v3)

- 8 iterations, 14 candidates each, all scored; negLL improved 273 → 265 (best iter7/cand8,
  total negLL −264.82). theta_best.csv written.
- iter0/cand0 = 1e6 penalty (a runner hang) — caught by the `PERSEUS_TIMEOUT_GUARD`; the
  chain proceeded normally. This is the hardening working in production.
- Harvest result: `max_n=201 < floor max(300, 0.85·201)` → not promoted. Per-plot LL ≈ −1.32
  (weaker than other states, partly an artifact of the tiny matched sample).

## Root cause of the small sample (structural, not a bug)

The LL block in `run_param_set_IN_t2.sh` only paired observed biomass at `invyr + {0,5,…,30}`.
IN's untreated set is 435 plots, 235 of them with exactly two FIA measurements, and eastern
remeasurement intervals (≈5–7 yr) rarely fall on 5-year multiples of the first inventory
year. Measured on the 157 IC-backed subset plots: 5-year pairing → n=201; pairing at every
observed year in the window → **n=747**.

## The fix: densified pairing (option 1)

`run_param_set_IN_t2.sh` and `run_param_set_OH_t2.sh` LL blocks now (`DENSE_PAIRING`):
sort the predicted years, and for every observed year whose offset from `invyr` falls in
`[0, max_predicted_year]`, linearly interpolate the predicted biomass at that offset and
form a residual. Years outside the predicted window are skipped. Applied with the idempotent
`patch_dense_pairing.py`; both runners pass `bash -n`, and the interpolation math was
unit-tested (off=7 between yr5=70 and yr10=90 → 78.0; out-of-window excluded). Patched
runners are committed to the repo (`perseus/tools/run_param_set_{IN,OH}_t2.sh`); the
pre-patch versions are backed up on scratch as `*.bak_20260531`.

## `in_t2_v3` (running)

Submitted as **job 11146353** (72 h), densified runner, warmstarted from
`states/IN/perseus/bayesian/in_t2_v2/theta_best.csv` (IN's own near-optimum → faster
convergence than the MN bootstrap). Expect iter0 candidates to report n≈700+ in their
`launch.log` `n=… LL=…` line — confirm that, then it should harvest cleanly.

## Next steps

1. **Confirm `in_t2_v3` iter0 lands with n≥300** (check `states/IN/perseus/bayesian/in_t2_v3/
   in_t2_v3_iter0_cand1/launch.log` for the `n=…` line, or `bash tools/check_t2v2_chains.sh
   in_t2_v3`). Real negatives, n≈700 → the densified objective is healthy.
2. **Harvest when landed:** `python3 tools/harvest_t2_chains.py --bayesian-dir
   states/IN/perseus/bayesian/in_t2_v3 --state IN`; with n≈700 it should clear the 300 floor
   and write theta_best_production.csv → PERSEUS is 8 states.
3. **Re-freeze the N3 reference** from IN's production theta so OH (and future N3 states)
   warmstart from a calibrated IN rather than the MN bootstrap.
4. **Smoke-test then launch OH** with the same densified runner, warmstarted from the
   re-frozen N3 reference.
5. **Verify the WA v1.4.1 statewide-carbon rerun output** (`wa_stwide_v2` left the queue;
   `states/WA/perseus/statewide/wa_t2v2_calibrated/` had only setup files at last check) and,
   if complete, refresh the five-state carbon figure with WA's v2.0 number.

## Caveats

- Densified pairing includes the year-0 (IC) point as before, which is near-tautological;
  the estimator's character is otherwise unchanged, just more densely sampled in time.
- `in_t2_v3` warmstarts from a theta optimized on the sparse (n=201) objective; the densified
  objective differs, so a few iterations of movement are expected and healthy.
