# Session 36, 6 Oct 2026. Decision 2 (Aaron, 6 Oct: "move forward with all recommendations"):
# anchor the NH VT MI WI initial communities to the 2024 FIADB live AGB total.
# Adapted from tools/anchor_ic_to_fiadb.R with one deliberate change. That script sums biomass over
# EVERY pixel of initial-communities.tif. For these four states the TreeMap clip is a padded bounding
# box (32 to 45 pct of active IC cells lie outside the state), so the original would scale an
# in-plus-out-of-state total to the state FIADB figure and under-anchor every state. Here the current
# total is taken only over IC cells with an active ecoregion in ecoregions_20260929.tif (the in-state
# landscape LANDIS runs), at 30 m.
# Reference: gates/fiadb_live_agb_fourstate_20261001.csv, confirmed against FIA EVALIDator on
# 6 Oct (evaluation group 2024, snum 10) to 0.01 Tg in all four states.
# Writes initial_communities/cohort_biomass_by_mapcode_fiadb.csv BESIDE the raw table; refuses to overwrite.
# Gates: N1 scale within 1 to 4 (the raw tables still carry the DRYBIO halving, so about 2.5 to 3.0); N2 anchored in-state total equals FIADB to 0.1 pct;
#   N3 scale within 0.5 pct of the 270 m run copy scale (anch_smoke_20261006.sh, anchor_scale.csv),
#   which used the gated smoke grid; N4 MapCode set and row count unchanged.
suppressPackageStartupMessages({library(terra); library(data.table)})
D <- "/fs/scratch/PUOM0008/crsfaaron/landis2/states_fb_20260930"
fia <- fread(file.path(D, "gates/fiadb_live_agb_fourstate_20261001.csv"))
out <- list(); fail <- character()
for (st in c("NH","VT","MI","WI")) {
  I <- file.path(D, st, "inputs"); ICd <- file.path(I, "initial_communities")
  dst <- file.path(ICd, "cohort_biomass_by_mapcode_fiadb.csv")
  if (file.exists(dst)) { fail <- c(fail, paste(st, "exists, not overwritten")); next }
  ic <- rast(file.path(ICd, "initial-communities.tif")); e <- rast(file.path(I, "ecoregions_20260929.tif"))
  stopifnot(compareGeom(ic, e))
  act <- as.integer(system(sprintf("awk '$1==\"yes\"{print $2}' %s", file.path(I, "ecoregions_20260929.txt")), intern = TRUE))
  stopifnot(length(act) > 0)
  icv <- values(ic)[, 1]; ev <- values(e)[, 1]
  keep <- !is.na(icv) & icv > 0 & !is.na(ev) & ev %in% act
  fr <- data.table(MapCode = icv[keep])[, .(npix = .N), by = MapCode]
  rm(icv, ev, keep); gc()
  cb <- fread(file.path(ICd, "cohort_biomass_by_mapcode.csv")); m2 <- prod(res(ic))
  tot <- function(x) { v <- merge(fr, x[, .(g = sum(CohortBiomass)), by = MapCode], by = "MapCode", all.x = TRUE); v[is.na(g), g := 0]; v[, sum(npix * m2 * g) / 1e12] }
  cur <- tot(cb); ref <- fia[state == st, fiadb_live_agb_Tg]; sc <- ref / cur
  cba <- copy(cb)[, CohortBiomass := pmax(1L, as.integer(round(CohortBiomass * sc)))]
  new <- tot(cba)
  rc <- fread(file.path(D, st, "runs/smoke_20261006_d10_unitfix_anch/anchor_scale.csv"))$scale * 2  # run copy scaled the doubled (unit fix) table, so on the raw table it is twice that
  g <- data.table(state = st, instate_raw_Tg = round(cur, 3), fiadb_Tg = ref, scale = round(sc, 5),
                  runcopy_scale_on_raw = round(rc, 5), anchored_Tg = round(new, 3),
                  N1 = sc > 1 & sc < 4, N2 = abs(new / ref - 1) < 0.001, N3 = abs(sc / rc - 1) < 0.005,
                  N4 = nrow(cba) == nrow(cb) && setequal(cba$MapCode, cb$MapCode))
  if (!all(unlist(g[, .(N1, N2, N3, N4)]))) { fail <- c(fail, paste(st, "gate")); out[[st]] <- g; next }
  tmp <- paste0(dst, ".tmp"); fwrite(cba, tmp); file.rename(tmp, dst)
  g[, md5 := tools::md5sum(dst)]; out[[st]] <- g
}
res <- rbindlist(out, fill = TRUE); print(res)
fwrite(res, file.path(D, "gates/anchor_ic_fourstate_20261006.csv"))
cat("GATES:", if (length(fail)) paste(fail, collapse = "; ") else "ALL PASS", "\n")
if (length(fail)) quit(status = 1)
