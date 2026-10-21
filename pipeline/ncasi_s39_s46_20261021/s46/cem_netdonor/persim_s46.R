#!/usr/bin/env Rscript
# s41 CEM realism gate, step D, version d8 (16 Oct 2026). Same as d7 with a
# third argument naming the engine copy folder (engine, engine_fix1,
# engine_fix2) so fixed runs can be scored unchanged.
# Version d7 notes: Same as d6 with a
# type fix (median remper as double) and an optional run tag argument (default
# s41gate) for the step E attribution runs.
# Version d6 notes: Adds version B, the
# dropout corrected tool total (each condition's mean over the sims in which the
# engine kept it), because 02_cem_matching.R reuses subject_row numbers across
# the three CEM iterations and select_matches keeps one row per number, so a
# random share of subjects is dropped in every sim and cycle. Version A (the
# gate number) sums each sim as the production expansion does.
# Earlier version d2 replaced
# cem_gate_score_s41d.R, which let missing biomass (conditions with no live
# trees, NA in the archive) propagate as NA. Here NA biomass is 0, which is
# what the engine's ratio projection implies (a zero stand stays zero), and
# coverage diagnostics (FIA forest conditions absent from the tool) are added. Plot imputation (like RPA).
# Scores the s41 state targeted runs (start = 2020 to 2024 FIA panel, two 5 yr
# cycles, BAU, 20 sims) against EVALIDator 2024 (biomass, DRYBIO_AG).
#
# Tool quantities, per condition and sim, from the per plot archive:
#   year 0 stock     = pre_drybio_ag in cycle 1 (the subject's own FIA value)
#   net growth       = proj_drybio / (1 - h) - pre_drybio_ag, i.e. change in live
#                      biomass with harvest removals added back (h = harvest
#                      intensity on harvested rows, else 0); unmatched rows 0
#   gross, mortality = from the imputed donor pair: the donor condition's FIA
#                      GRM gross and mortality over its remeasurement (step a6),
#                      as fractions of the donor's time 1 biomass (d_drybio_ag),
#                      times the level the engine applied the ratio to (the
#                      subject's pre value, or for harvested rows the donor T2
#                      value the engine copies in) and times the engine's
#                      effective scaling of the donor ratio, s = (gr - 1)/(r - 1)
#                      with r = T2/T1 of the donor (age saturation and clamp).
#   residual         = net - (gross - mortality): climate, anchor, productivity
#                      multiplier, SDImax cap, disturbance and the harvested row
#                      level swap. Positive residual is added to gross and
#                      negative residual to mortality, so gross - mortality =
#                      net exactly. Residual shares are reported.
# Annual rates are cycle changes / 5; the gate rate is the mean of cycles 1 and 2.
# Expansion: EVALIDator 2024 EXPVOL evaluation, sum EXPNS x adj x value, adj the
# condition's own FIA stock weighted mix of ADJ_FACTOR_SUBP, MICR, MACR. No
# CONDPROP multiplier (per plot acre values). Observed comparison on the same
# plots uses the step a6 tables and the 2024 EXPVOL / EXPGROW evaluations.
# Intervals: 1000 stratified plot bootstrap replicates, one random sim per plot
# per replicate, paired tool / FIA ratio, rescaled to the EVALIDator target.
# Writes only state aggregates.
# Usage: Rscript cem_gate_score_s41d.R <STATE>
suppressPackageStartupMessages(library(data.table))
ARGS <- commandArgs(trailingOnly = TRUE)
ST <- ARGS[1]
TAG <- if (length(ARGS) >= 2) ARGS[2] else "s41gate"
ENGDIR <- if (length(ARGS) >= 3) ARGS[3] else "engine"
W   <- "/fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s41/cem"
FIA <- path.expand("~/fia_data")
LB_TG <- 4.53592e-10; B <- 1000L
SC <- c(ME=23,NH=33,VT=50,MI=26,WI=55,MN=27)
DONORS <- list(ME=c("ME","NH","VT","NY","MA","CT","RI"), NH=c("NH","ME","VT","MA","CT"),
               VT=c("VT","NH","NY","MA","ME"), WI=c("WI","MN","MI","IA","IL"),
               MN=c("MN","WI","MI","IA"), MI=c("MI","WI","MN","OH","IN"))
