## s43 Track B stress alternative 1: same form with a plot random effect on a (nlme), all plots, per fit unit.
## Compares fixed-effect B* and 10/50 yr curve values with the primary (fit_v2 all-plot nls). usage: Rscript 05_mixed.R FITDIR OUTDIR
suppressMessages({library(data.table); library(nlme)})
set.seed(20261019)
A <- commandArgs(TRUE); FD <- A[1]; OD <- A[2]; dir.create(OD, showWarnings = FALSE, recursive = TRUE)
H <- path.expand("~")
rd <- function(f, s = NULL) { d <- fread(f); if (!"st" %in% names(d)) d[, st := s]; d[, st := as.character(st)]; d }
D <- rbindlist(list(rd(file.path(H, "maine_agb_yc_20261015/out_b/me_intervals_DATA.csv"), "ME"), rd(file.path(H, "nhvt_agb_yc_20261016/out/me_intervals_DATA.csv")),
  rd(file.path(H, "lakes_agb_yc_20261016/out_MI/yc_intervals_DATA.csv"), "MI"), rd(file.path(H, "lakes_agb_yc_20261016/out_WI/yc_intervals_DATA.csv"), "WI"),
  rd(file.path(H, "lakes_agb_yc_20261016/out_MN/yc_intervals_DATA.csv"), "MN")), use.names = TRUE, fill = TRUE)
D <- D[hf == TRUE & consecutive == TRUE & ftg %in% c("SF", "MBB", "AB", "WRPH", "OAK", "EAC") & is.finite(AGB1) & is.finite(AGB2) & is.finite(dt) & dt > 0 & AGB1 >= 0]
D[, y := (AGB2 - AGB1) / dt][, pkey := factor(paste0(st, ":", plot_ix))][, vt := as.numeric(st == "VT")]
P <- fread(file.path(FD, "tb_params_allplots_DATA.csv"))[ok == TRUE]
U <- unique(P[, .(unit, ftg, basis)])
dst <- function(u) switch(u, ME = "ME", MI = "MI", WI = "WI", MN = "MN", LSPOOL = c("MI", "WI", "MN"), NHVT = c("NH", "VT"))
Bt <- function(t, a, b, c) (a / c)^(1 / (1 - b)) * (-expm1(-(1 - b) * c * t))^(1 / (1 - b))
OUT <- list()
for (k in seq_len(nrow(U))) {
  u <- U[k]; d <- as.data.frame(D[st %in% dst(u$unit) & ftg == u$ftg]); p0 <- P[unit == u$unit & ftg == u$ftg][1]
  sv <- grepl("state effect on a", u$basis)
  st0 <- if (sv) c(a = p0$a / ifelse(p0$st == "VT", exp(p0$dv_VT), 1), b = p0$b, c = p0$c, dv = p0$dv_VT) else c(a = p0$a, b = p0$b, c = p0$c)
  f <- if (sv) y ~ a * exp(dv * vt) * AGB1^b - c * AGB1 else y ~ a * AGB1^b - c * AGB1
  m <- tryCatch(nlme(f, data = d, fixed = if (sv) a + b + c + dv ~ 1 else a + b + c ~ 1, random = a ~ 1 | pkey, start = st0,
                     control = nlmeControl(maxIter = 200, msMaxIter = 200, pnlsMaxIter = 20, returnObject = TRUE)), error = function(e) e)
  for (S in intersect(dst(u$unit), unique(P[unit == u$unit & ftg == u$ftg]$st))) {
    pp <- P[unit == u$unit & ftg == u$ftg & st == S]
    if (inherits(m, "error")) { OUT[[length(OUT) + 1]] <- data.table(unit = u$unit, ftg = u$ftg, st = S, ok = FALSE, msg = conditionMessage(m)); next }
    fe <- fixef(m); a <- fe["a"] * if (sv && S == "VT") exp(fe["dv"]) else 1
    OUT[[length(OUT) + 1]] <- data.table(unit = u$unit, ftg = u$ftg, st = S, ok = TRUE, n_plot = length(unique(d$pkey)), a = a, b = fe["b"], c = fe["c"],
      sd_plot_a = as.numeric(VarCorr(m)["a", "StdDev"]), b_le_1 = fe["b"] < 1,
      Bstar_mixed = if (fe["b"] < 1 && fe["c"] > 0) (a / fe["c"])^(1 / (1 - fe["b"])) else NA_real_, Bstar_primary = pp$Bstar,
      B50_mixed = if (fe["b"] < 1 && fe["c"] > 0) Bt(50, a, fe["b"], fe["c"]) else NA_real_, B50_primary = Bt(50, pp$a, pp$b, pp$c),
      B100_mixed = if (fe["b"] < 1 && fe["c"] > 0) Bt(100, a, fe["b"], fe["c"]) else NA_real_, B100_primary = Bt(100, pp$a, pp$b, pp$c))
  }
}
O <- rbindlist(OUT, fill = TRUE); O[, `:=`(Bstar_ratio = Bstar_mixed / Bstar_primary, B50_ratio = B50_mixed / B50_primary, B100_ratio = B100_mixed / B100_primary)]
setorder(O, st, ftg); fwrite(O, file.path(OD, "tb_stress1_mixed_DATA.csv"))
print(O[, .(st, ftg, ok, b = round(b, 3), Bs_m = round(Bstar_mixed), Bs_p = round(Bstar_primary), B50r = round(B50_ratio, 3), B100r = round(B100_ratio, 3))])
cat("done 05\n")
