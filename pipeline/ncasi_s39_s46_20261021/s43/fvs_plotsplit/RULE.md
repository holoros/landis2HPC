# Track H rule file: s41 FVS mortality recalibration grid values and selection rule, copied verbatim

Written 2026-10-19 21:25 EDT before any Track H fit. Source files (md5, path):

```
05ecb04f223a5205d7fcd1a0b2778165  /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs/fvs_mortrecal_PLAN_20261015.md
c8f32e8c945e074177b6a69a7a7b3a46  /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs/fvs_mortrecal_PLAN_AMEND1_20261015.md
e9ab0aae7476807b3313e52d64efffec  /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs/fvs_mortrecal_PLAN_AMEND2_20261015.md
769527f602ecd64ee9e8e34713d42865  /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs/fvsmr_run_20261015e.py
d1b698744725afda039a04c8c27260bb  /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs/fvsmr_select_20261015c.R
c73da77bf372356c4aa7dfe2f090c6be  /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs/fvsmr_score_20261015.py
```

Expected md5 from s41 MD5SUMS_s41d.txt:
```
769527f602ecd64ee9e8e34713d42865  fvsmr_run_20261015e.py
d1b698744725afda039a04c8c27260bb  fvsmr_select_20261015c.R
c73da77bf372356c4aa7dfe2f090c6be  fvsmr_score_20261015.py
05ecb04f223a5205d7fcd1a0b2778165  fvs_mortrecal_PLAN_20261015.md
c8f32e8c945e074177b6a69a7a7b3a46  fvs_mortrecal_PLAN_AMEND1_20261015.md
e9ab0aae7476807b3313e52d64efffec  fvs_mortrecal_PLAN_AMEND2_20261015.md
```

---- VERBATIM: fvs_mortrecal_PLAN_20261015.md, sections Knobs, Split, Objective and selection ----

## Knobs (standard keywords only; calibrated growth keywords untouched)

- kB, background scale: every calibrated MORTMULT multiplier is multiplied by kB (same species, same DBH range), and a
  species 0 MORTMULT kB record is placed before them so species without a calibrated record also get kB.
- PL, PU: one SDIMAX record with blank species value and field 2, field 5 = PL, field 6 = PU.
- kS, SDImax scale: each calibrated species SDIMAX value multiplied by kS. Because the trajectory depends on
  PL x SDImax and PU x SDImax, kS is a fallback for when PU = 95 is not enough; kS = 1 is preferred (tie rule).
- The keyword edits are inserted into the calibrated block; with kB = 1, PL = 55, PU = 85, kS = 1 the run must
  reproduce the calibrated arm exactly (null knob check, part of the reproduction gate).

Grid (216 settings per variant): kB in {1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0}; PL in {55, 65, 75};
PU in {85, 90, 95}; kS in {1.0, 1.25, 1.5}.

## Split

