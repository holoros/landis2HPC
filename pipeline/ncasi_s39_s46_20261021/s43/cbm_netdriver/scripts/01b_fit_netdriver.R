## s43 Track B: CBM net increment driver. Fit (AGB2-AGB1)/dt = a*B^b - c*B (0<b<1) by forest type group.
## Holdout by md5(plot key) mod 2 (even fit, odd holdout); class check vs 15% of state FIA mean net growth per ha;
## leave-one-state-out on pooled fits; refit on all plots; closed form B(t); 50 yr realism checks.
## usage: Rscript 01_fit_netdriver.R OUTDIR ; aggregates only are written (no plot keys).
suppressMessages({library(data.table); library(digest)})
set.seed(20261019)
OD <- commandArgs(TRUE)[1]; dir.create(OD, showWarnings = FALSE, recursive = TRUE)
H <- path.expand("~")
F <- list(ME = file.path(H, "maine_agb_yc_20261015/out_b/me_intervals_DATA.csv"),
          NHVT = file.path(H, "nhvt_agb_yc_20261016/out/me_intervals_DATA.csv"),
          MI = file.path(H, "lakes_agb_yc_20261016/out_MI/yc_intervals_DATA.csv"),
          WI = file.path(H, "lakes_agb_yc_20261016/out_WI/yc_intervals_DATA.csv"),
          MN = file.path(H, "lakes_agb_yc_20261016/out_MN/yc_intervals_DATA.csv"))
for (f in F) cat("md5", tools::md5sum(f), f, "\n")
rd <- function(f, st = NULL) { d <- fread(f); if (!"st" %in% names(d)) d[, st := st]; d[, st := as.character(st)]; d }
D <- rbindlist(list(rd(F$ME, "ME"), rd(F$NHVT), rd(F$MI, "MI"), rd(F$WI, "WI"), rd(F$MN, "MN")), use.names = TRUE, fill = TRUE)
cat("states in NHVT file:", paste(unique(rd(F$NHVT)$st), collapse = " "), "\n")
FT <- c("SF", "MBB", "AB", "WRPH", "OAK", "EAC")
D <- D[hf == TRUE & consecutive == TRUE & ftg %in% FT & is.finite(AGB1) & is.finite(AGB2) & is.finite(dt) & dt > 0 & AGB1 >= 0]
D[, y := (AGB2 - AGB1) / dt]
D[, pkey := paste0(st, ":", plot_ix)]
md5par <- function(k) vapply(k, function(s) strtoi(substr(digest(s, algo = "md5", serialize = FALSE), 32, 32), 16L) %% 2L, 1L)
U <- unique(D[, .(pkey)]); U[, half := ifelse(md5par(pkey) == 0L, "fit", "hold")]
D <- merge(D, U, by = "pkey")
cat(sprintf("intervals %d plots %d; fit plots %d hold plots %d\n", nrow(D), nrow(U), U[half == "fit", .N], U[half == "hold", .N]))
fwrite(D[, .(n_int = .N, n_plot = uniqueN(pkey), n_fit_plot = uniqueN(pkey[half == "fit"]), mean_dt = mean(dt), mean_AGB1 = mean(AGB1), mean_y = mean(y)), by = .(st, ftg)][order(st, ftg)],
       file.path(OD, "tb_data_counts_DATA.csv"))

## FIA mean net growth per ha (EVALIDator, Tg/yr and ha from the brief)
FIA <- data.table(st = c("NH", "VT", "MI", "WI", "ME", "MN"), net_Tg = c(5.470, 4.623, 18.729, 18.914, 16.1185, 14.4688),
                  area_ha = c(1910089, 1792058, 7790021, 6723136, 7002925, 7076703))
FIA[, net_Mgha := net_Tg * 1e6 / area_ha][, tol := 0.15 * net_Mgha]

