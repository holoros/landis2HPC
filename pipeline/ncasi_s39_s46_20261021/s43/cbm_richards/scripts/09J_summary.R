## s43 Track J summary tables (aggregates only). Also scores the session 43 free-A fit (fit_v2 even-half params, read only)
## on the same holdout dense bins 200-250, 250-300, >300 so the dense check is reported beside the three A variants.
## usage: Rscript 09J_summary.R OUTROOT S43FITDIR
suppressMessages({library(data.table); library(digest)})
a <- commandArgs(TRUE); OR <- a[1]; S43 <- a[2]
H <- rbindlist(lapply(c("p90", "p95", "p99"), function(v) fread(file.path(OR, paste0("fit_", v), "tb_holdout_state_class_DATA.csv"))))
## s43 dense bins: rebuild holdout data exactly as 01J/01b
Hm <- path.expand("~")
F <- list(ME = file.path(Hm, "maine_agb_yc_20261015/out_b/me_intervals_DATA.csv"), NHVT = file.path(Hm, "nhvt_agb_yc_20261016/out/me_intervals_DATA.csv"),
  MI = file.path(Hm, "lakes_agb_yc_20261016/out_MI/yc_intervals_DATA.csv"), WI = file.path(Hm, "lakes_agb_yc_20261016/out_WI/yc_intervals_DATA.csv"),
  MN = file.path(Hm, "lakes_agb_yc_20261016/out_MN/yc_intervals_DATA.csv"))
rd <- function(f, st = NULL) { d <- fread(f); if (!"st" %in% names(d)) d[, st := st]; d[, st := as.character(st)]; d }
D <- rbindlist(list(rd(F$ME, "ME"), rd(F$NHVT), rd(F$MI, "MI"), rd(F$WI, "WI"), rd(F$MN, "MN")), use.names = TRUE, fill = TRUE)
D <- D[hf == TRUE & consecutive == TRUE & ftg %in% c("SF", "MBB", "AB", "WRPH", "OAK", "EAC") & is.finite(AGB1) & is.finite(AGB2) & is.finite(dt) & dt > 0 & AGB1 >= 0]
D[, y := (AGB2 - AGB1) / dt][, pkey := paste0(st, ":", plot_ix)]
md5par <- function(k) vapply(k, function(s) strtoi(substr(digest(s, algo = "md5", serialize = FALSE), 32, 32), 16L) %% 2L, 1L)
U <- unique(D[, .(pkey)]); U[, half := ifelse(md5par(pkey) == 0L, "fit", "hold")]; D <- merge(D, U, by = "pkey")
P <- fread(file.path(S43, "tb_params_evenhalf_DATA.csv"))[ok == TRUE, .(st, ftg, a, b, c)]  # a already includes the VT state effect
Dh <- merge(D[half == "hold" & AGB1 >= 200], P, by = c("st", "ftg"))
Dh[, pred := a * AGB1^b - c * AGB1][, cls := as.character(cut(AGB1, c(200, 250, 300, Inf), right = FALSE, labels = c("d200-250", "d250-300", "d300+")))]
tol <- unique(H[, .(st, tol)])
S3 <- Dh[, .(n = .N, obs = mean(y), pred = mean(pred)), by = .(st, cls)][tol, on = "st", nomatch = 0][, absdiff := abs(pred - obs)][, pass := absdiff <= tol][, `:=`(variant = "s43free", set = "dense bins")]
s43c <- fread(file.path(S43, "tb_holdout_state_class_DATA.csv"))[, `:=`(variant = "s43free", set = "s43 classes", cls = as.character(cls))]
ALLH <- rbind(H, S3, s43c, fill = TRUE)
fwrite(ALLH, file.path(OR, "tbJ_holdout_all_variants_DATA.csv"))
T1 <- ALLH[, .(pass = sum(pass), cells = .N), by = .(variant, set, st)]
T1w <- dcast(T1, st ~ variant + set, value.var = "pass"); fwrite(T1w, file.path(OR, "tbJ_holdout_pass_by_state_DATA.csv"))
T2 <- ALLH[, .(pass = sum(pass), cells = .N), by = .(variant, set)]; fwrite(T2, file.path(OR, "tbJ_holdout_pass_totals_DATA.csv"))
DB <- ALLH[set == "dense bins", .(variant, st, cls, n, obs = round(obs, 2), pred = round(pred, 2), tol = round(tol, 2), pass)]
fwrite(DB, file.path(OR, "tbJ_dense_bins_DATA.csv"))
## realism
R <- rbindlist(lapply(c("p90", "p95", "p99"), function(v) fread(file.path(OR, paste0("fit_", v), "tb_realism_type_DATA.csv"))), fill = TRUE)
O <- rbindlist(lapply(c("p90", "p95", "p99"), function(v) fread(file.path(OR, paste0("fit_", v), "tb_realism_order_DATA.csv"))), fill = TRUE)
R3 <- fread(file.path(S43, "tb_realism_type_DATA.csv")); O3 <- fread(file.path(S43, "tb_realism_order_DATA.csv"))
RS <- rbind(R[, .(types = .N, monotone = sum(monotone_0_300), theta_lower_gompertz = sum(theta_at_lower_gompertz), theta_upper = sum(theta > 49.9),
                  median_age99 = median(age99), max_rk4_rel = max(rk4_maxrel_5_300), median_B100_over_A = median(B100 / A)), by = variant],
            R3[, .(variant = "s43free", types = .N, monotone = sum(monotone), theta_lower_gompertz = NA_integer_, theta_upper = NA_integer_,
                  median_age99 = median(age99), max_rk4_rel = max(rk4_maxrel), median_B100_over_A = median(B100 / Bstar))])
OS <- rbind(O[, .(states = .N, order_eq_identical = sum(order_A_identical), order_B100_identical = sum(order_B100_identical), disc_pairs_eq = sum(disc_A_vs_FIAmean), disc_pairs_B100 = sum(disc_B100_vs_FIAmean), pairs = sum(pairs)), by = variant],
            O3[, .(variant = "s43free", states = .N, order_eq_identical = sum(order_identical), order_B100_identical = NA_integer_, disc_pairs_eq = sum(discordant_pairs), disc_pairs_B100 = NA_integer_, pairs = sum(pairs))])
RS <- merge(RS, OS, by = "variant"); fwrite(RS, file.path(OR, "tbJ_realism_summary_DATA.csv"))
options(width = 200)
print(T2[order(set, variant)]); print(T1w); print(DB[variant %in% c("p99", "s43free")]); print(RS)
cat("done 09J\n")