TGT <- data.table(state = c("NH","VT","MI","WI","ME","MN"),
  stock = c(314.2606,294.2656,1050.9551,814.1724,762.4297,633.4494),
  stock_se_pct = c(1.6758,1.7692,1.0720,0.7862,0.9275,0.8684),
  gross = c(8.2526,7.6094,31.7742,29.0405,25.6128,25.1058),
  mort  = c(2.7822,2.9861,13.0453,10.1263,9.4943,10.6370),
  net   = c(5.4704,4.6233,18.7289,18.9142,16.1185,14.4688))[state == ST]
sc <- SC[[ST]]
f <- function(st, tb) file.path(FIA, sprintf("%s_%s.csv", st, tb))
set.seed(20261016 + sc)

# ---------------- tool archive
rd <- list.files(file.path(ENGDIR, "output"), pattern = sprintf("^%s_[0-9]{8}_%s$", ST, TAG), full.names = TRUE)
stopifnot(length(rd) == 1)
d <- as.data.table(readRDS(file.path(rd, "per_plot_projections.rds")))
cat(sprintf("archive rows %d; columns present: %s\n", nrow(d),
            paste(intersect(c("pre_drybio_ag","d_drybio_ag","T2_drybio_ag","T2_PLT_CN","d_CONDID","remper","gr_drybio"), names(d)), collapse = " ")))
comp_tab <- d[, .N, by = .(own = STATECD == sc)]
cat("archive composition (own state rows TRUE):\n"); print(comp_tab)
d <- d[STATECD == sc & scenario == "BAU"]
d[, T2_PLT_CN := as.character(T2_PLT_CN)]
na_tab <- d[, .(na_pre = sum(is.na(pre_drybio_ag)), na_proj = sum(is.na(proj_drybio)), na_gr = sum(is.na(gr_drybio)), rows = .N)]
cat("NA counts (set to 0):\n"); print(na_tab)
for (v in c("pre_drybio_ag","proj_drybio","T2_drybio_ag")) set(d, which(is.na(d[[v]])), v, 0)
grm <- rbindlist(lapply(DONORS[[ST]], function(s) readRDS(file.path(W, "work", sprintf("grm_cond_%s.rds", s)))), fill = TRUE)
grm <- unique(grm[, .(T2_PLT_CN = as.character(PLT_CN), d_CONDID = as.integer(CONDID), g_tot = gross_tot, m_tot = mort_tot, REMPER_fia = REMPER)],
              by = c("T2_PLT_CN","d_CONDID"))
d[, d_CONDID := as.integer(d_CONDID)]
d <- grm[d, on = c("T2_PLT_CN","d_CONDID")]
d[, hv := fcoalesce(as.logical(was_harvested), FALSE) & fcoalesce(harvest_intensity, 0) > 0]
d[, um := fcoalesce(as.logical(was_unmatched), FALSE)]
d[, h := fifelse(hv, pmin(harvest_intensity, 0.999), 0)]
d[, net := fifelse(um, 0, proj_drybio / (1 - h) - pre_drybio_ag)]
d[, base := fifelse(hv, T2_drybio_ag, pre_drybio_ag)]
d[, r := T2_drybio_ag / d_drybio_ag]
d[, s_eff := fifelse(is.finite(r) & is.finite(gr_drybio) & abs(r - 1) > 1e-6, (gr_drybio - 1) / (r - 1), 1)]
d[, donor_ok := !um & !is.na(g_tot) & is.finite(d_drybio_ag) & d_drybio_ag > 0]
d[, G := fifelse(donor_ok, base * g_tot / d_drybio_ag * s_eff, 0)]
d[, M := fifelse(donor_ok, base * m_tot / d_drybio_ag * s_eff, 0)]
d[, swap := fifelse(hv, T2_drybio_ag - pre_drybio_ag, 0)]
d[, resid := net - (G - M)]
d[, gross := G + pmax(resid, 0)]
d[, mort := M + pmax(-resid, 0)]
diag <- d[, .(rows = .N, share_unmatched = mean(um), share_harvested = mean(hv),
              share_donor_grm_missing = mean(!um & !donor_ok),
              share_remper_agree = mean(abs(remper - REMPER_fia) < 1, na.rm = TRUE),
              median_donor_remper = as.numeric(median(remper, na.rm = TRUE)),
              median_s_eff = median(s_eff[donor_ok], na.rm = TRUE),
              share_ratio_clamped = mean((r < 0.5 | r > 2)[donor_ok], na.rm = TRUE),
              donor_recon_median = median(((T2_drybio_ag - d_drybio_ag) / (g_tot - m_tot))[donor_ok & abs(g_tot - m_tot) > 1], na.rm = TRUE)),
          by = cycle]
