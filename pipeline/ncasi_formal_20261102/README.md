# NCASI Phase 1 formal scoring: driver README (pinned 2026-10-26, no data)

Prepared 26 October 2026 for the formal scoring runs of 2 to 11 November 2026 on OSC Cardinal.
Governing protocol: `s49/docs/2026-11-02_ncasi-formal-scoring_PLAN.md` (revision v5 governs over v4, v3, v2 and the base text).
Base folder: `B=/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015`. Manifest: `$B/s48/formal_prep/manifest.tsv`
(285 rows, md5 6069decc95a0e8c335303391d8732ce1 on 26 October; frozen at submission per v3 item 7).

This folder holds copies of the 50 registered scorer and driver scripts named in `$B/s48/formal_prep/syntax_check.tsv`
(all 50 appear in the manifest with a role containing scorer, driver, script, job, engine, selection or builder). Nothing here was run.
Everything below about order and inputs is drawn from the protocol, the s43, s44, s46 and s48 STATE.md files and the text of the
registered job scripts. Anything not established from those sources is marked [UNKNOWN]. Nothing was invented to fill a gap.

## Contents

| File | Purpose |
|:-|:-|
| `registered/<tool>/<origin>/<name>` | Byte identical copies of the 50 registered scripts. `<origin>` is the source folder (needed because `fia_bins_memn_20261015.R` is registered at four paths). |
| `registered_md5.tsv` | manifest path, copied path, manifest md5, copy md5, match yes/no, role. 50 of 50 match. |
| `registered_paths.txt` | The 50 manifest paths, one per line (input to the helper). |
| `copy_registered.sh` | The copy and md5 check script that produced the two files above. |
| `verify_manifest.sh` | Manifest verification helper (below). `verify_registered_20261026.log` is its run on the 50 scripts: 50 OK. |
| `COMMIT.txt`, `manifest_append.tsv`, `PUSH_formal_20261102.md` | Git commit record, manifest rows to append, push runbook for Aaron (written after the commit, so on Cardinal only, not in the commit). |

## Manifest verification step (every job, first)

Protocol v2 rule 1: a run whose inputs do not match the manifest is not scored. v3 item 5: the verdict rests only on a manifest
matching run; a mismatched output is quarantined. Each formal job therefore runs, before anything else:

```
$B/s49/formal_scripts/verify_manifest.sh -f <per job path list>   # exit 0 required; nonzero = stop, do not run
```

or the equivalent `md5sum -c <per job manifest subset>` where the subset is the manifest rows for that job's scripts, inputs and
targets reformatted as `md5  path` lines. The per job path lists are [UNKNOWN]: they have not been written yet and must be cut from
the manifest by role before 2 November (the roles each job needs are listed per tool below). The existing in job checks are weaker
than this and are kept in addition, not instead: FVS checks `MD5SUMS_s41d.txt`, OSM checks `MD5SUMS_s41osm_d.txt` (manifest role
`osm:pin list`), CBM checks only its two scripts by inline printf, the s46 LANDIS scorer job checks only its own R script, and the
plot imputation jobs only print md5sums without checking them.

`verify_manifest.sh` usage: `verify_manifest.sh [-m manifest.tsv] PATH... | -f LISTFILE | -` (paths on stdin). Prints OK, MISMATCH,
MISSING or NOT_IN_MANIFEST per path and a summary line with the manifest md5 and row count; exit 0 only when all are OK, 1 otherwise,
2 on usage error.

## General cautions found while reading the registered scripts

1. Several registered drivers refuse to overwrite an existing run folder and exit 0 or 1 without running: `confirm_nhvt_r2_20261015.sh`
   and `smoke_miwi_s46.sh` print `SKIP ... exists`, `smoke_run_s43.sh` skips when `Landis-log.txt` exists, and
   `cbm_gate_job_v2_20261015.slurm` aborts when `cbm/rerun_v2_20261015` exists. The draft runs already occupy those folders.
   How the formal run gets a fresh output folder while keeping the registered script unchanged (new run name or TAG by environment
   variable where the script takes one, or a dated re-pinned copy under v2 rule 10) is [UNKNOWN] and needs Aaron's decision before 2 November.
2. The registered job scripts hard code their session folders (s41, s43, s44, s46, cbm). The copies in this folder are for the
   record and the git commit; the jobs submitted on 2 November run from the registered paths, which the manifest pins.
3. v2 rule 2 and v3 item 4: one run per tool and state; a rerun only for a nonzero exit before output is written.

## LANDIS-II (all six states, seed 1234, 10 year anchored run)

Registered configuration: protocol v2 item 1. Scripts live under `registered/landis/`.

Order on 2 November (per state group; the four groups are independent and may be submitted together):

