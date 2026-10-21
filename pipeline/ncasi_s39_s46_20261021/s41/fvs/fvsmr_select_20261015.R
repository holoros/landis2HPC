# NCASI Phase 1, session 41: select the recalibrated FVS mortality setting per variant from the fit half grid,
# exactly per the pre-registered rule in fvs_mortrecal_PLAN_20261015.md. Reads aggregates only.
suppressPackageStartupMessages(library(data.table))
S41 <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/fvs"
g <- rbindlist(lapply(c("ne", "ls"), function(v) fread(file.path(S41, sprintf("fvs_mortrecal_grid_%s_20261015.csv", v)))))
stopifnot(g[, .N, by = variant]$N == 216 * 3)
ex <- function(r, up) pmax(0, abs(log(r)) - log(up))
g[, G := pmax(ex(r_gross, 1.15), ex(r_mort, 1.15), ex(r_net, 1.15),
              ifelse(r_dense > 1.25, log(r_dense) - log(1.25), ifelse(r_dense < 0.80, log(0.80) - log(r_dense), 0)))]
g[, J := ((log(rm_c0_100))^2 + (log(rm_c100_200))^2 + (log(rm_c200_250))^2 + (log(rm_c250p))^2) / 4]
g[, pref := abs(log(kS)) * 1e6 + kB * 1e3 + abs(PL - 55) + abs(PU - 85)]
pick <- function(d) {   # d: one row per setting with columns Gv, Jv
  if (any(d$Gv == 0)) {
    c0 <- d[Gv == 0]; c0 <- c0[Jv <= 1.02 * min(Jv)]
  } else {
    c0 <- d[Gv <= 1.02 * min(Gv)]; c0 <- c0[Jv <= 1.02 * min(Jv)]
  }
  c0[order(pref)][1]
}
v_agg <- g[, .(Gv = max(G), Jv = mean(J), pref = pref[1]), by = .(variant, kB, PL, PU, kS)]
chosen <- v_agg[, pick(.SD), by = variant][, `:=`(scope = "variant", state = NA_character_)]
fit_state <- merge(g, chosen[, .(variant, kB, PL, PU, kS)], by = c("variant", "kB", "PL", "PU", "kS"))
print(fit_state[, .(variant, state, kB, PL, PU, kS, r_gross, r_mort, r_net, r_dense, rm_c0_100, rm_c100_200, rm_c200_250, rm_c250p, G, J)])
out <- chosen[, .(variant, scope, state, kB, PL, PU, kS, Gv, Jv)]
fail_v <- fit_state[G > 0, unique(variant)]
if (length(fail_v)) {
  cat("Per variant setting fails a fit half gate in variants:", fail_v, "; applying the pre-registered per state fallback\n")
  st <- g[variant %in% fail_v, .(Gv = G, Jv = J, pref = pref), by = .(variant, state, kB, PL, PU, kS)]
  cs <- st[, pick(.SD), by = .(variant, state)][, scope := "state"]
  out <- rbind(out, cs[, .(variant, scope, state, kB, PL, PU, kS, Gv, Jv)])
}
print(out)
fwrite(out, file.path(S41, "fvs_mortrecal_chosen_20261015.csv"))
# compact grid summary (aggregates only): per variant setting, worst state gate excess and mean class loss
fwrite(v_agg[order(variant, Gv, Jv)], file.path(S41, "fvs_mortrecal_grid_summary_20261015.csv"))
fwrite(fit_state, file.path(S41, "fvs_mortrecal_fit_chosen_by_state_20261015.csv"))
cat("SELECT_DONE\n")