cat("row diagnostics by cycle:\n"); print(diag)

# per condition x sim: stock0, and first ten year annual rates (mean of cycles 1, 2)
d[, loc_key := paste(as.integer(STATECD), as.integer(COUNTYCD), as.integer(PLOT), sep = "_")]
d[, CONDID := as.integer(CONDID)]
cs <- d[, .(stock0 = pre_drybio_ag[cycle == 1][1],
            net = sum(net) / 10, gross = sum(gross) / 10, mort = sum(mort) / 10,
            G = sum(G) / 10, M = sum(M) / 10, swap = sum(swap) / 10,
            net_c1 = sum(net[cycle == 1]) / 5, net_c2 = sum(net[cycle == 2]) / 5,
            ncyc = uniqueN(cycle), invyr0 = INVYR[cycle == 1][1]),
        by = .(loc_key, CONDID, sim)]
cat(sprintf("condition x sim rows %d; with both cycles %.4f\n", nrow(cs), mean(cs$ncyc == 2)))
sims <- sort(unique(cs$sim)); nS <- length(sims)
# version B: per condition and cycle, mean over the sims that kept it
cb <- d[, .(stock0 = mean(pre_drybio_ag), net = mean(net) / 5, gross = mean(gross) / 5, mort = mean(mort) / 5,
            G = mean(G) / 5, M = mean(M) / 5, swap = mean(swap) / 5, nsim = uniqueN(sim)), by = .(loc_key, CONDID, cycle)]
presence <- cb[, .(c1 = mean(nsim[cycle == 1]) / nS, c2 = mean(nsim[cycle == 2]) / nS)]
cat(sprintf("mean share of sims keeping a condition: cycle 1 %.3f, cycle 2 %.3f\n", presence$c1, presence$c2))
csB <- cb[, .(stock0 = stock0[cycle == 1][1], net = mean(net), gross = mean(gross), mort = mean(mort),
              G = mean(G), M = mean(M), swap = mean(swap),
              net_c1 = net[cycle == 1][1], net_c2 = if (any(cycle == 2)) net[cycle == 2][1] else NA_real_), by = .(loc_key, CONDID)]

