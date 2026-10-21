# Promote the Michigan and Wisconsin LANDIS tables (session 45, 20 October 2026)

Supersedes `landis-stage8-20261003/s40_20261015/RUN_promote_miwi_20261015.md`. Prepared for Aaron, not run: the registry is shared state, earlier edits to it were refused by the permission classifier, and the session 45 plan leaves this promotion as your decision. Run only once you have decided to promote.

The tables, the edits and the Wisconsin replacement are the same as in the 15 October runbook. What changed: the registry now has the Maine row (session 44), so the expected pre edit md5 and the backup name differ; the evidence now includes an exact reproduction of the session 40 confirmations, the stock ratio and three fresh seeds (Track M, `ncasi_gates_20261015/s45/landis_miwi/`, STATE.md there).

## Commands

```
cd /fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930

# 1. Pre edit checks. Stop if any md5 differs.
md5sum MI/inputs/SppEcoregionData_fia_20261015.csv WI/inputs/SppEcoregionData_fia_20261015.csv PARAMS_ACTIVE.csv
# expect b8752e12bf80bacdfb319f5808b8c225  MI table
#        46aa9ec78d3b5b8d6e445ad2c8968fc5  WI table
#        219a661aa74ab284b3253b43290e8f82  PARAMS_ACTIVE.csv (as left by the s44 Maine promotion)

# 2. Backup. PARAMS_ACTIVE_PREV_20261020.csv already exists (the pre Maine registry, c576eb78); use the b suffix.
cp -n PARAMS_ACTIVE.csv PARAMS_ACTIVE_PREV_20261020b.csv
md5sum PARAMS_ACTIVE_PREV_20261020b.csv
# expect 219a661aa74ab284b3253b43290e8f82

# 3. Edits: retire the MI _20260929 row and the WI _20261007 row, append the two new rows.
DEC="Aaron $(date +%F)"
sed -i -e "/^MI,MI\/inputs\/SppEcoregionData_fia_20260929.csv,/ s/,current,,.*/,superseded,,superseded by SppEcoregionData_fia_20261015.csv ($DEC)/" \
       -e "/^WI,WI\/inputs\/SppEcoregionData_fia_20261007.csv,/ s/,promoted,Aaron 2026-10-15,.*/,superseded,Aaron 2026-10-15,superseded by SppEcoregionData_fia_20261015.csv (fails density test 0.39)/" PARAMS_ACTIVE.csv
echo "MI,MI/inputs/SppEcoregionData_fia_20261015.csv,b8752e12bf80bacdfb319f5808b8c225,promoted,$DEC,fit ANPPmax x1 BiomassMax x2.5 ProbEstablish x0.1 from MI/inputs/SppEcoregionData_fia_20260929.csv (f4ae759c); s40 confirm 15536510 reproduced exactly by s45 15725435; behavioural gate pass at seeds 1234 20261020 20261021 20261022 (ncasi_gates_20261015/s45/landis_miwi/out/behav_gate_runs_seeds.csv); stock 1.003; net 1.069 of FIA" >> PARAMS_ACTIVE.csv
echo "WI,WI/inputs/SppEcoregionData_fia_20261015.csv,46aa9ec78d3b5b8d6e445ad2c8968fc5,promoted,$DEC,fit ANPPmax x1.6 BiomassMax x3.5 ProbEstablish x0.1 from WI/inputs/SppEcoregionData_fia_20260929.csv (9104d7d6); s40 confirm 15536778 reproduced exactly by s45 15725435; behavioural gate pass at seeds 1234 20261020 20261021 20261022 (ncasi_gates_20261015/s45/landis_miwi/out/behav_gate_runs_seeds.csv); stock 1.002; net 1.049 of FIA" >> PARAMS_ACTIVE.csv

# 4. Post edit checks.
diff PARAMS_ACTIVE_PREV_20261020b.csv PARAMS_ACTIVE.csv
# expect exactly: the MI _20260929 row and the WI _20261007 row changed to superseded, and the two new rows appended
wc -l PARAMS_ACTIVE.csv                                  # expect 10 (header plus 9 rows)
awk -F, 'NF!=6{print "BAD FIELD COUNT line " NR}' PARAMS_ACTIVE.csv   # expect no output
tail -n +2 PARAMS_ACTIVE.csv | while IFS=, read st p m s d n; do
  [ "$(md5sum "$p" | cut -c1-32)" = "$m" ] && echo "OK $st $s $p" || echo "MD5 FAIL $st $p"; done
# expect 9 OK lines, no MD5 FAIL
md5sum MI/inputs/SppEcoregionData_fia_20261015.csv WI/inputs/SppEcoregionData_fia_20261015.csv
# expect b8752e12... and 46aa9ec7... unchanged
md5sum PARAMS_ACTIVE.csv                                 # record the new registry md5
grep -c ',promoted,' PARAMS_ACTIVE.csv                   # expect 5 (NH, VT, ME, MI, WI)
```

The new registry md5 cannot be given in advance, because the decided field carries the date you run it. If anything fails, restore with `cp PARAMS_ACTIVE_PREV_20261020b.csv PARAMS_ACTIVE.csv`.

## Evidence (Track M, 20 October 2026)

**Tables (step 1).** MI `b8752e12bf80bacdfb319f5808b8c225`, WI `46aa9ec78d3b5b8d6e445ad2c8968fc5`, both as registered in the s40 runbook. The s40 derivation rule (awk in `~/s34/confirm_mi_20261015.sh` and `confirm_wi_20261015.sh`) applied to the `_20260929` tables (MI f4ae759c, WI 9104d7d6) reproduces both md5s.

