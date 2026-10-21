## s43 Track J: CBM growth driver dB/dt = r*B*(1-(B/A)^theta), r>0, theta>0, A fixed at the FIA p90/p95/p99 of AGB2 by state x type.
## Data, filters, fit units (pooling), md5 plot split and state FIA tolerance copied from s43 Track B 01b_fit_netdriver.R (md5 bb6d5ef0...).
## Fit target y = (AGB2-AGB1)/dt against f(AGB1) as in 01b. B0 at age 5 = mean AGB1 of hf consecutive intervals with STDAGE1 <= 10
## by state x type, pooled over all six states by type if fewer than 30 such intervals (level recorded).
## usage: Rscript 01J_fit_richards.R OUTROOT ; aggregates only written (no plot keys).
suppressMessages({library(data.table); library(digest)})
set.seed(20261019); cat("seed 20261019\n")
OR <- commandArgs(TRUE)[1]; dir.create(OR, showWarnings = FALSE, recursive = TRUE)
H <- path.expand("~")
F <- list(ME = file.path(H, "maine_agb_yc_20261015/out_b/me_intervals_DATA.csv"),
          NHVT = file.path(H, "nhvt_agb_yc_20261016/out/me_intervals_DATA.csv"),
          MI = file.path(H, "lakes_agb_yc_20261016/out_MI/yc_intervals_DATA.csv"),
          WI = file.path(H, "lakes_agb_yc_20261016/out_WI/yc_intervals_DATA.csv"),
          MN = file.path(H, "lakes_agb_yc_20261016/out_MN/yc_intervals_DATA.csv"))
for (f in F) cat("md5", tools::md5sum(f), f, "\n")
rd <- function(f, st = NULL) { d <- fread(f); if (!"st" %in% names(d)) d[, st := st]; d[, st := as.character(st)]; d }
D <- rbindlist(list(rd(F$ME, "ME"), rd(F$NHVT), rd(F$MI, "MI"), rd(F$WI, "WI"), rd(F$MN, "MN")), use.names = TRUE, fill = TRUE)
stopifnot("STDAGE1" %in% names(D))
FT <- c("SF", "MBB", "AB", "WRPH", "OAK", "EAC")
D <- D[hf == TRUE & consecutive == TRUE & ftg %in% FT & is.finite(AGB1) & is.finite(AGB2) & is.finite(dt) & dt > 0 & AGB1 >= 0]
D[, y := (AGB2 - AGB1) / dt]
D[, pkey := paste0(st, ":", plot_ix)]
md5par <- function(k) vapply(k, function(s) strtoi(substr(digest(s, algo = "md5", serialize = FALSE), 32, 32), 16L) %% 2L, 1L)
U <- unique(D[, .(pkey)]); U[, half := ifelse(md5par(pkey) == 0L, "fit", "hold")]
D <- merge(D, U, by = "pkey")
cat(sprintf("intervals %d plots %d; fit plots %d hold plots %d\n", nrow(D), nrow(U), U[half == "fit", .N], U[half == "hold", .N]))
FIA <- data.table(st = c("NH", "VT", "MI", "WI", "ME", "MN"), net_Tg = c(5.470, 4.623, 18.729, 18.914, 16.1185, 14.4688),
                  area_ha = c(1910089, 1792058, 7790021, 6723136, 7002925, 7076703))
FIA[, net_Mgha := net_Tg * 1e6 / area_ha][, tol := 0.15 * net_Mgha]

## A quantiles (all hf consecutive intervals, AGB2, by state x type; same basis as 01b tb_fia_type_quantiles)
Q <- D[, .(n = .N, mean_AGB2 = mean(AGB2), p90 = quantile(AGB2, 0.90), p95 = quantile(AGB2, 0.95), p99 = quantile(AGB2, 0.99)), by = .(st, ftg)]
## B0 at age 5
Y <- D[is.finite(STDAGE1) & STDAGE1 <= 10]
B0s <- Y[, .(n_young = .N, B0_state = mean(AGB1)), by = .(st, ftg)]
B0p <- Y[, .(n_young_pool = .N, B0_pool = mean(AGB1)), by = ftg]
B0 <- merge(merge(Q[, .(st, ftg)], B0s, by = c("st", "ftg"), all.x = TRUE), B0p, by = "ftg", all.x = TRUE)
B0[is.na(n_young), n_young := 0L]
B0[, `:=`(B0 = ifelse(n_young >= 30, B0_state, B0_pool), B0_level = ifelse(n_young >= 30, "state x type", "six-state pool by type (n<30)"))]
Q <- merge(Q, B0, by = c("st", "ftg"))
fwrite(Q, file.path(OR, "tbJ_A_B0_by_state_type_DATA.csv"))
print(Q[, .(st, ftg, n, p90 = round(p90), p95 = round(p95), p99 = round(p99), n_young, B0 = round(B0, 1), lvl = substr(B0_level, 1, 5))])