# ---------------- FIA weights, 2024 group
plt <- fread(f(ST,"PLOT"), select = c("CN","STATECD","COUNTYCD","PLOT","INVYR"), colClasses = list(character = "CN"))
plt[, loc_key := paste(STATECD, COUNTYCD, PLOT, sep = "_")]
cnd <- fread(f(ST,"COND"), select = c("PLT_CN","CONDID","COND_STATUS_CD"), colClasses = list(character = "PLT_CN"))
peg <- fread(f(ST,"POP_EVAL_GRP"), colClasses = list(character = "CN"))
pe  <- fread(f(ST,"POP_EVAL"), colClasses = list(character = c("CN","EVAL_GRP_CN")))
pet <- fread(f(ST,"POP_EVAL_TYP"), colClasses = list(character = c("EVAL_CN","EVAL_GRP_CN")))
ev  <- merge(pet[, .(EVAL_CN, EVAL_TYP)], pe[EVAL_GRP_CN %in% peg[EVAL_GRP == sc * 10000 + 2024, CN], .(CN, EVALID)], by.x = "EVAL_CN", by.y = "CN")
ps   <- fread(f(ST,"POP_STRATUM"), colClasses = list(character = "CN"))
ppsa <- fread(f(ST,"POP_PLOT_STRATUM_ASSGN"), select = c("PLT_CN","STRATUM_CN","EVALID"), colClasses = list(character = c("PLT_CN","STRATUM_CN")))
wfun <- function(typ) {
  id <- ev[EVAL_TYP == typ, EVALID][1]
  w <- ppsa[EVALID == id][ps[, .(STRATUM_CN = CN, EXPNS, A1 = ADJ_FACTOR_SUBP, A2 = ADJ_FACTOR_MICR, A3 = ADJ_FACTOR_MACR)], on = "STRATUM_CN", nomatch = NULL]
  unique(w, by = "PLT_CN")
}
wv <- wfun("EXPVOL"); wg <- wfun("EXPGROW")
stk <- readRDS(file.path(W, "work", sprintf("stock_cond_%s.rds", ST)))
og  <- readRDS(file.path(W, "work", sprintf("grm_cond_%s.rds", ST)))
fc  <- cnd[COND_STATUS_CD == 1, .(PLT_CN, CONDID = as.integer(CONDID))]
ec  <- merge(fc, wv, by = "PLT_CN")
ec  <- plt[, .(PLT_CN = CN, loc_key, INVYR)][ec, on = "PLT_CN"]
ec  <- merge(ec, stk[, .(PLT_CN, CONDID = as.integer(CONDID), s1, s2, s3)], by = c("PLT_CN","CONDID"), all.x = TRUE)
for (v in c("s1","s2","s3")) set(ec, which(is.na(ec[[v]])), v, 0)
ec[, s_obs := s1 * A1 + s2 * A2 + s3 * A3]
ec[, adj := fifelse(s1 + s2 + s3 > 0, s_obs / (s1 + s2 + s3), A1)]
# tool values per eval condition (sim matrix)
tv <- merge(ec[, .(PLT_CN, STRATUM_CN, EXPNS, loc_key, CONDID, adj, INVYR)], cs, by = c("loc_key","CONDID"), all.x = TRUE, allow.cartesian = TRUE)
match_tab <- tv[, .(matched = !is.na(sim[1]), year_match = !is.na(sim[1]) && invyr0[1] == INVYR[1]), by = .(PLT_CN, CONDID, EXPNS)]
cat(sprintf("eval forest conditions %d; in tool %d (area share %.4f); same measurement year %.4f\n",
            nrow(match_tab), sum(match_tab$matched), match_tab[, sum(EXPNS * matched) / sum(EXPNS)],
            match_tab[matched == TRUE, mean(year_match)]))
Q <- c("stock0","net","gross","mort","G","M","swap","net_c1","net_c2")
tv <- tv[!is.na(sim)]
for (q in Q) tv[, (q) := get(q) * adj]
pl_sim <- tv[, lapply(.SD, sum), by = .(PLT_CN, sim), .SDcols = Q]
# plot frame of the EXPVOL evaluation (all plots, zero where no forest)
frame <- unique(wv[, .(PLT_CN, STRATUM_CN, EXPNS)])
frame[, pid := .I]
pl_sim <- frame[, .(PLT_CN, pid)][pl_sim, on = "PLT_CN"]
arr <- lapply(Q, function(q) {
  m <- matrix(0, nrow(frame), nS)
  m[cbind(pl_sim$pid, match(pl_sim$sim, sims))] <- pl_sim[[q]]
  m })
