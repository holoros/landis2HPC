#!/usr/bin/env Rscript
# stage5_daymet_fetch.R: fetch Daymet V4 daily tmin/tmax/prcp (single-pixel API, daymet.ornl.gov)
# at N random cell centres per EPA L3 ecoregion of the state's stage one raster, 1991-2020.
# Sample points are ecoregion raster cells (seeded), NOT FIA plots: no plot coordinates are used.
# Usage: Rscript stage5_daymet_fetch.R <ST> [N_PER_ECO=15]
source(path.expand("~/landis2_fb/scripts_20260929/gates_lib.R"))
a <- commandArgs(TRUE); ST <- a[1]; N <- if (length(a) > 1) as.integer(a[2]) else 15L
Y0 <- 1991; Y1 <- 2020
C <- file.path(FB, "daymet_cache", ST); dir.create(C, recursive = TRUE, showWarnings = FALSE)
eco <- rast(file.path(FB, "states", ST, "inputs", "ecoregions_l3_270m_20260928.tif"))
pts_f <- file.path(C, sprintf("sample_points_%s_seed20260929.csv", ST))
if (!file.exists(pts_f)) {
  set.seed(20260929)
  v <- values(eco, mat = FALSE); cells <- which(!is.na(v))
  pick <- unlist(lapply(split(cells, v[cells]), function(cc) cc[sample.int(length(cc), min(N, length(cc)))]))
  xy <- xyFromCell(eco, pick)
  ll <- project(vect(xy, crs = crs(eco)), "EPSG:4326")
  P <- data.table(pt = seq_along(pick), eco = v[pick], cell = pick, lon = round(geom(ll)[, "x"], 5), lat = round(geom(ll)[, "y"], 5))
  fwrite(P, pts_f)
}
P <- fread(pts_f)
cat(ST, "points:", nrow(P), "per eco:", paste(P[, .N, by = eco][, paste0(eco, "=", N)], collapse = " "), "\n")
for (i in seq_len(nrow(P))) {
  f <- file.path(C, sprintf("dm_%s_eco%d_pt%03d.csv", ST, P$eco[i], P$pt[i]))
  if (file.exists(f) && file.size(f) > 100000) next
  url <- sprintf("https://daymet.ornl.gov/single-pixel/api/data?lat=%.5f&lon=%.5f&vars=tmax,tmin,prcp&start=%d-01-01&end=%d-12-31",
                 P$lat[i], P$lon[i], Y0, Y1)
  ok <- FALSE
  for (k in 1:4) {
    r <- try(download.file(url, f, quiet = TRUE, method = "libcurl"), silent = TRUE)
    if (!inherits(r, "try-error") && file.exists(f) && file.size(f) > 100000) { ok <- TRUE; break }
    Sys.sleep(10 * k)
  }
  cat(sprintf("  %s pt %d eco %d: %s (%s bytes)\n", ST, P$pt[i], P$eco[i], if (ok) "ok" else "FAILED", file.size(f)))
  Sys.sleep(1)
}
cat("fetch done", ST, "\n")