UNITS <- rbindlist(list(
  CJ(unit = "ME", ftg = FT)[, `:=`(data_st = "ME", vt = FALSE, apply_st = "ME", basis = "state fit")],
  CJ(unit = "MI", ftg = FT)[, `:=`(data_st = "MI", vt = FALSE, apply_st = "MI", basis = "state fit")],
  CJ(unit = "WI", ftg = FT)[, `:=`(data_st = "WI", vt = FALSE, apply_st = "WI", basis = "state fit")],
  CJ(unit = "MN", ftg = c("SF", "AB", "WRPH", "EAC"))[, `:=`(data_st = "MN", vt = FALSE, apply_st = "MN", basis = "state fit")],
  CJ(unit = "LSPOOL", ftg = c("MBB", "OAK"))[, `:=`(data_st = "MI,WI,MN", vt = FALSE, apply_st = "MN", basis = "Lake States pooled (s42 handling)")],
  CJ(unit = "NHVT", ftg = c("SF", "MBB", "AB", "WRPH", "OAK"))[, `:=`(data_st = "NH,VT", vt = TRUE, apply_st = "NH,VT", basis = "NH+VT pooled, state effect on r")]))

## model: y = r*exp(dv*z)*B*(1-(B/A)^th); A per row (row's own state x type quantile)
xf <- function(B, A, th) B * (1 - (B / A)^th)
fitJ <- function(d, vt) {
  B <- d$AGB1; y <- d$y; A <- d$A; z <- if (vt) as.numeric(d$st == "VT") else rep(0, nrow(d))
  prof <- function(lth) { th <- exp(lth); x <- xf(B, A, th)
    if (!vt) { r <- sum(x * y) / sum(x * x); return(list(rss = sum((y - r * x)^2), r = r, dv = 0)) }
    X <- cbind(x * (1 - z), x * z); cf <- qr.coef(qr(X), y); if (any(!is.finite(cf)) || any(cf <= 0)) return(list(rss = Inf))
    list(rss = sum((y - X %*% cf)^2), r = cf[1], dv = log(cf[2] / cf[1])) }
  g <- seq(log(1e-3), log(50), length.out = 120); rs <- sapply(g, function(l) prof(l)$rss)
  if (all(!is.finite(rs))) return(list(ok = FALSE, msg = "profile failed"))
  o <- optimize(function(l) prof(l)$rss, interval = range(g[max(1, which.min(rs) - 2):min(120, which.min(rs) + 2)]))
  p <- prof(o$minimum); th0 <- exp(o$minimum)
  dd <- data.frame(B = B, y = y, z = z, A = A)
  f <- if (vt) y ~ r * exp(dv * z) * B * (1 - (B / A)^th) else y ~ r * B * (1 - (B / A)^th)
  st <- if (vt) list(r = max(p$r, 1e-5), th = th0, dv = p$dv) else list(r = max(p$r, 1e-5), th = th0)
  lo <- if (vt) c(r = 1e-6, th = 1e-3, dv = -3) else c(r = 1e-6, th = 1e-3)
  up <- if (vt) c(r = 5, th = 50, dv = 3) else c(r = 5, th = 50)
  m <- tryCatch(nls(f, dd, start = st, algorithm = "port", lower = lo, upper = up, control = nls.control(maxiter = 500)), error = function(e) e)
  if (inherits(m, "error")) {  # keep profile optimum, no SEs
    if (!is.finite(p$rss) || p$r <= 0) return(list(ok = FALSE, msg = conditionMessage(m)))
    return(list(ok = TRUE, nls = FALSE, cf = c(r = unname(p$r), th = th0, dv = if (vt) unname(p$dv) else NA), se = c(r = NA, th = NA, dv = NA), n = nrow(d), np = uniqueN(d$pkey), rse = sqrt(p$rss / (nrow(d) - 2 - vt))))
  }
  s <- summary(m)$coefficients; cf <- coef(m)
  list(ok = TRUE, nls = TRUE, cf = c(r = unname(cf["r"]), th = unname(cf["th"]), dv = if (vt) unname(cf["dv"]) else NA),
       se = c(r = s["r", 2], th = s["th", 2], dv = if (vt) s["dv", 2] else NA), n = nrow(d), np = uniqueN(d$pkey), rse = summary(m)$sigma)
}
## closed form from B0 at age 5 and age at 0.99 A
Bt <- function(t, r, th, A, B0) { K <- (A / B0)^th - 1; A * (1 + K * exp(-r * th * (t - 5)))^(-1 / th) }
age99 <- function(r, th, A, B0) { K <- (A / B0)^th - 1; if (K <= 0) return(NA_real_); 5 + log(K / (0.99^(-th) - 1)) / (r * th) }
CLs <- function(B) as.character(cut(B, c(-Inf, 50, 100, 150, 200, Inf), right = FALSE, labels = c("0-50", "50-100", "100-150", "150-200", "200+")))
CLd <- function(B) as.character(cut(B, c(200, 250, 300, Inf), right = FALSE, labels = c("d200-250", "d250-300", "d300+")))

