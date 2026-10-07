# Session 36, 6 Oct 2026 (Aaron approved decision 2, run on firebreather). Anchor the DRYBIO patched NH VT MI WI
# initial communities to the 2024 FIADB live AGB total. Adapted from anchor_ic_fourstate_20261006.R (Cardinal
# version, md5 ad3fc8fe, never run to completion there) for the firebreather source trees.
# The current total is taken only over IC cells with an active ecoregion in ecoregions_20260929.tif (in state);
# tools/anchor_ic_to_fiadb.R sums the whole raster, which here includes 32 to 45 pct out of state cells.
# Reference: FIA EVALIDator 2024 stock (snum 10, evaluation group SS2024), equal to the 1 Oct local FIADB figure
# to 0.01 Tg; file ../grm/evalidator_agb_fourstate_24_25_20261006.csv.
# Input: inputs/rebuild_20261006/initial_communities/cohort_biomass_by_mapcode.csv (patched, gated). Writes
# cohort_biomass_by_mapcode_fiadb.csv beside it; refuses to overwrite.
# Gates: N1 scale within 1.0 to 2.0; N2 anchored in-state total equals FIADB to 0.1 pct; N3 scale within 0.5 pct of
# the 270 m run copy scale on the unit corrected table (job 15303879: NH 1.3170, VT 1.2627, MI 1.4944, WI 1.3033);
# N4 keys and row count unchanged.
suppressPackageStartupMessages({library(terra); library(data.table)})
FB <- file.path(Sys.getenv("HOME"), "landis2_fb")
ev <- fread(file.path(Sys.getenv("HOME"), "jobs/ncasi_s36_20261006/grm/evalidator_agb_fourstate_24_25_20261006.csv"))
ref_tab <- ev[quantity == "stock" & substr(eval_grp, 3, 6) == "2024", .(state, Tg)]
rc_tab <- data.table(state = c("NH","VT","MI","WI"), rc = c(1.3170, 1.2627, 1.4944, 1.3033))
out <- list(); fail <- character()
for (st in commandArgs(TRUE)) {
  I <- file.path(FB, "states", st, "inputs"); ICd <- file.path(I, "rebuild_20261006/initial_communities")
  dst <- file.path(ICd, "cohort_biomass_by_mapcode_fiadb.csv")
  if (file.exists(dst)) { fail <- c(fail, paste(st, "exists")); next }
  ic <- rast(file.path(ICd, "initial-communities.tif")); e <- rast(file.path(I, "ecoregions_20260929.tif"))
  stopifnot(compareGeom(ic, e))
  act <- as.integer(system(sprintf("awk '$1==\"yes\"{print $2}' %s", file.path(I, "ecoregions_20260929.txt")), intern = TRUE))
  stopifnot(length(act) > 0)
  icv <- values(ic)[, 1]; evv <- values(e)[, 1]
  keep <- !is.na(icv) & icv > 0 & !is.na(evv) & evv %in% act
  fr <- data.table(MapCode = icv[keep])[, .(npix = .N), by = MapCode]
  out_share <- 1 - sum(keep) / sum(!is.na(icv) & icv > 0)
  rm(icv, evv, keep); gc()
  cb <- fread(file.path(ICd, "cohort_biomass_by_mapcode.csv")); m2 <- prod(res(ic))
  tot <- function(x) { v <- merge(fr, x[, .(g = sum(CohortBiomass)), by = MapCode], by = "MapCode", all.x = TRUE); v[is.na(g), g := 0]; v[, sum(npix * m2 * g) / 1e12] }
  cur <- tot(cb); ref <- ref_tab[state == st, Tg]; sc <- ref / cur; rc <- rc_tab[state == st, rc]
  cba <- copy(cb)[, CohortBiomass := pmax(1L, as.integer(round(CohortBiomass * sc)))]
  new <- tot(cba)
  g <- data.table(state = st, ic_cells_out_of_state_share = round(out_share, 4), instate_patched_Tg = round(cur, 3),
                  fiadb_Tg = ref, scale = round(sc, 5), runcopy_scale = rc, anchored_Tg = round(new, 3),
                  N1 = sc > 1 & sc < 2, N2 = abs(new / ref - 1) < 0.001, N3 = abs(sc / rc - 1) < 0.005,
                  N4 = nrow(cba) == nrow(cb) && identical(cba$MapCode, cb$MapCode))
  ok <- all(unlist(g[, .(N1, N2, N3, N4)]))
  if (ok) { tmp <- paste0(dst, ".tmp"); fwrite(cba, tmp); file.rename(tmp, dst); g[, md5 := unname(tools::md5sum(dst))] } else fail <- c(fail, paste(st, "gate"))
  out[[st]] <- g
}
res <- rbindlist(out, fill = TRUE); print(res)
f <- "anchor_fourstate_fb_20261006.tsv"; fwrite(res, f, sep = "\t", append = file.exists(f))
cat("GATES:", if (length(fail)) paste(fail, collapse = "; ") else "ALL PASS", "\n")
if (length(fail)) quit(status = 1)