## fitting: profile b on a grid with linear LS for (a, c), then nls port with bounds
fit1 <- function(d, vt = FALSE) {
  B <- d$AGB1; y <- d$y; z <- if (vt) as.numeric(d$st == "VT") else rep(0, nrow(d))
  best <- NULL
  for (b in seq(0.05, 0.95, 0.05)) {
    X <- cbind(B^b, -B, if (vt) z * B^b); cf <- qr.coef(qr(X), y); r <- sum((y - X %*% cf)^2)
    if (is.null(best) || r < best$r) best <- list(r = r, b = b, cf = cf)
  }
  a0 <- max(best$cf[1], 1e-3); c0 <- max(best$cf[2], 1e-4); d0 <- if (vt) best$cf[3] / a0 else 0
  dd <- data.frame(B = B, y = y, z = z)
  f <- if (vt) y ~ a * exp(dv * z) * B^b - c * B else y ~ a * B^b - c * B
  st <- if (vt) list(a = a0, b = best$b, c = c0, dv = max(min(d0, 1), -1)) else list(a = a0, b = best$b, c = c0)
  lo <- if (vt) c(a = 1e-6, b = 0.01, c = 1e-7, dv = -3) else c(a = 1e-6, b = 0.01, c = 1e-7)
  up <- if (vt) c(a = 1e3, b = 0.99, c = 1, dv = 3) else c(a = 1e3, b = 0.99, c = 1)
  m <- tryCatch(nls(f, dd, start = st, algorithm = "port", lower = lo, upper = up, control = nls.control(maxiter = 500)), error = function(e) e)
  if (inherits(m, "error")) return(list(ok = FALSE, msg = conditionMessage(m), grid = best))
  list(ok = TRUE, m = m, n = nrow(d), np = uniqueN(d$pkey))
}
bstar <- function(a, b, c) (a / c)^(1 / (1 - b))
Bt <- function(t, a, b, c) bstar(a, b, c) * (1 - exp(-(1 - b) * c * t))^(1 / (1 - b))   # closed form from B(0)=0
age99 <- function(b, c) -log(1 - 0.99^(1 - b)) / ((1 - b) * c)

## fit units: (state set, type, fit-data states, state effect, apply-to states, basis)
UNITS <- rbindlist(list(
  CJ(unit = "ME", ftg = FT)[, `:=`(data_st = "ME", vt = FALSE, apply_st = "ME", basis = "state fit")],
  CJ(unit = "MI", ftg = FT)[, `:=`(data_st = "MI", vt = FALSE, apply_st = "MI", basis = "state fit")],
  CJ(unit = "WI", ftg = FT)[, `:=`(data_st = "WI", vt = FALSE, apply_st = "WI", basis = "state fit")],
  CJ(unit = "MN", ftg = c("SF", "AB", "WRPH", "EAC"))[, `:=`(data_st = "MN", vt = FALSE, apply_st = "MN", basis = "state fit")],
  CJ(unit = "LSPOOL", ftg = c("MBB", "OAK"))[, `:=`(data_st = "MI,WI,MN", vt = FALSE, apply_st = "MN", basis = "Lake States pooled (s42 handling)")],
  CJ(unit = "NHVT", ftg = c("SF", "MBB", "AB", "WRPH", "OAK"))[, `:=`(data_st = "NH,VT", vt = TRUE, apply_st = "NH,VT", basis = "NH+VT pooled, state effect on a")]))

par_rows <- function(u, fr, tag) {
  if (!fr$ok) return(data.table(unit = u$unit, ftg = u$ftg, fit = tag, ok = FALSE, msg = fr$msg))
  s <- summary(fr$m)$coefficients; cf <- coef(fr$m); V <- vcov(fr$m)
  out <- list()
  sts <- strsplit(u$apply_st, ",")[[1]]
  for (S in sts) {
    a <- cf["a"] * if (u$vt && S == "VT") exp(cf["dv"]) else 1
    g <- function(p) { aa <- p["a"] * if (u$vt && S == "VT") exp(p["dv"]) else 1; bstar(aa, p["b"], p["c"]) }
    gr <- sapply(names(cf), function(k) { h <- 1e-6 * max(abs(cf[k]), 1e-6); p1 <- cf; p1[k] <- p1[k] + h; p0 <- cf; p0[k] <- p0[k] - h; (g(p1) - g(p0)) / (2 * h) })
    out[[S]] <- data.table(unit = u$unit, ftg = u$ftg, st = S, fit = tag, ok = TRUE, basis = u$basis, n_int = fr$n, n_plot = fr$np,
      a = unname(a), a_se_base = s["a", 2], b = cf["b"], b_se = s["b", 2], c = cf["c"], c_se = s["c", 2],
      dv_VT = if (u$vt) cf["dv"] else NA_real_, dv_se = if (u$vt) s["dv", 2] else NA_real_,
      Bstar = unname(bstar(a, cf["b"], cf["c"])), Bstar_se = sqrt(drop(t(gr) %*% V %*% gr)),
      age99 = unname(age99(cf["b"], cf["c"])), b_at_bound = cf["b"] > 0.985 | cf["b"] < 0.015, rse = summary(fr$m)$sigma)
  }
  rbindlist(out)
}
predfun <- function(u, fr) { cf <- coef(fr$m); function(d) { a <- cf["a"] * if (u$vt) exp(cf["dv"] * (d$st == "VT")) else 1; a * d$AGB1^cf["b"] - cf["c"] * d$AGB1 } }

