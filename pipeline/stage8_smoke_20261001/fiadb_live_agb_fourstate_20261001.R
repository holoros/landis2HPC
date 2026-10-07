# Design-based FIADB live aboveground dry biomass (Tg) per state, NH VT MI WI.
# Reference for the LANDIS stage eight smoke gate "year zero biomass against FIA",
# same quantity as FIADB_BIO_TG in tools/anchor_ic_to_fiadb.R (ME/MN/WA/GA/NH anchoring).
# Reads TREE, POP_PLOT_STRATUM_ASSGN, ENTIRE_POP_STRATUM and only CN and
# MACRO_BREAKPOINT_DIA from PLOT. No coordinate column is read. Output is aggregate.
#
# Revision history, 1 Oct 2026.
#   v1 took max(EVALID) and picked the 1990s evaluations (EVALID is SSYYTT, 339701 is 1997).
#   v2 decoded the year but picked 2025 evaluations for MI and WI that have no strata in the
#      July 2026 ENTIRE_POP_STRATUM.csv, so it returned zero.
#   v3 (this) computes every EXPVOL (type 01) evaluation from 2015 on and takes as reference
#      the latest one whose strata resolve; the others are written beside it as a sensitivity.
suppressPackageStartupMessages(library(data.table))
FIA <- "/fs/scratch/PUOM0008/crsfaaron/FIA"
OUT <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930/gates"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
ps <- fread(file.path(FIA, "ENTIRE_POP_STRATUM.csv"),
            select = c("CN", "EXPNS", "ADJ_FACTOR_MICR", "ADJ_FACTOR_SUBP", "ADJ_FACTOR_MACR"))
res <- list()
for (st in c("NH", "VT", "MI", "WI")) {
  A <- fread(file.path(FIA, paste0(st, "_POP_PLOT_STRATUM_ASSGN.csv")),
             select = c("PLT_CN", "STRATUM_CN", "EVALID"))
  p <- fread(file.path(FIA, paste0(st, "_PLOT.csv")), select = c("CN", "MACRO_BREAKPOINT_DIA"))
  TR <- fread(file.path(FIA, paste0(st, "_TREE.csv")),
              select = c("PLT_CN", "STATUSCD", "DIA", "TPA_UNADJ", "DRYBIO_AG"))
  TR <- TR[STATUSCD == 1 & !is.na(DRYBIO_AG) & !is.na(TPA_UNADJ)]
  TR <- merge(TR, p, by.x = "PLT_CN", by.y = "CN", all.x = TRUE)
  ev01 <- unique(A$EVALID[A$EVALID %% 100 == 1])
  yy <- (ev01 %/% 100) %% 100; yr <- ifelse(yy < 50, 2000 + yy, 1900 + yy)
  keep <- yr >= 2015; ev01 <- ev01[keep]; yr <- yr[keep]
  for (i in order(yr)) {
    a <- merge(A[EVALID == ev01[i]], ps, by.x = "STRATUM_CN", by.y = "CN")
    tr <- merge(TR, a, by = "PLT_CN")
    tr[, adj := fifelse(DIA < 5, ADJ_FACTOR_MICR,
                 fifelse(!is.na(MACRO_BREAKPOINT_DIA) & DIA >= MACRO_BREAKPOINT_DIA,
                         ADJ_FACTOR_MACR, ADJ_FACTOR_SUBP))]
    tg <- tr[, sum(DRYBIO_AG * TPA_UNADJ * adj * EXPNS, na.rm = TRUE)] * 0.45359237 / 1e9
    res[[length(res) + 1]] <- data.table(state = st, evalid = ev01[i], eval_year = yr[i],
      n_plots_assigned = A[EVALID == ev01[i], uniqueN(PLT_CN)], n_plots_with_strata = uniqueN(a$PLT_CN),
      n_live_trees = nrow(tr), fiadb_live_agb_Tg = round(tg, 2))
  }
}
out <- rbindlist(res)
out[, reference := FALSE]
out[n_plots_with_strata > 0, reference := eval_year == max(eval_year), by = state]
print(out)
fwrite(out[reference == TRUE, !"reference"], file.path(OUT, "fiadb_live_agb_fourstate_20261001.csv"))
fwrite(out, file.path(OUT, "fiadb_live_agb_fourstate_allevals_20261001.csv"))
cat("WROTE\n")
