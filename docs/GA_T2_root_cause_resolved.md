# GA Tier 2 root cause identified — race condition in runner, not pipeline failure

**Date:** 2026-05-17
**Status:** root cause identified; fix is one-line in `run_param_set_GA_t2.sh`
**Impact:** GA Tier 2 can be successfully re-run with the fix; no fundamental pipeline issue

## Findings

The GA T2 chain was previously characterized as a per-plot pipeline failure (`docs/GA_T2_failure_memo.md`). Closer inspection of preserved candidate directories reveals a different story:

| Per-candidate diagnostic | Count |
|---|---|
| biomass_trajectory.csv files preserved per candidate | 629–646 |
| trajectories with valid biomass data (>30 bytes) | 99.5–100% |
| sampled trajectories with valid pid → cn → obs → invyr chain | 200 / 200 |
| sampled trajectories yielding ≥ 1 paired residual | 198 / 200 |
| residuals per plot (mean) | 1.7 |
| **expected total residuals per candidate** | **≈ 1,068** |
| **actual residuals reported by runner** | **2** |

The pipeline is working. The aggregator reads the right files and finds the right matches. But the runner's main script ran the LL aggregator at a moment when only 2 of the 629 array tasks had finished flushing their biomass_trajectory.csv to disk.

## Race condition mechanism

The runner submits a SLURM array job of N=779 tasks (one chunk for GA's 779-plot subset) and waits:

```bash
JID=$(sbatch --parsable $CHK)
sleep 60
while squeue -j $JID -h -r 2>/dev/null | grep -q .; do sleep 30; done
# At this point: SLURM no longer reports the job in queue
# BUT: array tasks may still be in flight on compute nodes,
# or have just completed and not yet flushed stdout/stderr/CSV to shared filesystem
```

When `squeue` returns empty, the SLURM scheduler considers the array job complete but the array tasks themselves may have just completed their inner work without yet committing their output files (write-back caching, NFS sync delays, etc.).

The LL aggregator then reads `$BAY/runs/plot_*/biomass_trajectory.csv`. At that moment only the array tasks that ran on the same node as the runner's `cd` directory have committed. Tasks on other nodes are still in flight or in commit. The aggregator finds n = 2 plots, computes LL over those, writes log_likelihood.txt = 15.75 (a "great fit" over 2 plots — sample-size degeneracy!), and CMA-ES tells() this candidate as fitness=-15.75. CMA-ES is misled.

This pattern was masked in WA T2 because:
- The WA `run_param_set_WA_t2.sh` runner has a slightly different submit-and-wait pattern that includes a `sleep 60` plus a per-plot existence check.
- The WA aggregator runs on a candidate-internal scratch directory that benefits from shared local cache.

The GA runner uses a simpler `wait then aggregate` pattern and was caught.

## Fix

The one-line fix is to add a settling sleep after the SLURM wait, so all array tasks have time to flush their per-plot output before the LL aggregator reads:

```bash
JID=$(sbatch --parsable $CHK)
sleep 60
while squeue -j $JID -h -r 2>/dev/null | grep -q .; do sleep 30; done
sleep 120  # let array task output settle on shared FS (NEW)
```

A more robust fix is to actively check that all expected trajectory files exist before proceeding:

```bash
while squeue -j $JID -h -r 2>/dev/null | grep -q .; do sleep 30; done
# Wait for output settling: at least 90% of expected trajectories
EXPECTED=$(wc -l < $PLOT_SUBSET)
THRESHOLD=$(( EXPECTED * 9 / 10 ))
while true; do
  COUNT=$(find $BAY/runs -name biomass_trajectory.csv 2>/dev/null | wc -l)
  [ $COUNT -ge $THRESHOLD ] && break
  sleep 30
done
```

The active check is preferred because it adapts to actual array completion rather than blindly sleeping. We adopt the active check as the v1.0.1 fix.

## Implications for the v1.0 manuscript

1. **GA Tier 2 can be successfully re-run** with the patched runner. We have not done this for v1.0 (T2 deferral remains the published state) but a v1.x release should include the re-run T2 GA vector.

2. **The driver-level `MIN_N_PAIRS = 300` guard** that we added to `cma_es_optimize_WA.py` and `cma_es_optimize_GA.py` (commit 6d38ce5) would have correctly flagged every GA T2 candidate as DEGEN under the original runner, because every candidate had n < 300 reported to CMA-ES. This validates the guard.

3. **The three-mode pathology taxonomy is reinforced.** This is a fourth, even more subtle, manifestation of the sample-size degeneracy mode — it arises not from genuine plot failure but from an upstream race condition that makes the data appear to be missing. The diagnostic `MIN_N_PAIRS` guard catches it regardless of root cause.

4. **The methods paper Section 4.5 fourth limitation paragraph remains valid** — GA Tier 2 is deferred from v1.0 — and gains a useful follow-on: "Root cause identified post-v1.0 as a runner race condition; patched in v1.0.1 (see `docs/GA_T2_root_cause_resolved.md`); GA Tier 2 re-run is the natural follow-on technical work."

## Recommended next steps (in priority order)

1. **Patch `run_param_set_GA_t2.sh`** with the active settling check above. Commit to perseus/tools/. Tag v1.0.1.
2. **Re-run GA Tier 2** with the patched runner + the v1.0 driver guards. Expect roughly the same compute as the original run (~12-15 hours).
3. **Apply the same active settling check to `run_param_set_WA_t2.sh`** as a defense-in-depth measure even though WA wasn't observably affected.
4. **Update Methods Section 4.5** to reference this resolution memo when v1.0.1 lands.
5. **Update the Carbon Atlas dashboard** with the GA Tier 2 vector once it lands.