Per state, pair p goes to the fit half if int(md5(pair_id)[0:8], 16) is even, otherwise to the holdout half. The split
never looks at outcomes. Grid runs use a stratified subsample of the fit half: per state up to 1,500 pairs, sampled
proportionally within the t1 AGB classes [0,100), [100,200), [200,250), [250,inf) Mg/ha with seed 20261016 (all
fit pairs when the state's fit half is smaller).

## Objective and selection (per variant)

For each setting and each state in the variant, on the fit subsample, compute the four gate ratios and the mortality
ratio in each of the four AGB classes above. Gate excess G = max over the four gate quantities of
max(0, |ln r| - ln(upper)), with upper = 1.15 for gross, mortality and net and 1.25 / 0.80 for the dense class
(the asymmetric band is applied exactly). Class loss J = mean over the four classes of (ln(FVS mort / obs mort))^2.
Variant objective: Gv = max over the variant's states of G; Jv = mean over states of J.
Selection: among settings with Gv = 0, choose minimum Jv; if none has Gv = 0, choose minimum Gv, with Jv as tie
break. Settings within 2 percent of the chosen Jv (or Gv) are tied; ties go to kS = 1, then the smallest kB, then
PL = 55 and PU = 85 closest.
Per state fallback: only if the chosen per variant setting has G > 0 for any state on the fit subsample, the same
rule is applied per state to the same grid, and both the per variant and per state settings are scored on the
holdout; the per variant result is reported as primary.

---- VERBATIM: fvs_mortrecal_PLAN_AMEND1_20261015.md, section Change ----

## Change

A second grid is added on the same fit subsample (same split, same seed, same sampling), same knobs and keyword
mechanics:
kB in {1.0, 2.0, 3.0}; PL in {20, 25, 30, 35, 40, 45}; PU in {85, 90, 95}; kS in {1.0, 1.1, 1.2, 1.25, 1.35}
(270 settings per variant). PL is floored at 10 by the keyword reader, so all values are honored as written.
Selection uses the unchanged rule from the original plan applied to the union of both grids (486 settings per
variant). Everything downstream (holdout scoring, per state fallback rule, sanity run) is unchanged.
Both grids are reported.
---- VERBATIM: fvs_mortrecal_PLAN_AMEND2_20261015.md, section Change ----

## Change

A third grid on the same fit subsample, same selection rule, applied to the union of all three grids:
- fa, an annual density independent mortality proportion added by FIXMORT, all species, all DBH, mode 1 (adds to the
  survivors of the model's own mortality: WK2 = WK2 + (PROB - WK2) x p), point code 0. The cycle proportion is
  p = 1 - (1 - fa)^n with n the pair's own cycle length, so the annual rate is the same on every pair; one FIXMORT
  record per cycle in the multi cycle sanity run (dated at each cycle start year).
- Grid 3: kB = 1, PL = 55, PU in {85, 95}, kS in {1.0, 1.1, 1.2, 1.3},
  fa in {0, 0.0025, 0.005, 0.0075, 0.01, 0.0125, 0.015} (56 settings per variant).
- Tie preference order becomes: kS closest to 1, then smallest fa, then smallest kB, then PL and PU closest to 55 / 85.
Holdout scoring, per state fallback and the sanity run are unchanged, with the chosen fa included in the recalibrated
arm. All three grids are reported.
---- VERBATIM: grid constants as implemented, fvsmr_run_20261015e.py lines 38-43 ----
```
GRID = dict(kB=[1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0], PL=[55.0, 65.0, 75.0], PU=[85.0, 90.0, 95.0], kS=[1.0, 1.25, 1.5])
# Amendment 1 (fvs_mortrecal_PLAN_AMEND1_20261015.md): lower SDI onset and finer SDImax scale
GRID2 = dict(kB=[1.0, 2.0, 3.0], PL=[20.0, 25.0, 30.0, 35.0, 40.0, 45.0], PU=[85.0, 90.0, 95.0], kS=[1.0, 1.1, 1.2, 1.25, 1.35])
# Amendment 2 (fvs_mortrecal_PLAN_AMEND2_20261015.md): additive density independent FIXMORT rate fa (annual proportion)
GRID3 = dict(kB=[1.0], PL=[55.0], PU=[85.0, 95.0], kS=[1.0, 1.1, 1.2, 1.3], fa=[0.0, 0.0025, 0.005, 0.0075, 0.01, 0.0125, 0.015])

```

---- VERBATIM: selection as implemented, fvsmr_select_20261015c.R lines 11-24 ----
```
ex <- function(r, up) pmax(0, abs(log(r)) - log(up))
g[, G := pmax(ex(r_gross, 1.15), ex(r_mort, 1.15), ex(r_net, 1.15),
              ifelse(r_dense > 1.25, log(r_dense) - log(1.25), ifelse(r_dense < 0.80, log(0.80) - log(r_dense), 0)))]
g[, J := ((log(rm_c0_100))^2 + (log(rm_c100_200))^2 + (log(rm_c200_250))^2 + (log(rm_c250p))^2) / 4]
g[, `:=`(p1 = abs(log(kS)), p2 = fa, p3 = kB, p4 = abs(PL - 55) + abs(PU - 85))]
pick <- function(d) {   # d: one row per setting with columns Gv, Jv
  if (any(d$Gv == 0)) {
    c0 <- d[Gv == 0]; c0 <- c0[Jv <= 1.02 * min(Jv)]
  } else {
    c0 <- d[Gv <= 1.02 * min(Gv)]; c0 <- c0[Jv <= 1.02 * min(Jv)]
  }
  c0[order(p1, p2, p3, p4)][1]
}
v_agg <- g[, .(Gv = max(G), Jv = mean(J), p1 = p1[1], p2 = p2[1], p3 = p3[1], p4 = p4[1], grid = grid[1]), by = .(variant, kB, PL, PU, kS, fa)]
```

---- Track H application (written before any fit; the only change from s41 is which pairs form the fit and holdout halves) ----

- Plot key: Track D construction, s43/fvs_mi_ci/fvsci_boot_20261019b.py plot_key() copied verbatim: over the full
  pairs_{ST}.csv, union t1_id (PREV_PLT_CN) and pair_id (t2 PLT_CN), whitespace stripped; the key is the component root.
- Half: fit ("even") if int(md5(plot key)[0:8], 16) % 2 == 0, else holdout ("odd"); the same hash form as s41 half_of(),
  applied to the plot key instead of pair_id. Every pair of a plot is in the same half.
- Grid: the same three grids (216 + 270 + 56 settings per variant), the same stratified subsample of the fit half
  (cap 1,500 per state, four t1 AGB classes, seed 20261016), the same FVS binaries, calibrated block and run_pair
  (the s41 script is imported unchanged; only load_state's half column is replaced).
- Selection: the s41 rule above, unchanged (union of the three grids, 2 percent ties, tie order, per state fallback).
- Scoring: all odd plot pairs; default, old calibrated and recalibrated arms; frozen bands; point ratios as in
  fvsmr_score_20261015.py; intervals from 2,000 plot (cluster) bootstrap resamples, seed 20261019.
- Pipeline proof first: one s41 grid cell rerun on the original pair split must match its s41 row within 1e-6 relative.