| Step | State(s) | Script (manifest role) | Reads (manifest roles) | Writes |
|:-:|:-|:-|:-|:-|
| L0 | all | `verify_manifest.sh` on the LANDIS subset | manifest | log |
| L1 | NH, VT | `confirm_nhvt_r2_20261015.sh` (landis:driver:NH VT confirm r2), sbatch array 0-1 | landis:input:NH and VT promoted table (md5 checked in script), landis:registry, run inputs copied from `states_fb_20260930/<ST>/runs/smoke_20261001_d10` (landis:run input:NH/VT confirm scenario, IC, filtered table) | run folder `states_fb_20260930/<ST>/runs/fit_20261015_d10_confirm_*_r2/` (LANDIS output rasters, logs, RUN_SPEC.txt) |
| L2 | NH, VT | `confirm_score_20261015.R` (landis:scorer:NH VT), sourcing `behav_gate_score_20261015.R` (landis:scorer:NH VT parent) | landis:scorer input:NH VT surface preds, reproduction gate reference (2 files), target:FIA pair bins NH VT MI WI, target:NH VT MI WI GRM targets | draft equivalent: landis:draft output:NH VT confirm (`behav_gate_confirm_20261015c.csv`). Formal output name [UNKNOWN]. Job script that invokes this scorer: [UNKNOWN] (none registered; the s34 folder holds only the driver). |
| L3 | ME | `seeds_s44.slurm` task 0 only (landis:driver:ME array; seed 1234 control) calling `smoke_run_s44.sh` (landis:driver:ME) with env ST=ME RN=s_me_a2.5_b3_seed1234 SRCT=landis:input:ME promoted table A=1 B=1 PE=1 ETAG=from270 BUILD=orig | landis:input:ME promoted table (b7336118), landis:run input:ME seed1234 IC, scenario, table; landis:scorer input:ME ecoregion layer; s43 build IC (`landis:input:ME IC build original backstop`) | `s44/landis_me_promote/runs/ME/<RN>/` rasters and run table |
| L4 | ME | `score_s44.slurm` (landis:scorer job:ME; env TAG RR PAT) running `score_memn_s44.R` (landis:scorer:ME) | fia:input:ME PLOT, COND, TREE (LANDIS scorer); landis:scorer input:ME ecoregion layer; target:FIA pair bins ME MN; target_ME_MN_evalidator_2024 or the hard coded ME targets (v4 item 8 check required before the run) | `s44/landis_me_promote/out/behav_gate_memn_<TAG>.csv` (draft: landis:draft output:ME seed1234 rescore, `behav_gate_memn_repro43c.csv`) |
| L5 | MI, WI | `smoke_s46.slurm` (landis:driver:MI WI array, 0-1, SEED=1234) calling `smoke_miwi_s46.sh` (landis:driver:MI WI) | landis:registry (promoted row md5 checked), landis:input:MI and WI promoted table, landis:run input:MI/WI smoke1234 IC, scenario, table; landis:driver input:MI WI grid | `s46/landis_miwi_promote/runs/<ST>/confirm_seed1234/` |
| L6 | MI, WI | `score_s46.slurm` (landis:scorer job:MI WI; env TAG GRID; checks its own md5) running `score_miwi_s46.R` (landis:scorer:MI WI) | target:FIA pair bins NH VT MI WI, target:NH VT MI WI GRM targets, target:NH VT MI WI stock (s45) | `s46/landis_miwi_promote/out/behav_gate_runs_<TAG>.csv`, `raw_runs_<TAG>.csv` (draft: smoke1234) |
| L7 | MN | `smoke_run_s43.sh` (landis:driver:MN; env ST RN SRCT A B PE ETAG) with the registered MN configuration: SRCT = landis:input:MN base table (4df18984), PE=0.1 (run table fb295178), original builder age backstop, IC 2f2f3e1e, ecoregions f1004a9f | landis:run input:MN base run IC, scenario, table; landis:scorer input:MN ecoregion layer (s43) | `s43/landis_memn/runs/MN/<RN>/` |
| L8 | MN | `scoreb.slurm` (landis:scorer job:MN; env TAG) running `score_memn_s43b.R` (landis:scorer:MN) | fia:input:MN PLOT, COND, TREE (LANDIS scorer); target:FIA pair bins ME MN; MN targets (v4 item 8) | `s43/landis_memn/out/behav_gate_memn_<TAG>.csv` (draft: `behav_gate_memn_s43b.csv`) |
| L9 | all | LANDIS stock beside the verdict (v2 item 2, v5 item 3): year 0 aboveground live biomass of the run over EVALIDator 2024 stock, "the s45 step 3 calculation" | run TotalBiomass-0 raster; target:NH VT MI WI stock (s45); target_ME_MN_evalidator_2024 | one stock ratio per state. Script: [UNKNOWN] (no manifest row and no registered script implements it; the protocol says it is to be added as a pinned step before 2 November). |