names(arr) <- Q
# observed per plot on the same frame
obs_stock <- ec[, .(o = sum(s_obs)), by = PLT_CN]
ogw <- og[wg[, .(PLT_CN, A1, A2, A3)], on = "PLT_CN", nomatch = NULL]
ogw <- ogw[, .(og = sum(g_1 * A1 + g_2 * A2 + g_3 * A3), om = sum(mo_1 * A1 + mo_2 * A2 + mo_3 * A3)), by = PLT_CN]
wgx <- wg[, .(PLT_CN, EXPNS_g = EXPNS)]
frame <- obs_stock[frame, on = "PLT_CN"]; frame <- ogw[frame, on = "PLT_CN"]; frame <- wgx[frame, on = "PLT_CN"]
for (v in c("o","og","om","EXPNS_g")) set(frame, which(is.na(frame[[v]])), v, 0)
frame[, on_ := og - om]
# coverage: observed values on FIA forest conditions the tool does not carry
mt <- match_tab[, .(PLT_CN, CONDID, matched)]
ogc <- og[wg[, .(PLT_CN, A1, A2, A3, EXPNS_g = EXPNS)], on = "PLT_CN", nomatch = NULL]
ogc[, `:=`(ogv = g_1 * A1 + g_2 * A2 + g_3 * A3, omv = mo_1 * A1 + mo_2 * A2 + mo_3 * A3)]
ogc <- merge(ogc[, .(PLT_CN, CONDID = as.integer(CONDID), EXPNS_g, ogv, omv)], mt, by = c("PLT_CN","CONDID"), all.x = TRUE)
ogc[is.na(matched), matched := FALSE]
ecm <- merge(ec[, .(PLT_CN, CONDID, EXPNS, s_obs)], mt, by = c("PLT_CN","CONDID"))
cov <- data.table(state = ST,
  area_share_missing = match_tab[, sum(EXPNS * !matched) / sum(EXPNS)],
  stock_share_missing = ecm[, sum(EXPNS * s_obs * !matched) / sum(EXPNS * s_obs)],
  gross_share_missing = ogc[, sum(EXPNS_g * ogv * !matched) / sum(EXPNS_g * ogv)],
  mort_share_missing = ogc[, sum(EXPNS_g * omv * !matched) / sum(EXPNS_g * omv)],
  net_share_missing = ogc[, sum(EXPNS_g * (ogv - omv) * !matched) / sum(EXPNS_g * (ogv - omv))],
  obs_stock_matched_Tg = ecm[matched == TRUE, sum(EXPNS * s_obs)] * LB_TG,
  obs_gross_matched_Tgyr = ogc[matched == TRUE, sum(EXPNS_g * ogv)] * LB_TG,
  obs_mort_matched_Tgyr = ogc[matched == TRUE, sum(EXPNS_g * omv)] * LB_TG,
  obs_net_matched_Tgyr = ogc[matched == TRUE, sum(EXPNS_g * (ogv - omv))] * LB_TG)
cat("coverage:\n"); print(t(cov))
# point estimates (mean over sims)
pt <- sapply(Q, function(q) sum(frame$EXPNS * rowMeans(arr[[q]]), na.rm = TRUE) * LB_TG)
# ---- s46 appendix (Track K amended, post unblinding follow-on, not gate eligible): per simulation
# registered ratios, version A, for the v9 K2 stream test and the v10 item 1 s_sim. Lines 1-204 are the
# frozen s43c registered scorer verbatim; the bootstrap and pass rule are not run here.
ps <- rbindlist(lapply(c("stock0","gross","mort","net"), function(q) {
  tq <- c(stock0 = "stock", gross = "gross", mort = "mort", net = "net")[[q]]
  data.table(state = ST, quantity = q, sim = sims, ratio = colSums(frame$EXPNS * arr[[q]], na.rm = TRUE) * LB_TG / TGT[[tq]])
}))
chk <- ps[, .(mean_persim = mean(ratio)), by = quantity]
chk[, gate_ratio := sapply(quantity, function(q) pt[[q]] / TGT[[c(stock0 = "stock", gross = "gross", mort = "mort", net = "net")[[q]]]])]
print(chk)
fwrite(ps, file.path(Sys.getenv("CEM_OUT"), sprintf("persim_%s_%s.csv", ST, TAG)))
cat("PERSIM_DONE\n")