CL <- function(B) cut(B, c(-Inf, 50, 100, 150, 200, Inf), right = FALSE, labels = c("0-50", "50-100", "100-150", "150-200", "200+"))
P_half <- list(); P_all <- list(); H_rows <- list(); fits_all <- list()
for (k in seq_len(nrow(UNITS))) {
  u <- UNITS[k]; s <- strsplit(u$data_st, ",")[[1]]
  if (u$vt && !fit1(D[st %in% s & ftg == u$ftg], TRUE)$ok) { u[, vt := FALSE]; u[, basis := "NH+VT pooled, NO state effect (state-effect nls failed)"]; cat("fallback no state effect:", u$ftg, "\n") }
  dfit <- D[st %in% s & ftg == u$ftg & half == "fit"]; dhold <- D[st %in% s & ftg == u$ftg & half == "hold"]
  fr <- fit1(dfit, u$vt); P_half[[k]] <- par_rows(u, fr, "even_half")
  if (fr$ok) { ap <- strsplit(u$apply_st, ",")[[1]]; dh <- dhold[st %in% ap]; dh[, pred := predfun(u, fr)(dh)]; H_rows[[k]] <- dh[, .(st, ftg, AGB1, y, pred)] }
  fa <- fit1(D[st %in% s & ftg == u$ftg], u$vt); P_all[[k]] <- par_rows(u, fa, "all_plots"); fits_all[[k]] <- list(u = u, fr = fa)
}
PH <- rbindlist(P_half, fill = TRUE); PA <- rbindlist(P_all, fill = TRUE)
fwrite(PH, file.path(OD, "tb_params_evenhalf_DATA.csv")); fwrite(PA, file.path(OD, "tb_params_allplots_DATA.csv"))

## holdout by class (gate: state x class, all types); diagnostic: state x type x class
HR <- rbindlist(H_rows); HR[, cls := CL(AGB1)]
HS <- HR[, .(n = .N, obs = mean(y), pred = mean(pred)), by = .(st, cls)][FIA[, .(st, net_Mgha, tol)], on = "st"]
HS[, absdiff := abs(pred - obs)][, pass := absdiff <= tol]
setorder(HS, st, cls); fwrite(HS, file.path(OD, "tb_holdout_state_class_DATA.csv"))
HT <- HR[, .(n = .N, obs = mean(y), pred = mean(pred)), by = .(st, ftg, cls)][FIA[, .(st, tol)], on = "st"]
HT[, absdiff := abs(pred - obs)][, pass := absdiff <= tol]; setorder(HT, st, ftg, cls)
fwrite(HT, file.path(OD, "tb_holdout_type_class_DATA.csv"))

## leave-one-state-out on pooled fits: fit on the other state(s) (fit half, no state effect), predict left-out state's hold half
LO <- list()
for (u in list(list(unit = "LSPOOL", st = c("MI", "WI", "MN"), ft = c("MBB", "OAK")), list(unit = "NHVT", st = c("NH", "VT"), ft = c("SF", "MBB", "AB", "WRPH", "OAK")))) {
  for (L in u$st) for (g in u$ft) {
    fr <- fit1(D[st %in% setdiff(u$st, L) & ftg == g & half == "fit"], FALSE)
    if (!fr$ok) { LO[[length(LO) + 1]] <- data.table(unit = u$unit, left_out = L, ftg = g, ok = FALSE); next }
    cf <- coef(fr$m); dh <- D[st == L & ftg == g & half == "hold"]; dh[, pred := cf["a"] * AGB1^cf["b"] - cf["c"] * AGB1]
    LO[[length(LO) + 1]] <- dh[, .(n = .N, obs = mean(y), pred = mean(pred)), by = .(cls = CL(AGB1))][, `:=`(unit = u$unit, left_out = L, ftg = g, ok = TRUE)]
  }
}
LO <- rbindlist(LO, fill = TRUE)[FIA[, .(left_out = st, tol)], on = "left_out", nomatch = 0]
LO[, absdiff := abs(pred - obs)][, pass := absdiff <= tol]; setorder(LO, unit, left_out, ftg, cls)
fwrite(LO, file.path(OD, "tb_loso_DATA.csv"))

