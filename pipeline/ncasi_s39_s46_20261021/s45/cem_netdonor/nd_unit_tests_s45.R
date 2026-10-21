#!/usr/bin/env Rscript
# s45 Track K (post unblinding follow-on, not gate eligible): unit tests before any state run.
# Tests 1 to 3: three synthetic subjects with donor class 10 loss below, equal to and above the
#   module class 10 loss; each also carries donor weather (class 50) mortality, which must not
#   cancel the budworm loss (within class floors).
# Test 4: donor pair REMPER 7 yr vs engine cycle 5 yr, through the donor table builder: donor
#   GRM mortality is annual and must NOT be divided (or multiplied) by REMPER; module loss is
#   annualised by the cycle length only (v3 item 1).
# Test 5 (edge, v5 item 4): zero module loss gives scale 1; all scales 1 (and donor mortality 0,
#   the null path) return the retained fraction bit identical.
suppressPackageStartupMessages(library(data.table))
`%||%` <- function(a, b) if (is.null(a)) b else a
T <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s45/cem_netdonor"
source(file.path(T, "engine_k", "R", "16_netdonor_fns.R"))
tol <- 1e-12; res <- list()
chk <- function(name, ok, detail) { res[[length(res) + 1]] <<- data.table(test = name, pass = isTRUE(ok), detail = detail) }
# synthetic subjects: B = 10000 lb/ac plot acre, CONDPROP 1, budworm hit only (sbw_red 0.7)
B <- rep(10000, 3); cp <- rep(1, 3); sbw <- rep(0.7, 3); wnd <- rep(1, 3); fir <- rep(1, 3); tr <- sbw * wnd * fir
a <- cbind(c10 = 1 - sbw, c50 = sbw * (1 - wnd), c30 = sbw * wnd * (1 - fir))
L10 <- 10000 * 0.3 * ND_LBAC_MGHA / 5      # module class 10 loss, Mg/ha/yr
D <- cbind(c10 = c(0.5, 1, 2) * L10, c50 = rep(5 * L10, 3), c30 = 0)
r <- nd_netting(B, a, cp, D, 5, tr)
exp_s <- c(0.5, 0, 0)
exp_red <- 1 - exp_s * 0.3
for (j in 1:3) {
  nm <- c("T1 donor below module", "T2 donor equal module", "T3 donor above module")[j]
  ok <- abs(r$L[j, "c10"] - L10) < tol && abs(r$s[j, "c10"] - exp_s[j]) < tol && r$s[j, "c50"] == 1 &&
        abs(r$total_red[j] - exp_red[j]) < tol && abs(r$net[j, "c10"] - max(0, L10 - D[j, "c10"])) < tol
  chk(nm, ok, sprintf("L10=%.6f D10=%.6f s10=%.6f (exp %.6f) s50=%.3f red=%.6f (exp %.6f); donor weather %.6f did not cancel",
                      r$L[j, "c10"], D[j, "c10"], r$s[j, "c10"], exp_s[j], r$s[j, "c50"], r$total_red[j], exp_red[j], D[j, "c50"]))
}
# Test 4: builder with REMPER 7
gc4 <- data.table(TRE_CN = c("t1","t2","t3"), PLT_CN = "p1", comp = c("MORTALITY1","MORTALITY2","SURVIVOR"), typ = c(1L, 2L, 1L), tm = c(2, 6, 5))
mi4 <- data.table(TRE_CN = c("t1","t2","t3"), m = c(100, 10, 999))
tr4 <- data.table(TRE_CN = c("t1","t2","t3"), CONDID = 1L, AGENTCD = c(10L, 52L, 0L))
pl4 <- data.table(PLT_CN = "p1", REMPER = 7)
ad4 <- data.table(PLT_CN = "p1", A1 = 1.05, A2 = 1.2, A3 = 1)
cn4 <- data.table(PLT_CN = "p1", CONDID = 1L, CONDPROP_UNADJ = 0.5)
w4 <- nd_build_donor(gc4, mi4, tr4, pl4, ad4, cn4)
d10_exp <- 2 * 100 * 1.05 / 0.5; d50_exp <- 6 * 10 * 1.2 / 0.5
ok4a <- abs(w4$D10_ca - d10_exp) < 1e-9 && abs(w4$D50_ca - d50_exp) < 1e-9 && abs(w4$D10_ca - d10_exp / 7) > 1 && abs(w4$Dall_pa - (2*100*1.05 + 6*10*1.2)) < 1e-9
Bs <- 10000; cps <- 0.5; a4 <- cbind(c10 = 0.3, c50 = 0, c30 = 0)
D4 <- cbind(c10 = w4$D10_ca * ND_LBAC_MGHA, c50 = w4$D50_ca * ND_LBAC_MGHA, c30 = 0)
r4 <- nd_netting(Bs, a4, cps, D4, 5, 0.7)
L4 <- Bs * 0.3 / cps * ND_LBAC_MGHA / 5
s4 <- max(0, L4 - d10_exp * ND_LBAC_MGHA) / L4
ok4b <- abs(r4$L[1, "c10"] - L4) < tol && abs(r4$s[1, "c10"] - s4) < tol && abs(r4$total_red - (1 - s4 * 0.3)) < tol &&
        abs(r4$net[1, "c10"] * 5 - s4 * L4 * 5) < tol
chk("T4 REMPER 7 vs cycle 5", ok4a && ok4b,
    sprintf("D10_ca=%.4f lb/ac/yr (exp %.4f, REMPER divided would be %.4f); L10=%.6f Mg/ha/yr; D10=%.6f; s10=%.6f (exp %.6f); cycle netted loss %.6f Mg/ha",
            w4$D10_ca, d10_exp, d10_exp / 7, r4$L[1, "c10"], D4[1, "c10"], r4$s[1, "c10"], s4, r4$net[1, "c10"] * 5))
# Test 5: edges and null path
set.seed(1); n <- 1000
sb <- ifelse(runif(n) < 0.3, 0.7, 1); wd <- ifelse(runif(n) < 0.1, 0.8, 1); fr <- ifelse(runif(n) < 0.05, 0.4, 1)
tr5 <- sb * wd * fr; a5 <- cbind(c10 = 1 - sb, c50 = sb * (1 - wd), c30 = sb * wd * (1 - fr))
B5 <- runif(n, 0, 3e4); cp5 <- runif(n, 0.1, 1)
r5 <- nd_netting(B5, a5, cp5, matrix(0, n, 3, dimnames = list(NULL, c("c10","c50","c30"))), 5, tr5)
ok5 <- identical(r5$total_red, tr5) && all(r5$s[a5 == 0] == 1) && all(abs(rowSums(a5) - (1 - tr5)) < 1e-12)
chk("T5 zero loss scale 1 and null path bit identical", ok5,
    sprintf("identical(total_red)=%s; scales where loss 0 all 1: %s; attribution sums to 1 - total_red: %s",
            identical(r5$total_red, tr5), all(r5$s[a5 == 0] == 1), all(abs(rowSums(a5) - (1 - tr5)) < 1e-12)))
out <- rbindlist(res)
out[, label := "post unblinding follow-on, not gate eligible"]
fwrite(out, file.path(T, "out", "unit_tests_postunblind_followon_not_gate_eligible.csv"))
print(out)
cat(if (all(out$pass)) "ALL_UNIT_TESTS_PASS\n" else "UNIT_TEST_FAILURE\n")