for (V in c("p90", "p95", "p99")) {
  OD <- file.path(OR, paste0("fit_", V)); dir.create(OD, showWarnings = FALSE)
  D[Q, A := get(paste0("i.", V)), on = .(st, ftg)]
  PH <- list(); PA <- list(); HR <- list()
  for (k in seq_len(nrow(UNITS))) {
    u <- copy(UNITS[k]); s <- strsplit(u$data_st, ",")[[1]]
    if (u$vt && !fitJ(D[st %in% s & ftg == u$ftg], TRUE)$ok) { u[, vt := FALSE]; u[, basis := "NH+VT pooled, NO state effect (state-effect fit failed)"] }
    for (tag in c("even_half", "all_plots")) {
      d <- if (tag == "even_half") D[st %in% s & ftg == u$ftg & half == "fit"] else D[st %in% s & ftg == u$ftg]
      fr <- fitJ(d, u$vt)
      for (S in strsplit(u$apply_st, ",")[[1]]) {
        q <- Q[st == S & ftg == u$ftg]
        row <- data.table(variant = V, unit = u$unit, ftg = u$ftg, st = S, fit = tag, basis = u$basis, ok = fr$ok, A = q[[V]], B0 = q$B0, B0_level = q$B0_level)
        if (fr$ok) { rr <- fr$cf["r"] * if (u$vt && S == "VT") exp(fr$cf["dv"]) else 1
          row[, `:=`(nls_ok = fr$nls, n_int = fr$n, n_plot = fr$np, r = unname(rr), r_se_base = unname(fr$se["r"]), theta = unname(fr$cf["th"]), theta_se = unname(fr$se["th"]),
                     dv_VT = unname(fr$cf["dv"]), theta_at_bound = fr$cf["th"] < 1.01e-3 | fr$cf["th"] > 49.9, r_at_bound = fr$cf["r"] > 4.99 | fr$cf["r"] < 1.01e-6,
                     age99 = age99(unname(rr), unname(fr$cf["th"]), q[[V]], q$B0), rse = fr$rse, B0_ge_A = q$B0 >= q[[V]])] }
        if (tag == "even_half") PH[[length(PH) + 1]] <- row else PA[[length(PA) + 1]] <- row
        if (tag == "even_half" && fr$ok) {
          dh <- D[st == S & ftg == u$ftg & half == "hold"]
          rr <- fr$cf["r"] * if (u$vt && S == "VT") exp(fr$cf["dv"]) else 1
          dh[, pred := rr * xf(AGB1, A, fr$cf["th"])]; HR[[length(HR) + 1]] <- dh[, .(st, ftg, AGB1, y, pred)]
        }
      }
    }
  }
  PH <- rbindlist(PH, fill = TRUE); PA <- rbindlist(PA, fill = TRUE)
  fwrite(PH, file.path(OD, "tb_params_evenhalf_DATA.csv")); fwrite(PA, file.path(OD, "tb_params_allplots_DATA.csv"))
  HR <- rbindlist(HR)
  H1 <- HR[, .(n = .N, obs = mean(y), pred = mean(pred)), by = .(st, cls = CLs(AGB1))]
  H2 <- HR[AGB1 >= 200, .(n = .N, obs = mean(y), pred = mean(pred)), by = .(st, cls = CLd(AGB1))]
  HS <- rbind(H1[, set := "s43 classes"], H2[, set := "dense bins"])[FIA[, .(st, net_Mgha, tol)], on = "st"]
  HS[, absdiff := abs(pred - obs)][, pass := absdiff <= tol][, variant := V]
  setorder(HS, set, st, cls); fwrite(HS, file.path(OD, "tb_holdout_state_class_DATA.csv"))
  HT <- HR[, .(n = .N, obs = mean(y), pred = mean(pred)), by = .(st, ftg, cls = CLs(AGB1))][FIA[, .(st, tol)], on = "st"]
  HT[, absdiff := abs(pred - obs)][, pass := absdiff <= tol]; fwrite(HT, file.path(OD, "tb_holdout_type_class_DATA.csv"))
  ## curves 0..300 (closed form) with RK4 check from age 5
  CV <- list()
  for (i in seq_len(nrow(PA))) { p <- PA[i]; if (!isTRUE(p$ok)) next
    t <- 0:300; B <- Bt(t, p$r, p$theta, p$A, p$B0)
    f <- function(x) p$r * x * (1 - (max(x, 0) / p$A)^p$theta)
    Bn <- rep(NA_real_, 301); Bn[6] <- p$B0
    for (j in 6:300) { x <- Bn[j]; k1 <- f(x); k2 <- f(x + k1 / 2); k3 <- f(x + k2 / 2); k4 <- f(x + k3); Bn[j + 1] <- x + (k1 + 2 * k2 + 2 * k3 + k4) / 6 }
    CV[[i]] <- data.table(variant = V, st = p$st, ftg = p$ftg, age = t, B = B, B_rk4 = Bn, dBdt = p$r * B * (1 - (B / p$A)^p$theta),
      B_driver = ifelse(t == 0, 0, B), held_at_cap = FALSE, A = p$A, B0 = p$B0, age99 = p$age99, cap_p99 = Q[st == p$st & ftg == p$ftg]$p99)
  }
  CV <- rbindlist(CV); fwrite(CV, file.path(OD, "tb_curves_0_300_DATA.csv"))
  R1 <- merge(PA[ok == TRUE, .(st, ftg, unit, A, B0, B0_level, r, theta, theta_at_bound, age99, B0_ge_A)], Q[, .(st, ftg, mean_AGB2, p95, p99)], by = c("st", "ftg"))
  MON <- CV[, .(monotone_0_300 = all(diff(B_driver) >= -1e-9), rk4_maxrel_5_300 = max(abs(B_rk4 - B)[age >= 5] / pmax(B[age >= 5], 1e-9)),
               B20 = B[age == 20], B50 = B[age == 50], B100 = B[age == 100], B200 = B[age == 200], B300 = B[age == 300]), by = .(st, ftg)]
  R1 <- merge(R1, MON, by = c("st", "ftg")); R1[, variant := V]
  ordf <- function(x, m) { pr <- combn(length(x), 2); sum(sign(x[pr[1, ]] - x[pr[2, ]]) != sign(m[pr[1, ]] - m[pr[2, ]])) }
  ORD <- R1[, .(variant = V, n_types = .N, pairs = choose(.N, 2),
    disc_A_vs_FIAmean = ordf(A, mean_AGB2), disc_B100_vs_FIAmean = ordf(B100, mean_AGB2), disc_B50_vs_FIAmean = ordf(B50, mean_AGB2),
    order_A = paste(ftg[order(-A)], collapse = ">"), order_B100 = paste(ftg[order(-B100)], collapse = ">"), order_FIA_mean = paste(ftg[order(-mean_AGB2)], collapse = ">")), by = st]
  ORD[, `:=`(order_A_identical = disc_A_vs_FIAmean == 0, order_B100_identical = disc_B100_vs_FIAmean == 0)]
  fwrite(R1, file.path(OD, "tb_realism_type_DATA.csv")); fwrite(ORD, file.path(OD, "tb_realism_order_DATA.csv"))
  cat(sprintf("%s: holdout s43 classes pass %d/%d; dense bins pass %d/%d; theta at bound %d/%d; monotone %d/%d; B0>=A %d; order A identical %d/6; B100 identical %d/6\n", V,
      HS[set == "s43 classes", sum(pass)], HS[set == "s43 classes", .N], HS[set == "dense bins", sum(pass)], HS[set == "dense bins", .N],
      sum(R1$theta_at_bound, na.rm = TRUE), nrow(R1), sum(R1$monotone_0_300), nrow(R1), sum(R1$B0_ge_A), sum(ORD$order_A_identical), sum(ORD$order_B100_identical)))
}
cat("done 01J\n")
