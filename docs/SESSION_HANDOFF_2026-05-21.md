# PERSEUS session handoff (v2)

**Date:** 2026-05-21
**Repo:** github.com/holoros/landis2HPC, branch main, in sync with origin
**Supersedes:** the earlier 2026-05-21 handoff. Adds the GUI build, the phase 3 backend, the GA/ME export tooling, and the Cardinal cleanup.

## One paragraph summary

GA Tier 2 v2 landed and was harvested after fixing a settling-timeout artifact in the harvester. A Forest Intelligence GUI was built, given sensible defaults, and wired to real Washington trajectories with an indicative statewide carbon readout. A phase 3 FastAPI backend that submits a scenario to Cardinal as a SLURM job was authored and its submission path was proven with a canary job. The GA and ME trajectory export has its merge tool ready; the heavy LANDIS runs are deferred to the post-chain window so they do not starve the running MN, WI, and MI calibration chains. Finished-chain SLURM logs were cleaned off scratch.

## Commits this session (newest last)

1. 972ed9e v1.1: GA T2 v2 landed, n-aware harvester, 19 per-state parity scripts.
2. b04e02f Forest Intelligence GUI v1 plus architecture doc.
3. d0a4d61 GUI defaults (Maine, scenario presets, projected layer) plus first handoff.
4. 232e391 GUI phase 2: real WA per-plot trajectories from atlas JSON.
5. ff0a5db GUI: indicative statewide carbon KPI.
6. f73f720 Phase 3 seed: FastAPI scenario backend.
7. f6c483b aggregate_atlas_trajectories.py (GA/ME atlas merge tool).

## Cardinal calibration state

| State | Job | Status | Per-plot LL | n |
|---|---|---|---|---|
| ME | (v1.0) | production | +0.056 | 612 |
| WA | (v1.0) | production | -0.217 | 805 |
| GA | 10021254 | landed + harvested | -0.8871 (iter5_cand8) | 1255 |
| MN | 10124727 | running, iter1 | -0.96 provisional | 2867 |
| WI | 10126909 | running, iter1 | -0.66 provisional | 935 |
| MI | 10126910 | running, iter1 | -0.17 provisional | 528 |

The three Great Lakes chains were still running at handoff (queue around 188 jobs). They should land roughly 12 to 15 hours from the start of this work, at which point the queue clears for the deferred compute below.

## Access notes

SSH key at the session path `outputs/.session_ssh/id_osc`. Every call needs `ssh -F /dev/null -i <key> -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no crsfaaron@cardinal.osc.edu`, and each bash call is independent so copy and chmod the key inside the same call. Repo on Cardinal at `/users/PUOM0008/crsfaaron/repos/landis2HPC`; live scripts at `/fs/scratch/PUOM0008/crsfaaron/landis2/tools`. GitHub push from Cardinal works (holoros authenticated).

## GUI status

The app is `perseus/dashboard/perseus_forest_intelligence_v1.html`, a self-contained single page tool. It opens on Maine with a scenario preset selector (no management reference, working forest, moderate climate, high climate plus disturbance, custom) and a projected biomass map layer at year 50. Washington uses its real per-plot Tier 0 and Tier 1 trajectories; the other states use the Chapman-Richards model anchored on observed biomass and the calibrated asymptote, marked with a measured or modeled label. There is an indicative statewide carbon headline (mean aboveground biomass times forest area times 0.47). Architecture and the five-phase roadmap are in `docs/GUI_v1_architecture.md`.

## Phase 3 backend status

`perseus/backend/` holds a runnable FastAPI seed: `config.py` (state registry, scenario to pipeline mapping, env-driven host and SSH settings), `cardinal_jobs.py` (build sbatch, submit over SSH, squeue status, read result.json), `app.py` (health, states, scenario run, status, result), plus requirements, launcher, and README. The single-plot scenario path runs `build_plot_scenario_{ST}.sh` plus LANDIS and extracts biomass at years 0, 25, 50, 75, 100. The SSH to sbatch to squeue to scancel path was smoke-tested with a canary job. It is a seed: before exposing it, add OSC-account authentication, a job database instead of the in-memory registry, and a results cache.

## GA and ME trajectory export status

The merge tool `perseus/tools/aggregate_atlas_trajectories.py` is committed and self-tested. It reads the Tier 0 and calibrated per-plot biomass CSVs, converts g/m2 to Mg/ha, and writes t0 and t1 year-keyed dicts onto each atlas plot record in the WA schema. The LANDIS generation that produces those CSVs is deferred to the post-chain window so it does not compete with the calibration chains. Plan: run a Tier 0 pass and a calibrated pass over the GA and ME plot sets (ME via `run_t2_best_100yr.sh`; GA via a uniform theta 0.30 analog), aggregate into `atlas/GA.json` and `atlas/ME.json`, re-sample into the GUI dataset, and re-wire so GA and ME show measured curves like WA.

## Cardinal cleanup

A cleanup pass confirmed the finished GA Tier 2 v2 chain was already tidy: the runner self-cleans its per-task SLURM logs and `runs/` scratch during execution, so the chain directory holds only about 7.5 MB across 112 candidates (`launch.log`, `theta.csv`, `log_likelihood.txt`, `SppEcoregionData_*.csv`, and `theta_best_production.csv`). The pass removed the phase 3 canary directory. The MN, WI, and MI bayesian directories were left untouched because their chains are still writing to them. The pass log is in `/fs/scratch/PUOM0008/crsfaaron/landis2/cleanup_*.log`.

## Post-chain compute window checklist (run when MN/WI/MI land)

1. `harvest_t2_chains.py --all`, then build the six-state production table and species heatmap, refresh methods Section 3, and tag v1.2.
2. Matched-n GA Tier 1 versus Tier 2 evaluation (task #118): uniform theta 0.30 across the 54 GA params through `run_param_set_GA_t2.sh` on `ga_t2_plotsubset.txt`, compare per-plot LL to iter5_cand8's -0.8871, set GA's production tier.
3. GA and ME trajectory generation, then `aggregate_atlas_trajectories.py`, then re-sample into the GUI.
4. Optionally extend the same trajectory export to MN, WI, MI once their production vectors are set.

## Other next steps

GUI phase 4 is statewide raster tiles for true wall-to-wall carbon. Phase 3 hardening (auth, job DB, cache) turns the seed into a deployable service. IN and OH still need FIA states 18 and 39 downloaded plus initial-community rasters, then the MN pipeline applies.

## Open tasks

Monitor MN (#112) and WI/MI (#114). Matched-n GA evaluation (#118). GA/ME trajectory generation (#126, aggregator done, compute deferred). Phase 3 backend hardening and phase 4 rasters to be created as tasks when prioritized.