Not rerun on 2 November (registered as provenance of pinned inputs only): `build_ic_s43.slurm` and `build_ic_v3_drybio_s43.R`
(landis:IC builder job and builder; produced the ME and MN initial communities, s43 STATE step 4), `preanchor_gates_anchor_s43.R`
(landis:IC anchoring; anchored the IC to EVALIDator stock, s43 steps 5 and 6; MN IC md5 2f2f3e1e is pinned as a run input),
and `fia_bins_memn_20261015.R` (landis:script:FIA ME MN bin builder; produced target:FIA pair bins ME MN, d6ca4bb0, which is pinned).
The MN seed: protocol v2 item 1 fixes seed 1234 in every state; s43 STATE records the MN base run scenario as seed 1234
(manifest role `landis:run input:MN base run scenario (seed 1234)`).

## FVS (all six states, holdout split by pair)

Registered configuration: protocol v2 item 3 (NE variant SDIMAX x1.3, FIXMORT 0.0100 for ME, NH, VT; LS variant SDIMAX x1.1,
FIXMORT 0.0100 for MI, WI, MN; no RANNSEED). Scripts under `registered/fvs/`.

| Step | Script (role) | Reads (roles) | Writes |
|:-:|:-|:-|:-|
| F0 | `verify_manifest.sh` on the FVS subset | manifest | log |
| F1 | `fvsmr_job3c_score_20261015.slurm` (fvs:job:holdout run and score), one sbatch. In order inside the job: `md5sum -c MD5SUMS_s41d.txt`; `Rscript fvsmr_select_20261015c.R` (fvs:selection, writes the registered settings csv); `fvsmr_run_20261015e.py --mode score` (fvs:driver; keyword files from `inventory_keyfile.py`, fvs:keyword generator); `fvsmr_score_20261015.py` (fvs:scorer:holdout); `fvsmr_run_20261015e.py --mode sanity` | fvs:registered settings and fit diagnostics, fvs:input:holdout split (six), fvs:input:pairs (six, the observed comparator), fvs:input:t1 trees (six), fvs:input:NE and LS calibrated keyword block, fvs:binary NE and LS, fvs osm:input:NSVB emulator coefficients, fvs:plan and amendments 1 and 2 | `s41/fvs/fvs_mortrecal_holdout_results_20261015.csv` and `..._holdout_bins_...csv` (fvs:draft output:holdout results, bins), `work/hold_pairs_<ST>.csv` (fvs:draft output:holdout pair runs), sanity csvs |

Caution: the job writes into `s41/fvs` over the draft output names; a formal run would overwrite the pinned draft outputs unless the
output location is changed. How that is handled is [UNKNOWN] (see general caution 1). The per state arm sensitivity (v2 rule 15)
and the plot level split (s43/fvs_plotsplit) have no registered script in the manifest: [UNKNOWN]. The s49/fvs_config folder
exists but `s49/fvs_config/jobs` did not exist on 26 October; the "FVS calibrated config directory read by FvsConfigLoader is pinned
by listing before 2 November" (v2 item 3) was not found in the manifest on 26 October: [UNKNOWN].

## CBM-CFS3 (all six states, FVS_FIAW_NEW curves, no harvest, 10 years)

Registered configuration: protocol v2 item 4 (libcbm 2.10.2, CBM3 model, no young age correction, v4 scorer). Scripts under `registered/cbm/`.

| Step | Script (role) | Reads (roles) | Writes |
|:-:|:-|:-|:-|
| C0 | `verify_manifest.sh` on the CBM subset | manifest | log |
| C1 | `cbm_gate_job_v2_20261015.slurm` (cbm:job), one sbatch. Inside, in order: inline md5 check of the two python scripts; six parallel `cbm_gate_run_v2_20261015.py <ST> noharv $O --years 10` (cbm:driver); `cbm_gate_score_v4_20261015.py $O` (cbm:scorer v4); then an inline comparison against the first pass results | cbm:input:<ST> sit_config.json, classifiers, age_classes, inventory, growth_and_yield (FVS_FIAW_NEW), disturbance_events, disturbance_types, transition_rules (registered source config, six states), cbm:input:<ST> AIDB; target:NH VT MI WI GRM targets (read by the CBM scorer per its manifest role); ME and MN targets per v4 item 8 | `$O/pools_<ST>_FVS_FIAW_NEW_noharv_10yr.csv`, `$O/flux_<ST>_...csv`, `$O/cbm_gate_results_v4_20261015.csv` (cbm:draft output roles), logs under `$O/logs` |

Caution: `$O` is hard coded to `cbm/rerun_v2_20261015`, which exists (the draft run), and the job aborts if it exists (general
caution 1). The age class test is registered but never built (v2 item 4, v3 item 1): not exposed, nothing to run.

## Plot imputation (CEM engine, all six states, seed 42, 20 simulations, 2 cycles)

