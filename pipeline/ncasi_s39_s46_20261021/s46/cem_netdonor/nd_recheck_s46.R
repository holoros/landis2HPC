#!/usr/bin/env Rscript
# s46 Track K amended (post unblinding follow-on, not gate eligible): five draw spread, baseline recheck
# (v10 item 1 interval), 0.0025 flags (v9 K1), verdict stop (v9 K3, v7 K2), instability flags (v9 K3),
# stream F tests (v8 K3, v9 K2) and geometric mean check (v10 item 2). Writes aggregates only.
suppressPackageStartupMessages(library(data.table))
B <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015"; T <- file.path(B, "s46/cem_netdonor")
SUF <- "_postunblind_followon_not_gate_eligible"
ST6 <- c("ME","NH","VT","MI","WI","MN"); Q <- c("stock0","gross","mort","net")
rd <- function(f, draw) { x <- fread(f)[, .(state, quantity, ratio, pass)]; x[, draw := draw]; x }
g <- rbindlist(lapply(ST6, function(s) rbind(
  rd(file.path(B, "s43/cem_ablation/scores/reg", sprintf("cem_gate_%s_c00base_20261016e.csv", s)), "s43_c00base"),
  rd(file.path(B, "s45/cem_netdonor/scores/reg", sprintf("cem_gate_%s_k20ref%s_20261016e.csv", s, SUF)), "s45_k20ref"),
  rd(file.path(T, "scores/reg", sprintf("cem_gate_%s_u3%s_20261016e.csv", s, SUF)), "s46_u3"),
  rd(file.path(T, "scores/reg", sprintf("cem_gate_%s_u4%s_20261016e.csv", s, SUF)), "s46_u4"),
  rd(file.path(T, "scores/reg", sprintf("cem_gate_%s_u5%s_20261016e.csv", s, SUF)), "s46_u5"))))
fx <- rbindlist(lapply(ST6, function(s) rd(file.path(T, "scores/reg", sprintf("cem_gate_%s_f20a%s_20261016e.csv", s, SUF)), "s46_f20a_fixed")))
ps <- function(cfg) rbindlist(lapply(ST6, function(s) { x <- fread(file.path(T, "scores/persim", sprintf("persim_%s_%s%s.csv", s, cfg, SUF))); x[, cfg := cfg]; x }))
pr <- ps("k20ref"); pf <- ps("f20a")
ssim <- pr[, .(s_sim = sd(ratio), n_sim = .N), by = .(state, quantity)]
tq <- qt(1 - 0.025 / 24, 4)
sp <- g[, .(mean5 = mean(ratio), s_run = sd(ratio), min5 = min(ratio), max5 = max(ratio),
            maxabsdev5 = max(abs(ratio - mean(ratio))), n_pass5 = sum(pass), all_identical = uniqueN(ratio) == 1,
            r_s43 = ratio[draw == "s43_c00base"], pass_s43 = pass[draw == "s43_c00base"]), by = .(state, quantity)]
