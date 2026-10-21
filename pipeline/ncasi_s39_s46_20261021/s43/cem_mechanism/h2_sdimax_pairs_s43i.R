#!/usr/bin/env Rscript
# Track I H2: among undisturbed remeasured FIA pairs (FVS gate pairs, s40:
# no TRTCD/DSTRBCD on t2 conditions, fully forested both visits) whose t1
# relative density exceeds the engine's own SDImax (engine_c E:755-786 and
# E:670-694: BRMS plot lookup by PLT_CN > state x FORTYPCD lookup > state
# default, each accepted only within [150, 800] English; SDI = TPA x (QMD/10)^1.605,
# live trees DIA >= 1 as 01_data_prep.R:163-175), share that gains AGB t1 to t2.
suppressPackageStartupMessages(library(data.table))
FIA <- path.expand("~/fia_data"); T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_mechanism"
E <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cem_ablation/engine_c"
P <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/fvs/work"
SC <- c(ME=23,NH=33,VT=50,MI=26,WI=55,MN=27)
bp <- fread(file.path(E, "config/sdimax_brms_plot.csv"), select = c("PLT_CN","sdimax_english_mean"), colClasses = list(character = "PLT_CN"))
bp <- bp[, .(sp = mean(sdimax_english_mean)), by = PLT_CN]
bf <- fread(file.path(E, "config/sdimax_brms_fortyp.csv"), select = c("STATECD","FORTYPCD","sdimax_english_mean")); setnames(bf, 3, "sf")
scst <- fread(file.path(E, "config/state_constants.csv"))
ok <- function(x) fifelse(!is.na(x) & x >= 150 & x <= 800, x, NA_real_)
out <- list()
for (st in names(SC)) {
  pr <- fread(file.path(P, sprintf("pairs_%s.csv", st)), colClasses = list(character = c("pair_id","t1_id")))
  tr <- fread(file.path(FIA, sprintf("%s_TREE.csv", st)), select = c("PLT_CN","STATUSCD","DIA","TPA_UNADJ"), colClasses = list(character = "PLT_CN"))
  tr <- tr[PLT_CN %chin% pr$t1_id & STATUSCD == 1 & DIA >= 1 & !is.na(TPA_UNADJ)]
  t1 <- tr[, .(tpa = sum(TPA_UNADJ), ba = sum(TPA_UNADJ * 0.005454 * DIA^2)), by = PLT_CN][, qmd := sqrt(ba / tpa / 0.005454)]
  pr <- t1[pr, on = c(PLT_CN = "t1_id")]
  pr[is.na(tpa), `:=`(tpa = 0, qmd = 0)]
  pr[, sdi := tpa * (qmd / 10)^1.605]
  pr <- bp[pr, on = "PLT_CN"]; setnames(pr, "sp", "sp_t1")
  pr <- bp[pr, on = c(PLT_CN = "pair_id")]; setnames(pr, "sp", "sp_t2")
  pr[, STATECD := SC[[st]]]
  pr <- bf[pr, on = c("STATECD","FORTYPCD")]
  dflt <- if (st %in% scst$state) scst[state == st, sdimax_default_english] else 440
  pr[, src := fifelse(!is.na(ok(sp_t1)), "plot_t1", fifelse(!is.na(ok(sp_t2)), "plot_t2", fifelse(!is.na(ok(sf)), "fortyp", "default")))]
  pr[, sdimax := fcoalesce(ok(sp_t1), ok(sp_t2), ok(sf), as.numeric(dflt))]
  pr[, rd := sdi / sdimax]
  pr[, gain := B2_Mgha > B1_Mgha]
  for (thr in c(1, 0.9, 0.8)) {
    x <- pr[rd > thr]
    k <- sum(x$gain); n <- nrow(x)
    ci <- if (n > 0) binom.test(k, n)$conf.int else c(NA, NA)
    out[[length(out) + 1]] <- data.table(state = st, rd_threshold = thr, n_pairs = nrow(pr), sdimax_default = dflt,
      share_src_plot = mean(pr$src %like% "plot"), share_src_fortyp = mean(pr$src == "fortyp"), share_src_default = mean(pr$src == "default"),
      n_over = n, share_over = n / nrow(pr), share_gain = if (n > 0) k / n else NA_real_, ci_lo = ci[1], ci_hi = ci[2],
      mean_net_Mghayr_over = if (n > 0) mean((x$B2_Mgha - x$B1_Mgha) / x$REMPER) else NA_real_,
      share_gain_all = mean(pr$gain), median_rd = median(pr$rd))
  }
}
res <- rbindlist(out)
res[rd_threshold == 1, H2 := fifelse(is.na(share_gain), "no pairs", fifelse(share_gain > 0.5, "supported", fifelse(share_gain < 0.25, "rejected", "inconclusive")))]
fwrite(res, file.path(T, "out", "h2_sdimax_pairs_s43i.csv"))
print(res[, .(state, rd_threshold, n_pairs, n_over, share_over = round(share_over, 4), share_gain = round(share_gain, 4), ci_lo = round(ci_lo, 3), ci_hi = round(ci_hi, 3), src_plot = round(share_src_plot, 3), src_def = round(share_src_default, 3), H2)])