## curves 0..300 from all-plot fits, per state x type; NH/VT oak: s42 held oak at the type cap (99th pct AGB) -> held at cap if B(t) exceeds it
Q <- D[, .(p99_AGB2 = quantile(AGB2, 0.99), mean_AGB2 = mean(AGB2), p95_AGB2 = quantile(AGB2, 0.95), n = .N), by = .(st, ftg)]
fwrite(Q, file.path(OD, "tb_fia_type_quantiles_DATA.csv"))
CV <- list()
for (r in seq_len(nrow(PA))) { p <- PA[r]; if (!isTRUE(p$ok)) next
  t <- 0:300; B <- Bt(t, p$a, p$b, p$c)
  ## numerical check: RK4 from B(1) closed form
  Bn <- numeric(301); Bn[1:2] <- B[1:2]; f <- function(x) p$a * max(x, 0)^p$b - p$c * x
  for (i in 2:300) { x <- Bn[i]; k1 <- f(x); k2 <- f(x + k1 / 2); k3 <- f(x + k2 / 2); k4 <- f(x + k3); Bn[i + 1] <- x + (k1 + 2 * k2 + 2 * k3 + k4) / 6 }
  cap <- Q[st == p$st & ftg == p$ftg]$p99_AGB2
  hold <- p$unit == "NHVT" && p$ftg == "OAK"
  CV[[r]] <- data.table(st = p$st, ftg = p$ftg, age = t, B = B, B_rk4 = Bn, dBdt = p$a * B^p$b - p$c * B,
    B_driver = if (hold) pmin(B, cap) else B, held_at_cap = hold & B > cap, Bstar = p$Bstar, age99 = p$age99, cap_p99 = cap)
}
CV <- rbindlist(CV); fwrite(CV, file.path(OD, "tb_curves_0_300_DATA.csv"))

## realism: B* < p99; monotone; ordering of B* vs FIA type mean AGB2 within state
R1 <- merge(PA[ok == TRUE, .(st, ftg, unit, Bstar, Bstar_se, age99)], Q, by = c("st", "ftg"))
R1[, Bstar_below_p99 := Bstar < p99_AGB2]
MON <- CV[, .(monotone = all(diff(B) >= -1e-9), rk4_maxrel = max(abs(B_rk4 - B)[age >= 5] / pmax(B[age >= 5], 1e-9)), B50 = B[age == 50], B100 = B[age == 100]), by = .(st, ftg)]
R1 <- merge(R1, MON, by = c("st", "ftg"))
ORD <- R1[, { o <- cor(Bstar, mean_AGB2, method = "kendall"); pr <- combn(.N, 2); disc <- sum(sign(Bstar[pr[1, ]] - Bstar[pr[2, ]]) != sign(mean_AGB2[pr[1, ]] - mean_AGB2[pr[2, ]]))
  .(n_types = .N, kendall_tau = o, discordant_pairs = disc, pairs = ncol(pr), order_identical = disc == 0,
    order_Bstar = paste(ftg[order(-Bstar)], collapse = ">"), order_FIA_mean = paste(ftg[order(-mean_AGB2)], collapse = ">"),
    order_FIA_p95 = paste(ftg[order(-p95_AGB2)], collapse = ">")) }, by = st]
fwrite(R1, file.path(OD, "tb_realism_type_DATA.csv")); fwrite(ORD, file.path(OD, "tb_realism_order_DATA.csv"))
saveRDS(lapply(fits_all, function(x) list(u = x$u, coef = if (x$fr$ok) coef(x$fr$m), vcov = if (x$fr$ok) vcov(x$fr$m))), file.path(OD, "tb_fits_allplots.rds"))
print(HS[, .(st, cls, n, obs = round(obs, 3), pred = round(pred, 3), tol = round(tol, 3), pass)])
print(PA[, .(st, ftg, b = round(b, 3), Bstar = round(Bstar, 1), se = round(Bstar_se, 1), age99 = round(age99))])
cat("done 01\n")