sp <- ssim[sp, on = .(state, quantity)]
sp <- fx[, .(state, quantity, fixed = ratio, pass_fixed = pass)][sp, on = .(state, quantity)]
sp[, half_width := tq * sqrt(s_run^2 * (1 + 1/5) + s_sim^2 / 20)]
sp[, inside := abs(fixed - mean5) <= half_width]
sp[half_width == 0, inside := fixed == mean5]
sp[, dist_mean := fixed - mean5]
sp[, flag_0025 := abs(dist_mean) > 0.0025]
sp[, drift_vs_s43 := fixed - r_s43]
# verdict change: fixed on the other side of a band edge from at least 4 of 5 draws (pass flag of the registered scorer)
sp[, n_other_side := fifelse(pass_fixed, 5L - n_pass5, n_pass5)]
sp[, verdict_changed := n_other_side >= 4]
edges <- function(q) if (q == "stock0") c(0.90, 1.10) else c(0.85, 1.15)
sp[, verdict_unstable := mapply(function(q, lo, hi) any(edges(q) >= lo - 0.0055 & edges(q) <= hi + 0.0055), quantity, min5, max5)]
sp[, within_0055_of_edge_fixed := mapply(function(q, r) any(abs(edges(q) - r) <= 0.0055), quantity, fixed)]
sp[, t_quantile := tq]
sp[, label := "post unblinding follow-on, not gate eligible"]
setcolorder(sp, c("label","state","quantity"))
fwrite(sp, file.path(T, "out", sprintf("recheck_s46%s.csv", SUF)))
# stream test: per cell F test on between sim variances, fixed f20a vs designated reference k20ref, df (19,19)
v <- merge(pf[, .(var_f = var(ratio), n_f = .N), by = .(state, quantity)], pr[, .(var_r = var(ratio), n_r = .N), by = .(state, quantity)], by = c("state","quantity"))
v <- v[quantity != "stock0"]
v[, Fratio := var_f / var_r]
v[, p_two := 2 * pmin(pf(Fratio, n_f - 1, n_r - 1), 1 - pf(Fratio, n_f - 1, n_r - 1))]
a <- 0.05 / 18
v[, reject := p_two < a]
gm <- v[, .(geo_mean_ratio = exp(mean(log(Fratio))), lo = 0.632, hi = 1.587), by = quantity][, inside := geo_mean_ratio >= lo & geo_mean_ratio <= hi]
# detectable variance ratio at 80 percent power for the per cell two sided test at alpha 0.05/18, df (19,19)
fl <- qf(a / 2, 19, 19); fh <- qf(1 - a / 2, 19, 19)
pow <- function(R) pf(fl / R, 19, 19) + 1 - pf(fh / R, 19, 19)
Rup <- uniroot(function(R) pow(R) - 0.8, c(1.01, 100))$root
Rdn <- uniroot(function(R) pow(R) - 0.8, c(0.01, 0.99))$root
v[, label := "post unblinding follow-on, not gate eligible"]
fwrite(v, file.path(T, "out", sprintf("stream_Ftest_s46%s.csv", SUF)))
fwrite(gm, file.path(T, "out", sprintf("stream_geomean_s46%s.csv", SUF)))
# check: mean of per sim ratios equals the gate ratio for k20ref
chk <- merge(pr[, .(m = mean(ratio)), by = .(state, quantity)], g[draw == "s45_k20ref", .(state, quantity, ratio)], by = c("state","quantity"))
cat(sprintf("persim mean vs gate ratio (k20ref) max abs diff %.3g\n", chk[, max(abs(m - ratio))]))
cat(sprintf("t quantile %.4f; F crit lo %.4f hi %.4f; detectable ratio at 80%% power: %.3f (up) %.3f (down)\n", tq, fl, fh, Rup, Rdn))
options(width = 250)
print(sp[, .(state, quantity, fixed = round(fixed, 4), mean5 = round(mean5, 4), s_run = signif(s_run, 3), s_sim = signif(s_sim, 3),
             half_width = signif(half_width, 3), dist = signif(dist_mean, 3), inside, flag_0025, min5 = round(min5, 4), max5 = round(max5, 4),
             maxabsdev5 = signif(maxabsdev5, 3), r_s43 = round(r_s43, 4), drift = signif(drift_vs_s43, 3), pass_fixed, n_pass5, verdict_changed, verdict_unstable)])
print(v[, .(state, quantity, var_f = signif(var_f, 3), var_r = signif(var_r, 3), Fratio = round(Fratio, 3), p_two = signif(p_two, 3), reject)])
print(gm)
cat(sprintf("RECHECK all inside: %s; any verdict changed: %s; any F reject: %s; geo mean all inside: %s\n",
            all(sp$inside), any(sp$verdict_changed), any(v$reject), all(gm$inside)))
