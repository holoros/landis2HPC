# Session 36, 6 Oct 2026. Gates for the DRYBIO patched IC rebuild against the current (29 Sep) ICs.
# R1 IC raster: same geometry and identical cell values. R2 initial_communities.txt byte identical (age lists
# carry no biomass). R3 tm_to_mapcode.csv and species_lookup.csv byte identical. R4 cohort table: same
# (MapCode, SpeciesName, CohortAge) keys, and CohortBiomass new = 2 x old up to integer rounding
# (|new - 2 old| <= 2 g m-2 on every row; total ratio within 0.0005 of 2.000).
# Usage: Rscript gate_rebuild_20261006.R ST [ST ...]; appends to gates_rebuild_20261006.tsv
suppressMessages({library(terra); library(data.table)})
FB <- file.path(Sys.getenv("HOME"), "landis2_fb")
out <- list(); md5 <- function(f) unname(tools::md5sum(f))
for (st in commandArgs(TRUE)) {
  o <- file.path(FB, "states", st, "inputs/initial_communities"); n <- file.path(FB, "states", st, "inputs/rebuild_20261006/initial_communities")
  ro <- rast(file.path(o, "initial-communities.tif")); rn <- rast(file.path(n, "initial-communities.tif"))
  geo <- isTRUE(compareGeom(ro, rn, stopOnError = FALSE))
  vals <- geo && identical(values(ro)[, 1], values(rn)[, 1]); rm(ro, rn); gc()
  txt <- md5(file.path(o, "initial_communities.txt")) == md5(file.path(n, "initial_communities.txt"))
  tm <- md5(file.path(o, "tm_to_mapcode.csv")) == md5(file.path(n, "tm_to_mapcode.csv"))
  sl <- md5(file.path(o, "species_lookup.csv")) == md5(file.path(n, "species_lookup.csv"))
  a <- fread(file.path(o, "cohort_biomass_by_mapcode.csv")); b <- fread(file.path(n, "cohort_biomass_by_mapcode.csv"))
  k <- c("MapCode", "SpeciesName", "CohortAge")
  m <- merge(a, b, by = k, suffixes = c("_old", "_new"))
  keys <- nrow(m) == nrow(a) && nrow(m) == nrow(b)
  dev <- m[, max(abs(CohortBiomass_new - 2 * CohortBiomass_old))]
  ratio <- m[, sum(as.numeric(CohortBiomass_new)) / sum(as.numeric(CohortBiomass_old))]
  r <- data.table(state = st, R1_raster = geo && vals, R2_agelist = txt, R3_lookups = tm && sl,
                  R4_keys = keys, R4_rows = nrow(b), R4_max_abs_dev = dev, R4_total_ratio = round(ratio, 6),
                  R4_pass = keys && dev <= 2 && abs(ratio - 2) < 5e-4)
  r[, ALL := R1_raster & R2_agelist & R3_lookups & R4_pass]; out[[st]] <- r
}
res <- rbindlist(out); print(res)
f <- "gates_rebuild_20261006.tsv"; fwrite(res, f, sep = "\t", append = file.exists(f))
if (!all(res$ALL)) quit(status = 1)