Registered configuration: protocol v2 item 5: engine file set listing md5 0a2b3724 (`s43/cem_ablation/engine_c`, the 13 active
files pinned singly: `R/00_config.R` to `R/11_economic_harvest.R` and `run_projection.R`, manifest roles cem:engine active file and
cem:engine entry point), config seed 42, registered scorer `cem_gate_score_s41d8.R` (cem:scorer registered) run through
`cem_gate_score_s43c_reg.R` (cem:scorer copy used for s43 engine_c output; differs from s41d8 only in I/O paths, s43 cem_ablation STATE).
Scripts under `registered/plot_imputation/`.

| Step | Script (role) | Reads (roles) | Writes |
|:-:|:-|:-|:-|
| P0 | `verify_manifest.sh` on the plot imputation subset (13 engine files, scorers, drivers, patches, config listing) | manifest | log |
| P1 | `run_ablation_s43c.slurm` (cem:driver (c00base flags)) restricted to array tasks 0-5 (config c00base, states ME NH VT MI WI MN; the flags equal the s41 f2gate flags per the script header). The s41 driver `run_engine_fix_s41g.slurm` (cem:driver (s41 f2gate)) is registered as the provenance of the draft baseline (tasks 6-11, engine_fix2) and is not the formal driver because it runs engine_fix2, not engine_c | engine_c files; cem:engine config listing; FIA_DATA_DIR = fia:input:<ST> PLOT, COND, POP_* (CEM scorer roles name the same files); cem:engine patch F1 and F2 (provenance only) | `engine_c/output/<ST>_*_c00base/` per plot archives (stay on Cardinal) |
| P2 | `cem_gate_score_s43c_reg.R <ST> <tag> <engine>` per state | cem:scorer input:observed stock <ST> and observed GRM <ST> (`work/stock_cond_<ST>.rds`, `grm_cond_<ST>.rds`), fia:input:<ST> POP_* (CEM scorer) | `cem_gate_<ST>_<tag>.csv` in CEM_OUT (draft: cem:draft output:baseline <ST>, `cem_gate_<ST>_f2gate_20261016e.csv`) |

Caution: the job that invokes the s43c_reg scorer (`score_ablation_s43c.slurm`, md5 449c63a7 per s43 STATE) is not in the manifest;
the registered scorer job `score_fix_s41i.slurm` (cem:scorer job) is hard wired to the s41 engine folders and job id 15576378, so
it cannot score an engine_c run unchanged. The formal scoring job script is therefore [UNKNOWN]. Rules 3 and 14 (run to run spread
0.0055, verdict unstable flag) are applied in reporting, not by a registered script. The dense stand test is not exposed.

## OSM (Maine only; NH and VT not runnable, "fail (not run)")

Registered configuration: protocol v2 item 6 (binary v2.26.1, 7,510 pairs, NSVB emulator; stock not exposed by construction).
Scripts under `registered/osm/`.

| Step | Script (role) | Reads (roles) | Writes |
|:-:|:-|:-|:-|
| O0 | `verify_manifest.sh` on the OSM subset | manifest | log |
| O1 | `osmgate_job_20261016d.slurm` (osm:job), one sbatch. Inside, in order: `md5sum -c MD5SUMS_s41osm_d.txt` (osm:pin list); two 30 pair smokes (`osmgate_run_20261016d.py --limit 30`, cycle and annual); full `--mode cycle`; full `--mode annual` (osm:driver); `osmgate_score_20261016b.py` (osm:scorer) | osm:binary, osm:input:BGI lookup, osm:input:species crosswalk, fvs osm:input:NSVB emulator coefficients, fia:input:ME PLOT (OSM), FVS pairs and trees for ME [ASSUMPTION: the driver header says it writes `work/osm_pairs_ME*.csv` keyed on the plot control number; which fvs:input files it reads was not verified line by line] | `s41/osm/osm_gate_results_me_20261016.csv` (osm:draft output:ME results), `osm_gate_bins_me_20261016.csv`, `work/osm_pairs_ME*.csv` (plot keyed, stays on Cardinal) |

Caution: outputs are written over the draft output names in `s41/osm` (general caution 1). The 3,861 pair and YPC sensitivities
(v2 rule 15) have no registered script: [UNKNOWN].

## GLFPS

Scored only if a pinned configuration exists by 1 November (v2 item 8, v4 item 6). No script is registered: nothing in this folder.

## Restricted data

Every file in this folder was scanned (case insensitive grep for the plot control number column, the latitude and longitude column names, and credential words; a header line scan for plot level
column names, and a secret pattern scan) before the git commit. Files with a hit were left out of the commit and are listed in
`COMMIT.txt`. The hits are column name references and log filters in code (no data rows); whether to include them is Aaron's call.
No input, target, run output or FIA file is in this folder or in the commit.