**Reproduction (step 2, F9).** Both confirmations rerun at seed 1234 with copies of the s40 build script (`s45/landis_miwi/scripts/confirm_miwi_s45.sh`; differences: uses the existing table after an md5 check instead of writing it, run folder in the track, seed from `SEED`) and scored with a copy of the registered scorer (`score_miwi_s45.R`, from `pesc4_score_20261015.R`; pesc3 differs only in tag and grid). Array 15725435, scorer 15725465. The scorer's own reproduction gate passed. All scored fields are string identical to the s40 rows in `gates/behav_gate_runs_20261015g.csv` (MI) and `_20261015h.csv` (WI), and the year 0, year 10 and year 5 ANPP rasters are md5 identical to the s40 run folders.

| State | Gross | Mortality | Net | Dense | s40 |
|---|---|---|---|---|---|
| MI | 0.993 | 0.877 | 1.069 | 0.866 | 0.993, 0.877, 1.069, 0.866 |
| WI | 1.018 | 0.981 | 1.049 | 0.823 | 1.018, 0.981, 1.049, 0.823 |

**Stock (step 3).** Anchored year 0 aboveground live biomass over the EVALIDator 2024 stock (`gates/fiadb_live_agb_fourstate_20261001.csv`, which carries the same values: MI 1,050.96, WI 814.17). The gate reads the anchored ratio. It is a construction pass that tests bookkeeping, not prediction.

| State | Year 0 Tg | FIA 2024 Tg | Anchored ratio | Unanchored ratio (diagnostic) | Anchoring scale (diagnostic) |
|---|---|---|---|---|---|
| MI | 1,054.063 | 1,050.96 | 1.003 | 0.669 (table 0.334) | 1.499 (table 2.998) |
| WI | 815.657 | 814.17 | 1.002 | 0.767 (table 0.383) | 1.306 (table 2.611) |
| NH check | 315.106 | 314.26 | 1.003 | 0.759 (table 0.379) | 1.321 (table 2.641) |
| VT check | 294.165 | 294.27 | 1.000 | 0.792 (table 0.396) | 1.262 (table 2.525) |

NH and VT year 0 values are from `gates/behav_gate_confirm_20261015c.csv` and give the expected 1.003 and 1.000. The anchoring scale is the uniform multiplier between `cohort_biomass_by_mapcode_fiadb.csv` and `cohort_biomass_by_mapcode.csv` (row ratios agree to 0.001); the unanchored ratio is year 0 divided by that scale, over FIA. The "table" values are from `gates/anchor_ic_fourstate_20261006.csv` (instate raw over FIA, and its scale); that scale is twice the cohort table multiplier in all four states. Not diagnosed here; it does not touch the anchored ratio. No ratio fell outside 0.5 to 2, so no code diagnosis was triggered.

**Fresh seeds (step 4).** Array 15725604 (seeds 20261020, 20261021, 20261022), scorer 15725605 (reproduction gate passed, 8 of 8 complete). Registered gate: stock within 10 percent; gross, mortality, net 0.85 to 1.15; dense 0.8 to 1.25.

| State | Seed | Stock | Gross | Mortality | Net | Dense | Net Tg/yr | FIA net (95 pct) | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| MI | 1234 | 1.003 | 0.993 | 0.877 | 1.069 | 0.866 | 20.023 | 18.729 (17.859 to 19.599) | PASS |
| MI | 20261020 | 1.003 | 0.993 | 0.876 | 1.070 | 0.866 | 20.039 | | PASS |
| MI | 20261021 | 1.003 | 0.993 | 0.877 | 1.068 | 0.866 | 19.998 | | PASS |
| MI | 20261022 | 1.003 | 0.993 | 0.874 | 1.069 | 0.866 | 20.030 | | PASS |
| WI | 1234 | 1.002 | 1.018 | 0.981 | 1.049 | 0.823 | 19.839 | 18.914 (18.363 to 19.466) | PASS |
| WI | 20261020 | 1.002 | 1.018 | 0.978 | 1.049 | 0.823 | 19.848 | | PASS |
| WI | 20261021 | 1.002 | 1.018 | 0.978 | 1.049 | 0.823 | 19.837 | | PASS |
| WI | 20261022 | 1.002 | 1.018 | 0.981 | 1.049 | 0.823 | 19.843 | | PASS |

## Caveats

- Net growth is above the FIA 95 percent upper bound in every run (MI by about 0.4 to 0.44 Tg/yr, WI by about 0.37 to 0.38). The gate is the 0.85 to 1.15 band, which both pass.
- Narrowest margins: MI mortality 0.874 to 0.877 (about 2.4 points above the 0.85 floor); WI dense 0.823 (about 2.3 points above the 0.8 floor).
- Seed spread is small (MI net 1.068 to 1.070, WI 1.049). Year 0 is identical across seeds, so the stock ratio does not vary by seed.
- Carried forward from 15 October: runs built from these full tables must filter rows to the run's active ecoregions, as `confirm_mi_20261015.sh` does (for these runs the filter kept every row). ProbEstablish now differs from the template, so any PnET-II coupling or factorial builder that regenerates ProbEstablish would undo this fit; check before the factorial build. The WI row replaces the `_20261007` table, which fails the density test at 0.39.
